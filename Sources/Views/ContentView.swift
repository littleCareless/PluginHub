import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            NavigationStack {
                DetailContentView()
            }
        }
        .sheet(isPresented: $appState.showingDuplicateReport) {
            if let report = appState.duplicateReport {
                DuplicateReportSheet(report: report)
            }
        }
        .sheet(isPresented: $appState.showingPreferences) {
            PreferencesView()
                .environmentObject(appState)
        }
        .alert("common.error".localized, isPresented: $appState.showingError) {
            Button("common.ok".localized) {}
        } message: {
            Text(appState.errorMessage)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedTab) {
            Section("nav.overview".localized) {
                Label("nav.plugins".localized, systemImage: "puzzlepiece.extension")
                    .tag(AppState.MainTab.plugins)
                    .onTapGesture {
                        appState.selectedTab = .plugins
                        appState.clearEditorSelection()
                    }

                Label("nav.editors".localized, systemImage: "chevron.left.forwardslash.chevron.right")
                    .tag(AppState.MainTab.editors)
                    .onTapGesture {
                        appState.selectedTab = .editors
                        appState.clearEditorSelection()
                    }

                Label("nav.duplicates".localized, systemImage: "doc.on.doc")
                    .tag(AppState.MainTab.duplicates)
                    .onTapGesture {
                        appState.selectedTab = .duplicates
                        appState.clearEditorSelection()
                    }
            }

            Section("nav.actions".localized) {
                Button {
                    Task {
                        await appState.scanAllEditors()
                    }
                } label: {
                    Label("editor.scan".localized, systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoading)

                Button {
                    Task {
                        await appState.detectDuplicates()
                    }
                } label: {
                    Label("duplicate.detect".localized, systemImage: "magnifyingglass")
                }
                .disabled(appState.isLoading)
            }

            Section("nav.editors".localized) {
                ForEach(appState.editors) { editor in
                    Text(editor.name)
                        .tag(editor)
                        .onTapGesture {
                            appState.selectedTab = .editors
                            appState.selectedEditorForDetail = editor
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        appState.removeEditor(appState.editors[index])
                    }
                }
            }

            Section("nav.settings".localized) {
                Label("nav.settings".localized, systemImage: "gear")
                    .tag(AppState.MainTab.settings)
                    .onTapGesture {
                        appState.selectedTab = .settings
                        appState.clearEditorSelection()
                    }
            }
        }
        .navigationTitle("app.name".localized)
        .listStyle(.sidebar)
    }
}

// MARK: - Detail Content View

struct DetailContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let selectedEditor = appState.selectedEditorForDetail {
                EditorDetailView(editor: selectedEditor)
                    .navigationTitle(selectedEditor.name)
            } else {
                switch appState.selectedTab {
                case .plugins:
                    PluginListView()
                        .navigationTitle("nav.plugins".localized)
                case .editors:
                    EditorListView()
                        .navigationTitle("nav.editors".localized)
                case .duplicates:
                    DuplicateListView()
                        .navigationTitle("nav.duplicates".localized)
                case .settings:
                    SettingsView()
                        .navigationTitle("nav.settings".localized)
                }
            }
        }
    }
}

// MARK: - Editor Sidebar Item

struct EditorSidebarItem: View {
    let editor: Editor

    var body: some View {
        HStack {
            Image(systemName: editor.type.iconName)
                .foregroundStyle(.secondary)
            Text(editor.name)

            Spacer()

            if let lastScan = editor.lastScanDate {
                Text(lastScan, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Main Content

struct MainContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedTab {
            case .plugins:
                PluginListView()
            case .editors:
                EditorListView()
            case .duplicates:
                DuplicateListView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
