import Foundation

/// 重复检测服务
final class DeduplicatorService: ObservableObject {
    static let shared = DeduplicatorService()

    @Published var isAnalyzing = false
    @Published var currentReport: DuplicateReport?

    private let fileManager = FileManager.default

    init() {}

    /// 分析重复插件
    func analyzeDuplicates(
        pluginsByEditor: [UUID: [Plugin]],
        editors: [Editor]
    ) async -> DuplicateReport {
        await MainActor.run {
            isAnalyzing = true
        }

        var pluginMap: [String: [DuplicateInstance]] = [:]

        // 收集所有插件实例
        for (editorId, plugins) in pluginsByEditor {
            guard let editor = editors.first(where: { $0.id == editorId }) else {
                continue
            }

            for plugin in plugins {
                let key = plugin.uniqueId

                if pluginMap[key] == nil {
                    pluginMap[key] = []
                }

                let instance = DuplicateInstance(
                    editorName: editor.name,
                    editorId: editorId,
                    path: plugin.fullPath,
                    version: plugin.version,
                    size: 0 // 延迟计算大小
                )

                pluginMap[key]?.append(instance)
            }
        }

        // 计算文件夹大小（延迟）
        for (key, instances) in pluginMap {
            pluginMap[key] = instances.map { instance in
                let size = (try? folderSize(at: instance.path)) ?? 0
                return DuplicateInstance(
                    id: instance.id,
                    editorName: instance.editorName,
                    editorId: instance.editorId,
                    path: instance.path,
                    version: instance.version,
                    size: size,
                    isLinked: false
                )
            }
        }

        // 创建重复组
        var groups: [DuplicatePluginGroup] = []

        for (uniqueId, instances) in pluginMap {
            guard instances.count > 1 else {
                continue // 只有单个实例，不算重复
            }

            guard let firstPlugin = pluginsByEditor.values
                .flatMap({ $0 })
                .first(where: { $0.uniqueId == uniqueId }) else {
                continue
            }

            let group = DuplicatePluginGroup(
                pluginUniqueId: uniqueId,
                displayName: firstPlugin.displayName,
                instances: instances.sorted { $0.size > $1.size }
            )

            groups.append(group)
        }

        let report = DuplicateReport(
            editors: editors,
            groups: groups
        )

        await MainActor.run {
            currentReport = report
            isAnalyzing = false
        }

        return report
    }

    /// 生成优化建议
    func generateSuggestions(for report: DuplicateReport) -> [String] {
        var suggestions: [String] = []

        // 1. 链接优化建议
        let linkedPlugins = report.groups.filter { group in
            group.instances.contains { $0.isLinked }
        }

        if !linkedPlugins.isEmpty {
            suggestions.append("dedup.suggestion.linkedPlugins".localized(linkedPlugins.count))
        }

        // 2. 版本冲突建议
        let versionConflicts = report.groups.filter { $0.isVersionConflict }

        for group in versionConflicts {
            suggestions.append("dedup.suggestion.versionConflict".localized(group.displayName, group.allVersions.joined(separator: ", ")))
        }

        // 3. 空间节省建议
        if report.wastedSpace > 0 {
            let formattedSize = ByteCountFormatter.string(
                fromByteCount: report.wastedSpace,
                countStyle: .file
            )
            suggestions.append("dedup.suggestion.spaceSaved".localized(formattedSize))
        }

        // 4. 批量操作建议
        if report.totalDuplicates > 5 {
            suggestions.append("dedup.suggestion.bulkLink".localized)
        }

        return suggestions
    }

    /// 创建优化计划
    func createOptimizationPlan(for report: DuplicateReport) -> OptimizationPlan {
        var actions: [OptimizationAction] = []

        // 1. 链接操作
        for group in report.groups {
            // 找出最大的实例作为主副本
            let sortedInstances = group.instances.sorted { $0.size > $1.size }
            guard let master = sortedInstances.first else { continue }

            // 其他实例需要链接到主副本
            for instance in sortedInstances.dropFirst() {
                actions.append(.link(
                    pluginUniqueId: group.pluginUniqueId,
                    sourcePath: master.path,
                    targetPath: instance.path,
                    editorName: instance.editorName
                ))
            }
        }

        // 2. 删除重复
        for group in report.groups {
            // 删除较小的重复副本
            let sortedInstances = group.instances.sorted { $0.size > $1.size }
            for instance in sortedInstances.dropFirst() {
                actions.append(.remove(
                    pluginUniqueId: group.pluginUniqueId,
                    path: instance.path,
                    editorName: instance.editorName
                ))
            }
        }

        return OptimizationPlan(
            actions: actions,
            estimatedSpaceSaved: report.wastedSpace,
            estimatedTime: Double(actions.count) * 0.5 // 假设每个操作 0.5 秒
        )
    }

    /// 执行优化计划
    func executePlan(_ plan: OptimizationPlan, progress: @escaping (Double) -> Void) async throws {
        var completed = 0
        let total = Double(plan.actions.count)

        for action in plan.actions {
            switch action {
            case .link(_, let sourcePath, let targetPath, _):
                try await performLink(sourcePath: sourcePath, targetPath: targetPath)

            case .remove(_, let path, _):
                try fileManager.removeItem(atPath: path)

            case .cleanup:
                // 清理临时文件
                break
            }

            completed += 1
            progress(Double(completed) / total)
        }
    }

    private func performLink(sourcePath: String, targetPath: String) async throws {
        // 移除现有目标
        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        // 创建符号链接
        try fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: sourcePath)
    }

    private func folderSize(at path: String) throws -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var size: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }

        return size
    }
}

/// 优化计划
struct OptimizationPlan {
    let actions: [OptimizationAction]
    let estimatedSpaceSaved: Int64
    let estimatedTime: Double

    var formattedSpaceSaved: String {
        ByteCountFormatter.string(fromByteCount: estimatedSpaceSaved, countStyle: .file)
    }
}

/// 优化操作
enum OptimizationAction: Hashable {
    case link(pluginUniqueId: String, sourcePath: String, targetPath: String, editorName: String)
    case remove(pluginUniqueId: String, path: String, editorName: String)
    case cleanup(path: String)
}
