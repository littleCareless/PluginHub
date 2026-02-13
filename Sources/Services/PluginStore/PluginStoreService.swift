import Foundation
import CryptoKit

/// 集中插件存储服务 (类似 pnpm store)
final class PluginStoreService: ObservableObject {
    static let shared = PluginStoreService()

    @Published var storePath: String
    @Published var storedPlugins: [UUID: Plugin] = [:]
    @Published var totalSize: Int64 = 0

    private let fileManager = FileManager.default
    private let userDefaults: UserDefaults
    private let pluginsKey = "storedPlugins"
    private let casObjectPath = "objects/sha256"

    init(storePath: String? = nil, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 默认存储路径
        let storeURL: URL
        if let storePath {
            storeURL = URL(fileURLWithPath: storePath)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            storeURL = appSupport.appendingPathComponent("AIPluginManager/store")
        }
        self.storePath = storeURL.path

        // 创建存储目录
        try? fileManager.createDirectory(at: URL(fileURLWithPath: self.storePath), withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: casRootURL, withIntermediateDirectories: true)

        // 加载已存储的插件
        loadStoredPlugins()
    }

    private var casRootURL: URL {
        URL(fileURLWithPath: storePath).appendingPathComponent(casObjectPath)
    }

    private var preferSymlink: Bool {
        userDefaults.object(forKey: "enableSymlinks") as? Bool ?? true
    }

    /// 添加插件到存储
    func addPlugin(_ plugin: Plugin, from sourcePath: String) async throws -> Plugin {
        let pluginId = plugin.id
        let destinationPath = try await ensureStoredCopy(from: sourcePath)

        // 更新插件信息
        var storedPlugin = plugin
        storedPlugin.storePath = destinationPath
        storedPlugin.source = .linked

        // 保存到内存
        storedPlugins[pluginId] = storedPlugin

        // 持久化
        saveStoredPlugins()

        // 更新总大小
        updateTotalSize()

        return storedPlugin
    }

    /// 确保目录内容已进入 CAS，返回对象路径
    func ensureStoredCopy(from sourcePath: String) async throws -> String {
        let hash = try contentHash(at: sourcePath)
        let destinationFolder = casRootURL.appendingPathComponent(hash, isDirectory: true)

        if fileManager.fileExists(atPath: destinationFolder.path) {
            return destinationFolder.path
        }

        let tempFolder = casRootURL.appendingPathComponent(".tmp-\(UUID().uuidString)", isDirectory: true)
        try fileManager.copyItem(atPath: sourcePath, toPath: tempFolder.path)

        do {
            try fileManager.moveItem(atPath: tempFolder.path, toPath: destinationFolder.path)
        } catch {
            // 处理并发写入：如果目标已存在，说明已有进程/线程落盘成功
            try? fileManager.removeItem(atPath: tempFolder.path)
            if !fileManager.fileExists(atPath: destinationFolder.path) {
                throw error
            }
        }

        return destinationFolder.path
    }

