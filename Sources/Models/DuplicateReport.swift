import Foundation

/// 重复插件信息
struct DuplicatePluginGroup: Identifiable {
    let id: UUID
    let pluginUniqueId: String
    let displayName: String
    var instances: [DuplicateInstance]

    init(
        id: UUID = UUID(),
        pluginUniqueId: String,
        displayName: String,
        instances: [DuplicateInstance] = []
    ) {
        self.id = id
        self.pluginUniqueId = pluginUniqueId
        self.displayName = displayName
        self.instances = instances
    }

    /// 重复次数
    var duplicateCount: Int {
        instances.count
    }

    /// 是否是真正的重复（不同版本）
    var isVersionConflict: Bool {
        let versions = Set(instances.compactMap { $0.version })
        return versions.count > 1
    }

    /// 所有版本
    var allVersions: [String] {
        Array(Set(instances.compactMap { $0.version })).sorted()
    }
}

/// 重复实例信息
struct DuplicateInstance: Identifiable, Hashable {
    let id: UUID
    let editorName: String
    let editorId: UUID
    let path: String
    let version: String?
    let size: Int64
    let isLinked: Bool

    init(
        id: UUID = UUID(),
        editorName: String,
        editorId: UUID,
        path: String,
        version: String? = nil,
        size: Int64 = 0,
        isLinked: Bool = false
    ) {
        self.id = id
        self.editorName = editorName
        self.editorId = editorId
        self.path = path
        self.version = version
        self.size = size
        self.isLinked = isLinked
    }

    /// 格式化大小
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// 重复检测报告
struct DuplicateReport: Identifiable {
    let id: UUID
    let scanDate: Date
    let editors: [Editor]
    var groups: [DuplicatePluginGroup]
    var totalDuplicates: Int
    var wastedSpace: Int64

    init(
        id: UUID = UUID(),
        scanDate: Date = Date(),
        editors: [Editor] = [],
        groups: [DuplicatePluginGroup] = []
    ) {
        self.id = id
        self.scanDate = scanDate
        self.editors = editors
        self.groups = groups
        self.totalDuplicates = groups.reduce(0) { $0 + ($1.duplicateCount - 1) }
        self.wastedSpace = groups.reduce(0) { total, group in
            // 估算浪费空间：除了第一个实例外，其他实例的空间
            let sortedInstances = group.instances.sorted { $0.size > $1.size }
            let sizesToRemove = sortedInstances.dropFirst().map { $0.size }
            return total + sizesToRemove.reduce(0, +)
        }
    }

    /// 格式化浪费空间
    var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: wastedSpace, countStyle: .file)
    }
}
