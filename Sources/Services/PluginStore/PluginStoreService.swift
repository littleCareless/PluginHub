import Foundation

/// 集中插件存储服务 (类似 pnpm store)
final class PluginStoreService: ObservableObject {
    static let shared = PluginStoreService()

    @Published var storePath: String
    @Published var storedPlugins: [UUID: Plugin] = [:]
    @Published var totalSize: Int64 = 0

    private let fileManager = FileManager.default
    private let pluginsKey = "storedPlugins"

    init() {
        // 默认存储路径
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("AIPluginManager/store")
        storePath = storeURL.path

        // 创建存储目录
        try? fileManager.createDirectory(at: URL(fileURLWithPath: storePath), withIntermediateDirectories: true)

        // 加载已存储的插件
        loadStoredPlugins()
    }

    /// 添加插件到存储
    func addPlugin(_ plugin: Plugin, from sourcePath: String) async throws -> Plugin {
        let pluginId = plugin.id
        let destinationFolder = URL(fileURLWithPath: storePath).appendingPathComponent(plugin.uniqueId)

        // 如果已存在，跳过
        if fileManager.fileExists(atPath: destinationFolder.path) {
            return plugin
        }

        // 复制插件到存储
        try fileManager.copyItem(atPath: sourcePath, toPath: destinationFolder.path)

        // 更新插件信息
        var storedPlugin = plugin
        storedPlugin.storePath = destinationFolder.path
        storedPlugin.source = .linked

        // 保存到内存
        storedPlugins[pluginId] = storedPlugin

        // 持久化
        saveStoredPlugins()

        // 更新总大小
        updateTotalSize()

        return storedPlugin
    }

    /// 从存储链接插件到编辑器
    func linkPlugin(_ plugin: Plugin, to editor: Editor) async throws -> String {
        guard let storePath = plugin.storePath else {
            throw PluginStoreError.pluginNotInStore(plugin.uniqueId)
        }

        let targetPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        // 如果目标已存在，先删除
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        // 创建符号链接
        try fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: storePath)

        return targetPath
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
            return destination == plugin.storePath
        } catch {
            return false
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
        guard let storePath = plugin.storePath else {
            throw PluginStoreError.pluginNotInStore(plugin.uniqueId)
        }

        try fileManager.removeItem(atPath: storePath)
        storedPlugins.removeValue(forKey: plugin.id)

        saveStoredPlugins()
        updateTotalSize()
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

    // MARK: - 私有方法

    /// 加载已存储的插件
    private func loadStoredPlugins() {
        let userDefaults = UserDefaults.standard

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
        let userDefaults = UserDefaults.standard
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