    /// 从存储链接插件到编辑器
    func linkPlugin(_ plugin: Plugin, to editor: Editor) async throws -> String {
        let sourcePath: String
        if let existingStorePath = plugin.storePath, fileManager.fileExists(atPath: existingStorePath) {
            sourcePath = existingStorePath
        } else if let installedPath = plugin.installedPath, !installedPath.isEmpty {
            sourcePath = try await ensureStoredCopy(from: installedPath)
        } else {
            throw PluginStoreError.pluginNotInStore(plugin.uniqueId)
        }

        // 记录到已存储插件，便于设置页统计与后续复用
        var storedPlugin = plugin
        storedPlugin.storePath = sourcePath
        storedPlugin.source = .linked
        storedPlugins[plugin.id] = storedPlugin
        saveStoredPlugins()
        updateTotalSize()

        let targetPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        // 确保编辑器扩展目录存在
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: editor.expandedPath),
            withIntermediateDirectories: true
        )

        // 如果目标已存在，先删除
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        try createSharedLink(from: sourcePath, to: targetPath)

        return targetPath
    }

    /// 直接将任意源目录通过 CAS 链接到目标路径
    func linkStoreContent(from sourcePath: String, to targetPath: String) async throws {
        let casPath = try await ensureStoredCopy(from: sourcePath)

        let targetParent = URL(fileURLWithPath: targetPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: targetParent, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        try createSharedLink(from: casPath, to: targetPath)
    }

    /// 取消链接
    func unlinkPlugin(_ plugin: Plugin, from editor: Editor) throws {
        let linkPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        guard fileManager.fileExists(atPath: linkPath) else {
            return
        }

        // 检查是否是符号链接
        let isSymbolicLink = (try? fileManager.attributesOfItem(atPath: linkPath)[.type] as? FileAttributeType) == .typeSymbolicLink

        if isSymbolicLink {
            try fileManager.removeItem(atPath: linkPath)
        } else {
            // 如果不是符号链接，直接删除
            try fileManager.removeItem(atPath: linkPath)
        }
    }

    /// 批量链接插件
    func linkPlugins(_ plugins: [Plugin], to editor: Editor) async throws -> [String] {
        var links: [String] = []
        var errors: [Error] = []

        for plugin in plugins {
            do {
                let linkPath = try await linkPlugin(plugin, to: editor)
                links.append(linkPath)
            } catch {
                errors.append(error)
            }
        }

        if !errors.isEmpty {
            throw PluginStoreError.linkErrors(errors)
        }

        return links
    }

    /// 检查插件是否已链接到编辑器
    func isPluginLinked(_ plugin: Plugin, to editor: Editor) -> Bool {
        let linkPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        guard fileManager.fileExists(atPath: linkPath) else {
            return false
        }

        // 检查是否是有效的符号链接
        do {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: linkPath)
            if let storePath = plugin.storePath {
                return normalizedPath(destination) == normalizedPath(storePath)
            }
            return normalizedPath(destination).hasPrefix(normalizedPath(casRootURL.path) + "/")
        } catch {
            // 不是符号链接时，尝试识别硬链接树
            guard let storePath = plugin.storePath else {
                return false
            }
            return isHardLinkedTree(from: storePath, to: linkPath)
        }
    }

    /// 批量取消链接
    func unlinkPlugins(_ plugins: [Plugin], from editor: Editor) throws {
        for plugin in plugins {
            let linkPath = URL(fileURLWithPath: editor.expandedPath)
                .appendingPathComponent(plugin.uniqueId)
                .path

            guard fileManager.fileExists(atPath: linkPath) else {
                continue
            }

            if (try? fileManager.destinationOfSymbolicLink(atPath: linkPath)) != nil {
                try fileManager.removeItem(atPath: linkPath)
            } else {
                try fileManager.removeItem(atPath: linkPath)
            }
        }
    }

    /// 移除存储中的插件
    func removePlugin(_ plugin: Plugin) throws {
        guard plugin.storePath != nil else {
            throw PluginStoreError.pluginNotInStore(plugin.uniqueId)
        }

        storedPlugins.removeValue(forKey: plugin.id)

        saveStoredPlugins()
        updateTotalSize()

        // CAS 下真实对象可能被多个索引项/链接共享，交给 GC 判定是否可删除
        _ = try? garbageCollectStore()
    }

    /// 清空存储
    func clearStore() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: storePath),
            includingPropertiesForKeys: nil
        )

        for item in contents {
            try? fileManager.removeItem(atPath: item.path)
        }

        storedPlugins.removeAll()
        totalSize = 0

        saveStoredPlugins()
    }

    /// CAS 垃圾回收：删除未被索引与编辑器符号链接引用的对象
    @discardableResult
    func garbageCollectStore() throws -> Int {
        let referencedHashes = referencedCASHashes()
        let casRoot = casRootURL

        guard fileManager.fileExists(atPath: casRoot.path) else {
            return 0
        }

        let contents = try fileManager.contentsOfDirectory(
            at: casRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var removed = 0
        for item in contents {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let hash = item.lastPathComponent
            guard !referencedHashes.contains(hash) else { continue }

            try fileManager.removeItem(at: item)
            removed += 1
        }

        // 清理索引中无效项
        storedPlugins = storedPlugins.filter { _, plugin in
            guard let path = plugin.storePath else { return false }
            return fileManager.fileExists(atPath: path)
        }
        saveStoredPlugins()
        updateTotalSize()

        return removed
    }

    // MARK: - 私有方法

    /// 加载已存储的插件
    private func loadStoredPlugins() {
        guard let data = userDefaults.data(forKey: pluginsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return
        }

        for id in ids {
            if let pluginData = userDefaults.data(forKey: "plugin_\(id.uuidString)"),
               let plugin = try? JSONDecoder().decode(Plugin.self, from: pluginData) {
                storedPlugins[id] = plugin
            }
        }

        updateTotalSize()
    }

    /// 保存存储的插件
    private func saveStoredPlugins() {
        let ids = Array(storedPlugins.keys)

        if let data = try? JSONEncoder().encode(ids) {
            userDefaults.set(data, forKey: pluginsKey)
        }

        for (id, plugin) in storedPlugins {
            if let data = try? JSONEncoder().encode(plugin) {
                userDefaults.set(data, forKey: "plugin_\(id.uuidString)")
            }
        }
    }

    /// 更新总大小
    private func updateTotalSize() {
        var total: Int64 = 0

        for (_, plugin) in storedPlugins {
            guard let path = plugin.storePath else { continue }

            if let size = folderSize(at: path) {
                total += size
            }
        }

        totalSize = total
    }

    /// 计算文件夹大小
    private func folderSize(at path: String) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var size: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }

        return size
    }

    /// 共享链接策略：符号链接优先；关闭符号链接时使用硬链接树；失败再回退到普通复制
    private func createSharedLink(from sourcePath: String, to targetPath: String) throws {
        if preferSymlink {
            do {
                try fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: sourcePath)
                return
            } catch {
                // 符号链接失败后回退
            }
        }

        do {
            try createHardLinkedTree(from: sourcePath, to: targetPath)
        } catch {
            try fileManager.copyItem(atPath: sourcePath, toPath: targetPath)
        }
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func referencedCASHashes() -> Set<String> {
        var hashes: Set<String> = []
        let rootPrefix = normalizedPath(casRootURL.path) + "/"

        for (_, plugin) in storedPlugins {
            guard let storePath = plugin.storePath else { continue }
            let normalizedStorePath = normalizedPath(storePath)
            guard normalizedStorePath.hasPrefix(rootPrefix) else { continue }
            hashes.insert(URL(fileURLWithPath: normalizedStorePath).lastPathComponent)
        }

        // 扫描所有已知编辑器路径中的符号链接目标
        for type in EditorType.allCases {
            for path in type.allPossibleExtensionsPaths {
                let expanded = NSString(string: path).expandingTildeInPath
                guard fileManager.fileExists(atPath: expanded) else { continue }
                guard let entries = try? fileManager.contentsOfDirectory(atPath: expanded) else { continue }

                for entry in entries {
                    let linkPath = URL(fileURLWithPath: expanded).appendingPathComponent(entry).path
                    guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: linkPath) else {
                        continue
                    }
                    let normalizedDestination = normalizedPath(destination)
                    guard normalizedDestination.hasPrefix(rootPrefix) else { continue }
                    hashes.insert(URL(fileURLWithPath: normalizedDestination).lastPathComponent)
                }
            }
        }

        return hashes
    }

    private func isHardLinkedTree(from sourcePath: String, to targetPath: String) -> Bool {
        guard fileManager.fileExists(atPath: sourcePath),
              fileManager.fileExists(atPath: targetPath) else {
            return false
        }

        guard let sampleRelativePath = sampleRegularFileRelativePath(in: sourcePath) else {
            return false
        }

        let sourceSample = URL(fileURLWithPath: sourcePath).appendingPathComponent(sampleRelativePath).path
        let targetSample = URL(fileURLWithPath: targetPath).appendingPathComponent(sampleRelativePath).path

        guard fileManager.fileExists(atPath: sourceSample),
              fileManager.fileExists(atPath: targetSample) else {
            return false
        }

        do {
            let sourceAttrs = try fileManager.attributesOfItem(atPath: sourceSample)
            let targetAttrs = try fileManager.attributesOfItem(atPath: targetSample)
            let sourceInode = sourceAttrs[.systemFileNumber] as? NSNumber
            let targetInode = targetAttrs[.systemFileNumber] as? NSNumber
            let sourceDev = sourceAttrs[.systemNumber] as? NSNumber
            let targetDev = targetAttrs[.systemNumber] as? NSNumber
            return sourceInode == targetInode && sourceDev == targetDev
        } catch {
            return false
        }
    }

    private func sampleRegularFileRelativePath(in rootPath: String) -> String? {
        let rootURL = URL(fileURLWithPath: rootPath)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }
            return fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
        }

        return nil
    }

    private func createHardLinkedTree(from sourcePath: String, to targetPath: String) throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            throw PluginStoreError.copyError("Source path does not exist: \(sourcePath)")
        }

        if !isDirectory.boolValue {
            try fileManager.linkItem(atPath: sourcePath, toPath: targetPath)
            return
        }

        try fileManager.createDirectory(at: URL(fileURLWithPath: targetPath), withIntermediateDirectories: true)

        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        ) else {
            throw PluginStoreError.copyError("Failed to enumerate source directory: \(sourcePath)")
        }

        var entries: [URL] = []
        for case let entryURL as URL in enumerator {
            entries.append(entryURL)
        }
        entries.sort { $0.path < $1.path }

        for entryURL in entries {
            let relativePath = entryURL.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
            let targetEntryPath = URL(fileURLWithPath: targetPath).appendingPathComponent(relativePath).path
            let values = try entryURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])

            if values.isDirectory == true {
                try fileManager.createDirectory(at: URL(fileURLWithPath: targetEntryPath), withIntermediateDirectories: true)
            } else if values.isRegularFile == true {
                try fileManager.linkItem(atPath: entryURL.path, toPath: targetEntryPath)
            } else if values.isSymbolicLink == true {
                let destination = try fileManager.destinationOfSymbolicLink(atPath: entryURL.path)
                try fileManager.createSymbolicLink(atPath: targetEntryPath, withDestinationPath: destination)
            }
        }
    }

    /// 目录内容哈希（路径+内容），用于真实 CAS
    private func contentHash(at sourcePath: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            throw PluginStoreError.copyError("Source path does not exist: \(sourcePath)")
        }

        var hasher = SHA256()
        hasher.update(data: Data("sha256-dir-v1\n".utf8))

        if !isDirectory.boolValue {
            hasher.update(data: Data("F:root\n".utf8))
            try updateHasherForFile(at: sourceURL, hasher: &hasher)
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }

        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        ) else {
            throw PluginStoreError.copyError("Failed to enumerate source directory: \(sourcePath)")
        }

        var entries: [URL] = []
        for case let entryURL as URL in enumerator {
            entries.append(entryURL)
        }
        entries.sort { $0.path < $1.path }

        for entryURL in entries {
            let relativePath = entryURL.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
            let values = try entryURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])

            if values.isDirectory == true {
                hasher.update(data: Data("D:\(relativePath)\n".utf8))
            } else if values.isRegularFile == true {
                hasher.update(data: Data("F:\(relativePath)\n".utf8))
                try updateHasherForFile(at: entryURL, hasher: &hasher)
            } else if values.isSymbolicLink == true {
                let destination = try fileManager.destinationOfSymbolicLink(atPath: entryURL.path)
                hasher.update(data: Data("L:\(relativePath)->\(destination)\n".utf8))
            }
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func updateHasherForFile(at fileURL: URL, hasher: inout SHA256) throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }
    }
}

/// 插件存储错误
enum PluginStoreError: LocalizedError {
    case pluginNotInStore(String)
    case linkErrors([Error])
    case copyError(String)

    var errorDescription: String? {
        switch self {
        case .pluginNotInStore(let id):
            return "Plugin not in store: \(id)"
        case .linkErrors(let errors):
            return "Link errors: \(errors.count) failures"
        case .copyError(let message):
            return "Copy error: \(message)"
        }
    }
}
