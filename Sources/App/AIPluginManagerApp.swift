import SwiftUI

@main
struct AIPluginManagerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.locale)
                .id(languageManager.currentLanguage)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("editor.scan".localized) {
                    Task {
                        await appState.scanAllEditors()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("duplicate.detect".localized) {
                    Task {
                        await appState.detectDuplicates()
                    }
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandGroup(after: .appInfo) {
                Button("settings.preferences".localized) {
                    appState.showingPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}

/// 全局应用状态
@MainActor
final class AppState: ObservableObject {
    // MARK: - 服务
    let discoveryService = PluginDiscoveryService.shared
    let storeService = PluginStoreService.shared
    let linkManager = LinkManagerService.shared
    let deduplicator = DeduplicatorService.shared

    // MARK: - 编辑器
    @Published var editors: [Editor] = []

    // MARK: - 插件
    @Published var pluginsByEditor: [UUID: [Plugin]] = [:]
    @Published var allPlugins: [Plugin] = []
    @Published var selectedPlugins: Set<UUID> = []

    // MARK: - 重复检测
    @Published var duplicateReport: DuplicateReport?
    @Published var showingDuplicateReport = false

    // MARK: - UI 状态
    @Published var selectedTab: MainTab = .plugins
    @Published var selectedEditorForDetail: Editor?
    @Published var isLoading = false
    @Published var showingPreferences = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published private(set) var hasPerformedInitialScan = false

    // MARK: - 搜索和过滤
    @Published var searchText = ""
    @Published var filterCategory: String?
    @Published var sortOption: SortOption = .name

    enum MainTab: String, CaseIterable {
        case plugins = "plugins"
        case editors = "editors"
        case duplicates = "duplicates"
        case settings = "settings"
    }

    // MARK: - 编辑器操作

    func selectEditor(_ editor: Editor) {
        selectedEditorForDetail = editor
        selectedTab = .editors
    }

    func clearEditorSelection() {
        selectedEditorForDetail = nil
    }

    enum SortOption: String, CaseIterable {
        case name
        case size
        case publisher
        case date

        var localizedTitle: String {
            switch self {
            case .name:
                return "sort.name".localized
            case .size:
                return "sort.size".localized
            case .publisher:
                return "sort.publisher".localized
            case .date:
                return "sort.date".localized
            }
        }
    }

    init() {
        loadEditors()
    }

    // MARK: - 编辑器管理

    func loadEditors() {
        // 从 UserDefaults 加载或使用默认值
        editors = EditorDiscoveryService.getDefaultEditors()
    }

    func addEditor(_ editor: Editor) {
        editors.append(editor)
        saveEditors()
    }

    func removeEditor(_ editor: Editor) {
        editors.removeAll { $0.id == editor.id }
        saveEditors()
    }

    func updateEditor(_ editor: Editor, name: String? = nil, extensionsPath: String? = nil, isEnabled: Bool? = nil) {
        if let index = editors.firstIndex(where: { $0.id == editor.id }) {
            if let name = name {
                editors[index].name = name
            }
            if let extensionsPath = extensionsPath {
                editors[index].extensionsPath = extensionsPath
            }
            if let isEnabled = isEnabled {
                editors[index].isEnabled = isEnabled
            }
            saveEditors()
        }
    }

    private func saveEditors() {
        // 持久化编辑器列表
    }

    // MARK: - 扫描

    func scanAllEditors() async {
        isLoading = true

        do {
            let results = try await discoveryService.scanEditors(editors) { progress in
                Task { @MainActor in
                    self.discoveryService.scanProgress = progress
                }
            }

            pluginsByEditor = results
            mergeAllPlugins()
        } catch {
            showError(error.localizedDescription)
        }

        isLoading = false
    }

    func performInitialScanIfNeeded() async {
        guard !hasPerformedInitialScan else { return }
        hasPerformedInitialScan = true
        await scanAllEditors()
    }

    func scanEditor(_ editor: Editor) async {
        do {
            let plugins = try await discoveryService.discoverPlugins(in: editor)
            pluginsByEditor[editor.id] = plugins
            mergeAllPlugins()

            // 更新扫描时间
            if let index = editors.firstIndex(where: { $0.id == editor.id }) {
                editors[index].lastScanDate = Date()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func mergeAllPlugins() {
        var merged: [Plugin] = []

        for (_, plugins) in pluginsByEditor {
            merged.append(contentsOf: plugins)
        }

        // 去重
        var seenIds: Set<String> = []
        allPlugins = merged.filter { plugin in
            let id = plugin.uniqueId
            if seenIds.contains(id) {
                return false
            }
            seenIds.insert(id)
            return true
        }
    }

    // MARK: - 重复检测

    func detectDuplicates() async {
        await scanAllEditors()

        duplicateReport = await deduplicator.analyzeDuplicates(
            pluginsByEditor: pluginsByEditor,
            editors: editors
        )

        showingDuplicateReport = true
    }

    // MARK: - 链接操作

    func linkPlugins(_ plugins: [Plugin], to editor: Editor) async {
        isLoading = true

        do {
            try await storeService.linkPlugins(plugins, to: editor)
            await scanEditor(editor)
        } catch {
            showError(error.localizedDescription)
        }

        isLoading = false
    }

    func unlinkPlugins(_ plugins: [Plugin], from editor: Editor) {
        do {
            try storeService.unlinkPlugins(plugins, from: editor)
            Task {
                await scanEditor(editor)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - 批量操作

    func linkSelectedPluginsToEditor(_ editor: Editor) async {
        let plugins = allPlugins.filter { selectedPlugins.contains($0.id) }
        await linkPlugins(plugins, to: editor)
        selectedPlugins.removeAll()
    }

    // MARK: - 过滤和搜索

    var filteredPlugins: [Plugin] {
        var plugins = allPlugins

        // 搜索过滤
        if !searchText.isEmpty {
            plugins = plugins.filter { plugin in
                plugin.displayName.localizedCaseInsensitiveContains(searchText) ||
                plugin.publisherId.localizedCaseInsensitiveContains(searchText) ||
                plugin.extensionId.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 排序
        switch sortOption {
        case .name:
            plugins.sort { $0.displayName < $1.displayName }
        case .size:
            plugins.sort { $0.fullPath.count > $1.fullPath.count }
        case .publisher:
            plugins.sort { $0.publisherId < $1.publisherId }
        case .date:
            plugins.sort { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }
        }

        return plugins
    }

    // MARK: - 错误处理

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

/// 编辑器发现服务（用于获取默认编辑器）
enum EditorDiscoveryService {
    /// 检测编辑器是否已安装（通过检查应用程序或插件目录是否存在）
    private static func isEditorInstalled(type: EditorType) -> Bool {
        // 1. 检查应用程序是否存在
        for appPath in type.applicationPaths {
            if FileManager.default.fileExists(atPath: appPath) {
                return true
            }
        }

        // 2. 检查插件目录是否存在（检查所有可能的路径）
        for path in type.allPossibleExtensionsPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }

        // 3. 检查应用支持目录
        let appSupportBase = NSString(string: "~/Library/Application Support").expandingTildeInPath
        let editorName: String
        switch type {
        case .vscode:
            editorName = "Code"
        case .vscodeInsiders:
            editorName = "Code - Insiders"
        case .vscodium:
            editorName = "VSCodium"
        case .cursor:
            editorName = "Cursor"
        case .windsurf:
            editorName = "Windsurf"
        case .trae:
            editorName = "Trae"
        case .marsCode:
            editorName = "MarsCode"
        }
        
        let editorAppSupport = (appSupportBase as NSString).appendingPathComponent(editorName)
        return FileManager.default.fileExists(atPath: editorAppSupport)
    }
    
    /// 获取本机已安装的编辑器列表
    static func getDefaultEditors() -> [Editor] {
        let allTypes = EditorType.allCases
        return allTypes
            .filter { isEditorInstalled(type: $0) }
            .map { Editor(type: $0) }
    }
    
    /// 获取所有支持的编辑器（用于设置页面显示）
    static func getAllSupportedEditors() -> [Editor] {
        EditorType.allCases.map { Editor(type: $0) }
    }
}
