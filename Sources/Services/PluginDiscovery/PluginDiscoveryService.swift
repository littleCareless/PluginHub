import Foundation

/// 插件发现服务
final class PluginDiscoveryService: ObservableObject {
    static let shared = PluginDiscoveryService()

    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var lastError: Error?

    private let fileManager = FileManager.default

    private init() {}

    /// 发现编辑器插件
    func discoverPlugins(in editor: Editor) async throws -> [Plugin] {
        guard editor.isEnabled else { return [] }
        guard editor.extensionsDirectoryExists else {
            throw PluginDiscoveryError.directoryNotFound(editor.expandedPath)
        }

        var plugins: [Plugin] = []

        let contents = try fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: editor.expandedPath),
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        for case let extensionFolder as URL in contents {
            if let plugin = parseExtensionFolder(extensionFolder, editor: editor) {
                plugins.append(plugin)
            }
        }

        return plugins
    }

    /// 批量扫描多个编辑器
    func scanEditors(_ editors: [Editor], progress: @escaping (Double) -> Void) async throws -> [UUID: [Plugin]] {
        await MainActor.run {
            isScanning = true
            scanProgress = 0
            lastError = nil
        }

        var results: [UUID: [Plugin]] = [:]
        var errors: [Error] = []

        let totalEditors = Double(editors.count)

        for (index, editor) in editors.enumerated() {
            do {
                let plugins = try await discoverPlugins(in: editor)
                results[editor.id] = plugins
            } catch {
                errors.append(error)
                print("Failed to scan \(editor.name): \(error.localizedDescription)")
            }

            await MainActor.run {
                scanProgress = Double(index + 1) / totalEditors
                progress(scanProgress)
            }
        }

        await MainActor.run {
            isScanning = false
        }

        if !errors.isEmpty {
            lastError = errors.first
        }

        return results
    }

    /// 解析扩展文件夹
    private func parseExtensionFolder(_ folderURL: URL, editor: Editor) -> Plugin? {
        let packageJSONURL = folderURL.appendingPathComponent("package.json")

        guard fileManager.fileExists(atPath: packageJSONURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: packageJSONURL)
            guard let packageInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let extensionId = packageInfo["name"] as? String else {
                return nil
            }

            let publisherId = packageInfo["publisher"] as? String ?? "unknown"
            let displayName = packageInfo["displayName"] as? String ?? extensionId
            let description = packageInfo["description"] as? String ?? ""
            let version = packageInfo["version"] as? String

            return Plugin(
                publisherId: publisherId,
                extensionId: extensionId,
                displayName: displayName,
                description: description,
                version: version,
                source: .local,
                installedPath: folderURL.path
            )
        } catch {
            print("Failed to parse \(folderURL.path): \(error.localizedDescription)")
            return nil
        }
    }
}

/// 插件发现错误
enum PluginDiscoveryError: LocalizedError {
    case directoryNotFound(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Extension directory not found: \(path)"
        case .parseError(let message):
            return "Failed to parse plugin: \(message)"
        }
    }
}
