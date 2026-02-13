import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general".localized, systemImage: "gear")
                }

            EditorSettingsView()
                .tabItem {
                    Label("nav.editors".localized, systemImage: "chevron.left.forwardslash.chevron.right")
                }

            StorageSettingsView()
                .tabItem {
                    Label("settings.storage".localized, systemImage: "internaldrive")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("settings.advanced".localized, systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("checkForUpdates") private var checkForUpdates = true
    @AppStorage("showNotifications") private var showNotifications = true
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        Form {
            Section("settings.general".localized) {
                Picker("settings.language".localized, selection: $languageManager.currentLanguage) {
                    ForEach(Array(languageManager.supportedLanguages.keys.sorted()), id: \.self) { key in
                        Text((languageManager.supportedLanguages[key] ?? key).localized).tag(key)
                    }
                }
            }

            Section("settings.launch".localized) {
                Toggle("settings.launchAtLogin".localized, isOn: $launchAtLogin)
            }

            Section("settings.updates".localized) {
                Toggle("settings.autoCheckUpdates".localized, isOn: $checkForUpdates)
            }

            Section("settings.showNotifications".localized) {
                Toggle("settings.showNotifications".localized, isOn: $showNotifications)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddEditor = false
    @State private var editingEditor: Editor?
    @State private var editorToDelete: Editor?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(appState.editors) { editor in
                    HStack {
                        Image(systemName: editor.type.iconName)
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading) {
                            Text(editor.name)
                                .font(.body)

                            Text(editor.expandedPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { editor.isEnabled },
                            set: { newValue in
                                appState.updateEditor(editor, isEnabled: newValue)
                            }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingEditor = editor
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        editorToDelete = appState.editors[index]
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    showingAddEditor = true
                } label: {
                    Label("editor.add".localized, systemImage: "plus")
                }

                Spacer()

                Button {
                    // 恢复默认编辑器
                    let defaults = EditorDiscoveryService.getDefaultEditors()
                    for defaultEditor in defaults {
                        if !appState.editors.contains(where: { $0.type == defaultEditor.type }) {
                            appState.addEditor(defaultEditor)
                        }
                    }
                } label: {
                    Text("editor.restoreDefaults".localized)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddEditor) {
            AddEditorView()
                .environmentObject(appState)
        }
        .sheet(item: $editingEditor) { editor in
            EditEditorView(editor: editor)
                .environmentObject(appState)
        }
        .alert("editor.deleteConfirmTitle".localized, isPresented: .init(
            get: { editorToDelete != nil },
            set: { if !$0 { editorToDelete = nil } }
        )) {
            Button("common.cancel".localized, role: .cancel) {
                editorToDelete = nil
            }
            Button("common.delete".localized, role: .destructive) {
                if let editor = editorToDelete {
                    appState.removeEditor(editor)
                    editorToDelete = nil
                }
            }
        } message: {
            if let editor = editorToDelete {
                Text("editor.deleteConfirmMessage".localized(editor.name))
            }
        }
    }
}

// MARK: - Add Editor View

struct AddEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType: EditorType = .cursor
    @State private var extensionsPath = ""
    @State private var isEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("editor.basicInfo".localized) {
                    TextField("editor.name".localized, text: $name)

                    Picker("editor.type".localized, selection: $selectedType) {
                        ForEach(EditorType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, newType in
                        extensionsPath = newType.defaultExtensionsPath
                        if name.isEmpty {
                            name = newType.rawValue
                        }
                    }
                }

                Section("editor.extensionsDirectory".localized) {
                    TextField("editor.path".localized, text: $extensionsPath)

                    Button("editor.selectPath".localized) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false

                        if panel.runModal() == .OK,
                           let url = panel.url {
                            extensionsPath = url.path
                        }
                    }
                }

                Section("editor.status".localized) {
                    Toggle("editor.enabled".localized, isOn: $isEnabled)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("editor.add".localized) {
                    let editor = Editor(
                        type: selectedType,
                        name: name.isEmpty ? selectedType.rawValue : name,
                        extensionsPath: extensionsPath.isEmpty ? selectedType.defaultExtensionsPath : extensionsPath,
                        isEnabled: isEnabled
                    )
                    appState.addEditor(editor)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            extensionsPath = selectedType.defaultExtensionsPath
            if name.isEmpty {
                name = selectedType.rawValue
            }
        }
    }
}

// MARK: - Edit Editor View

struct EditEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let editor: Editor

    @State private var name: String
    @State private var extensionsPath: String
    @State private var isEnabled: Bool

    init(editor: Editor) {
        self.editor = editor
        _name = State(initialValue: editor.name)
        _extensionsPath = State(initialValue: editor.extensionsPath)
        _isEnabled = State(initialValue: editor.isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("editor.basicInfo".localized) {
                    TextField("editor.name".localized, text: $name)

                    HStack {
                        Text("editor.type".localized)
                        Spacer()
                        Text(editor.type.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("editor.extensionsDirectory".localized) {
                    TextField("editor.path".localized, text: $extensionsPath)

                    Button("editor.selectPath".localized) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false

                        if panel.runModal() == .OK,
                           let url = panel.url {
                            extensionsPath = url.path
                        }
                    }
                }

                Section("editor.status".localized) {
                    Toggle("editor.enabled".localized, isOn: $isEnabled)

                    HStack {
                        Text("editor.status".localized)
                        Spacer()
                        Text(editor.extensionsDirectoryExists ? "editor.directoryExists".localized : "editor.directoryMissing".localized)
                            .foregroundStyle(editor.extensionsDirectoryExists ? .green : .red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("common.save".localized) {
                    appState.updateEditor(editor, name: name, extensionsPath: extensionsPath, isEnabled: isEnabled)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Storage Settings

struct StorageSettingsView: View {
    @StateObject private var storeService = PluginStoreService.shared
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("settings.storageLocation".localized) {
                    HStack {
                        Text("settings.storagePath".localized)
                        Spacer()
                        Text(storeService.storePath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("settings.storedPlugins".localized)
                        Spacer()
                        Text("\(storeService.storedPlugins.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.totalSize".localized)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: storeService.totalSize, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("nav.actions".localized) {
                    Button("settings.clearStorage".localized, role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .alert("settings.clearConfirmTitle".localized, isPresented: $showingClearConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("settings.clear".localized, role: .destructive) {
                try? storeService.clearStore()
            }
        } message: {
            Text("settings.clearConfirmMessage".localized)
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @AppStorage("enableSymlinks") private var enableSymlinks = true
    @AppStorage("autoLinkOnScan") private var autoLinkOnScan = false
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("debugMode") private var debugMode = false

    var body: some View {
        Form {
            Section("settings.linkSettings".localized) {
                Toggle("settings.useSymlink".localized, isOn: $enableSymlinks)
                    .help("settings.useSymlinkHelp".localized)

                Toggle("settings.autoLinkAfterScan".localized, isOn: $autoLinkOnScan)
                    .help("settings.autoLinkAfterScanHelp".localized)
            }

            Section("settings.fileDisplay".localized) {
                Toggle("settings.showHiddenFiles".localized, isOn: $showHiddenFiles)
                Toggle("settings.debugMode".localized, isOn: $debugMode)
                    .help("settings.debugModeHelp".localized)
            }

            Section("settings.dataManagement".localized) {
                Button("settings.resetAll".localized) {
                    // 重置设置
                }

                Button("settings.clearCache".localized) {
                    // 清除缓存
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preferences View

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsView()
            .frame(width: 550, height: 450)
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}
