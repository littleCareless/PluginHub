import Foundation

/// 插件安装来源
enum PluginSource: String, Codable {
    case local = "local"
    case marketplace = "marketplace"
    case linked = "linked"
}

/// 插件状态
enum PluginStatus: String, Codable {
    case installed = "installed"
    case available = "available"
    case updateAvailable = "update_available"
    case error = "error"
}

/// 插件信息
struct Plugin: Identifiable, Codable, Hashable {
    let id: UUID
    var publisherId: String
    var extensionId: String
    var displayName: String
    var description: String
    var version: String?
    var latestVersion: String?
    var source: PluginSource
    var installedPath: String?
    var storePath: String?
    var isEnabled: Bool
    var tags: [String]
    var categories: [String]
    var lastUpdated: Date?
    var downloadCount: Int?

    init(
        id: UUID = UUID(),
        publisherId: String,
        extensionId: String,
        displayName: String,
        description: String,
        version: String? = nil,
        latestVersion: String? = nil,
        source: PluginSource = .local,
        installedPath: String? = nil,
        storePath: String? = nil,
        isEnabled: Bool = true,
        tags: [String] = [],
        categories: [String] = [],
        lastUpdated: Date? = nil,
        downloadCount: Int? = nil
    ) {
        self.id = id
        self.publisherId = publisherId
        self.extensionId = extensionId
        self.displayName = displayName
        self.description = description
        self.version = version
        self.latestVersion = latestVersion
        self.source = source
        self.installedPath = installedPath
        self.storePath = storePath
        self.isEnabled = isEnabled
        self.tags = tags
        self.categories = categories
        self.lastUpdated = lastUpdated
        self.downloadCount = downloadCount
    }

    /// 插件唯一标识符 (publisher.extensionId)
    var uniqueId: String {
        "\(publisherId).\(extensionId)"
    }

    /// 插件完整路径
    var fullPath: String {
        installedPath ?? storePath ?? ""
    }

    /// 是否有可用更新
    var hasUpdate: Bool {
        guard let version = version, let latestVersion = latestVersion else {
            return false
        }
        return version != latestVersion && latestVersion.compare(version, options: .numeric) == .orderedDescending
    }

    /// VSCode 市场 URL
    var marketplaceURL: URL? {
        URL(string: "https://marketplace.visualstudio.com/items?itemName=\(publisherId).\(extensionId)")
    }
}

/// 插件链接信息
struct PluginLink: Identifiable, Codable {
    let id: UUID
    let pluginId: UUID
    let editorId: UUID
    let sourcePath: String
    let linkPath: String
    let isActive: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        pluginId: UUID,
        editorId: UUID,
        sourcePath: String,
        linkPath: String,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pluginId = pluginId
        self.editorId = editorId
        self.sourcePath = sourcePath
        self.linkPath = linkPath
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
