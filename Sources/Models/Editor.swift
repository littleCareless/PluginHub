import Foundation
import AppKit

/// 支持的编辑器类型
enum EditorType: String, Codable, CaseIterable {
    case vscode = "VS Code"
    case vscodeInsiders = "VS Code Insiders"
    case vscodium = "VSCodium"
    case cursor = "Cursor"
    case windsurf = "Windsurf"
    case trae = "Trae"
    case marsCode = "MarsCode"

    var defaultExtensionsPath: String {
        switch self {
        case .vscode:
            return "~/.vscode/extensions"
        case .vscodeInsiders:
            return "~/.vscode-insiders/extensions"
        case .vscodium:
            return "~/.vscode-oss/extensions"
        case .cursor:
            return "~/Library/Application Support/Cursor/extensions"
        case .windsurf:
            return "~/Library/Application Support/Windsurf/extensions"
        case .trae:
            return "~/Library/Application Support/Trae/extensions"
        case .marsCode:
            return "~/Library/Application Support/MarsCode/extensions"
        }
    }

    /// 应用程序路径（可能有多个候选路径）
    var applicationPaths: [String] {
        switch self {
        case .vscode:
            return ["/Applications/Visual Studio Code.app"]
        case .vscodeInsiders:
            return ["/Applications/Visual Studio Code - Insiders.app"]
        case .vscodium:
            return ["/Applications/VSCodium.app", "/Applications/VSCodium.app/Contents/Resources/app/bin/../.."]
        case .cursor:
            return ["/Applications/Cursor.app"]
        case .windsurf:
            return ["/Applications/Windsurf.app"]
        case .trae:
            return ["/Applications/Trae.app"]
        case .marsCode:
            return ["/Applications/MarsCode.app"]
        }
    }

    var iconName: String {
        switch self {
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .vscodeInsiders: return "chevron.left.forwardslash.chevron.right"
        case .vscodium: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursor"
        case .windsurf: return "wind"
        case .trae: return "t.bubble"
        case .marsCode: return "m.circle"
        }
    }
}

/// 编辑器配置
struct Editor: Identifiable, Codable, Hashable {
    let id: UUID
    let type: EditorType
    var name: String
    var extensionsPath: String
    var isEnabled: Bool
    var lastScanDate: Date?

    init(
        id: UUID = UUID(),
        type: EditorType,
        name: String? = nil,
        extensionsPath: String? = nil,
        isEnabled: Bool = true,
        lastScanDate: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.rawValue
        self.extensionsPath = extensionsPath ?? type.defaultExtensionsPath
        self.isEnabled = isEnabled
        self.lastScanDate = lastScanDate
    }

    /// 获取展开的路径
    var expandedPath: String {
        NSString(string: extensionsPath).expandingTildeInPath
    }

    /// 插件目录是否存在
    var extensionsDirectoryExists: Bool {
        FileManager.default.fileExists(atPath: expandedPath)
    }

    /// 获取应用程序图标
    var appIcon: NSImage? {
        for path in type.applicationPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let appIcon = NSWorkspace.shared.icon(forFile: path)
            if appIcon.isValid && appIcon.size.width > 1 {
                return appIcon
            }
        }
        return nil
    }
}
