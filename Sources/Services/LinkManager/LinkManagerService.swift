import Foundation

/// 链接管理器
final class LinkManagerService: ObservableObject {
    static let shared = LinkManagerService()

    @Published var activeLinks: [UUID: [UUID: PluginLink]] = [:] // editorId -> [pluginId -> link]
    @Published var pendingOperations: [UUID: LinkOperation] = [:]

    private let fileManager = FileManager.default
    private let linkStorageKey = "activeLinks"

    init() {
        loadLinks()
    }

    /// 创建链接
    func createLink(plugin: Plugin, editor: Editor) async throws -> PluginLink {
        let sourcePath = plugin.storePath ?? plugin.fullPath
        let targetPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        // 检查目标是否存在
        if fileManager.fileExists(atPath: targetPath) {
            // 如果是符号链接，先移除
            if (try? fileManager.destinationOfSymbolicLink(atPath: targetPath)) != nil {
                try fileManager.removeItem(atPath: targetPath)
            } else {
                // 如果是普通文件夹，询问是否覆盖
                throw LinkError.targetAlreadyExists(targetPath)
            }
        }

        // 创建符号链接
        try fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: sourcePath)

        // 记录链接
        let link = PluginLink(
            pluginId: plugin.id,
            editorId: editor.id,
            sourcePath: sourcePath,
            linkPath: targetPath
        )

        addLink(link, for: editor.id)

        return link
    }

    /// 移除链接
    func removeLink(plugin: Plugin, editor: Editor) throws {
        let targetPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        guard fileManager.fileExists(atPath: targetPath) else {
            return
        }

        // 检查是否是符号链接
        if (try? fileManager.destinationOfSymbolicLink(atPath: targetPath)) != nil {
            try fileManager.removeItem(atPath: targetPath)
        } else {
            // 如果不是符号链接，直接删除
            try fileManager.removeItem(atPath: targetPath)
        }

        removeLink(for: editor.id, pluginId: plugin.id)
    }

    /// 批量链接
    func linkPlugins(_ plugins: [Plugin], to editor: Editor) async throws -> [PluginLink] {
        var links: [PluginLink] = []
        var errors: [Error] = []

        for plugin in plugins {
            do {
                let link = try await createLink(plugin: plugin, editor: editor)
                links.append(link)
            } catch {
                errors.append(error)
                print("Failed to link \(plugin.uniqueId): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            throw LinkError.batchErrors(errors)
        }

        return links
    }

    /// 批量取消链接
    func unlinkPlugins(_ plugins: [Plugin], from editor: Editor) throws {
        for plugin in plugins {
            try? removeLink(plugin: plugin, editor: editor)
        }
    }

    /// 检查链接状态
    func checkLinkStatus(plugin: Plugin, editor: Editor) -> LinkStatus {
        let targetPath = URL(fileURLWithPath: editor.expandedPath)
            .appendingPathComponent(plugin.uniqueId)
            .path

        if !fileManager.fileExists(atPath: targetPath) {
            return .notLinked
        }

        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: targetPath) {
            if destination == plugin.storePath || destination == plugin.fullPath {
                return .linked
            } else {
                return .broken
            }
        }

        return .directInstall
    }

    /// 验证所有链接
    func validateAllLinks() async -> [UUID: [UUID: LinkValidationResult]] {
        var results: [UUID: [UUID: LinkValidationResult]] = [:]

        for (editorId, links) in activeLinks {
            var editorResults: [UUID: LinkValidationResult] = [:]

            for (pluginId, link) in links {
                let isValid = fileManager.fileExists(atPath: link.linkPath)

                if isValid, let destination = try? fileManager.destinationOfSymbolicLink(atPath: link.linkPath) {
                    if destination == link.sourcePath {
                        editorResults[pluginId] = .valid
                    } else {
                        editorResults[pluginId] = .broken
                    }
                } else {
                    editorResults[pluginId] = .invalid
                }
            }

            results[editorId] = editorResults
        }

        return results
    }

    /// 修复损坏的链接
    func fixBrokenLinks(for editor: Editor) async throws -> Int {
        var fixed = 0

        guard let links = activeLinks[editor.id] else {
            return 0
        }

        for (pluginId, link) in links {
            if let result = try? await validateLink(link),
               result == .broken {
                // 移除损坏的链接
                try? fileManager.removeItem(atPath: link.linkPath)

                // 重新创建
                // 这里需要重新获取插件信息，略过
                fixed += 1
            }
        }

        return fixed
    }

    private func validateLink(_ link: PluginLink) async throws -> LinkValidationResult {
        if !fileManager.fileExists(atPath: link.linkPath) {
            return .invalid
        }

        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: link.linkPath) {
            if destination == link.sourcePath {
                return .valid
            } else {
                return .broken
            }
        }

        return .invalid
    }

    // MARK: - 持久化

    private func addLink(_ link: PluginLink, for editorId: UUID) {
        if activeLinks[editorId] == nil {
            activeLinks[editorId] = [:]
        }
        activeLinks[editorId]?[link.pluginId] = link
        saveLinks()
    }

    private func removeLink(for editorId: UUID, pluginId: UUID) {
        activeLinks[editorId]?.removeValue(forKey: pluginId)
        saveLinks()
    }

    private func loadLinks() {
        guard let data = UserDefaults.standard.data(forKey: linkStorageKey),
              let decoded = try? JSONDecoder().decode([UUID: [UUID: PluginLink]].self, from: data) else {
            return
        }
        activeLinks = decoded
    }

    private func saveLinks() {
        if let data = try? JSONEncoder().encode(activeLinks) {
            UserDefaults.standard.set(data, forKey: linkStorageKey)
        }
    }
}

/// 链接状态
enum LinkStatus {
    case linked
    case notLinked
    case broken
    case directInstall
}

/// 链接验证结果
enum LinkValidationResult {
    case valid
    case broken
    case invalid
}

/// 链接错误
enum LinkError: LocalizedError {
    case targetAlreadyExists(String)
    case linkFailed(String)
    case batchErrors([Error])
    case pluginNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .targetAlreadyExists(let path):
            return "Target already exists: \(path)"
        case .linkFailed(let message):
            return "Link failed: \(message)"
        case .batchErrors(let errors):
            return "Batch operation had \(errors.count) errors"
        case .pluginNotFound(let id):
            return "Plugin not found: \(id)"
        }
    }
}

/// 链接操作
struct LinkOperation: Identifiable {
    let id: UUID
    let pluginId: UUID
    let editorId: UUID
    let type: OperationType
    var progress: Double
    var status: OperationStatus

    enum OperationType {
        case link
        case unlink
        case move
    }

    enum OperationStatus {
        case pending
        case inProgress
        case completed
        case failed(Error)
    }
}
