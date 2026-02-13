import SwiftUI

// MARK: - Editor List View

struct EditorListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button {
                    Task {
                        await appState.scanAllEditors()
                    }
                } label: {
                    Label("plugin.scanAll".localized, systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoading)

                Spacer()

                Button {
                    // 添加编辑器
                } label: {
                    Label("editor.add".localized, systemImage: "plus")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 编辑器卡片
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appState.editors) { editor in
                        EditorCardView(editor: editor)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("editor.title".localized)
    }
}

// MARK: - Editor Card

struct EditorCardView: View {
    let editor: Editor
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // 图标 - 优先显示真实应用图标
            if let appIcon = editor.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: editor.type.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(10)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(editor.name)
                        .font(.headline)

                    if !editor.isEnabled {
                        Text("editor.disabled".localized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(editor.expandedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Label("\(pluginCount)", systemImage: "puzzlepiece.extension")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastScan = editor.lastScanDate {
                        Text(lastScan, format: .dateTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 操作按钮
            VStack(spacing: 8) {
                Menu {
                    Button {
                        Task {
                            await appState.scanEditor(editor)
                        }
                    } label: {
                        Label("editor.scanPlugins".localized, systemImage: "arrow.clockwise")
                    }

                    Button {
                        // 打开插件目录
                    } label: {
                        Label("editor.openDir".localized, systemImage: "folder")
                    }

                    Divider()

                    Button {
                        // 编辑配置
                    } label: {
                        Label("editor.editConfig".localized, systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await appState.scanEditor(editor)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .disabled(appState.isLoading)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .contextMenu {
            Button {
                Task {
                    await appState.scanEditor(editor)
                }
            } label: {
                Label("editor.scanPlugins".localized, systemImage: "arrow.clockwise")
            }

            Button {
                // 打开插件目录
                NSWorkspace.shared.open(URL(fileURLWithPath: editor.expandedPath))
            } label: {
                Label("editor.openDir".localized, systemImage: "folder")
            }

            Divider()

            Button {
                // 编辑配置
            } label: {
                Label("editor.editConfig".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                appState.removeEditor(editor)
            } label: {
                Label("editor.remove".localized, systemImage: "trash")
            }
        }
    }

    private var pluginCount: Int {
        appState.pluginsByEditor[editor.id]?.count ?? 0
    }
}

// MARK: - Editor Detail View

struct EditorDetailView: View {
    let editor: Editor
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                // 图标 - 优先显示真实应用图标
                if let appIcon = editor.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: editor.type.iconName)
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading) {
                    Text(editor.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(editor.expandedPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await appState.scanEditor(editor)
                    }
                } label: {
                    Label("common.scan".localized, systemImage: "arrow.clockwise")
                }
                .disabled(appState.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 插件列表
            if let plugins = appState.pluginsByEditor[editor.id] {
                List(plugins) { plugin in
                    HStack {
                        PluginIconView(plugin: plugin)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading) {
                            Text(plugin.displayName)
                                .font(.body)

                            Text(plugin.version ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if PluginStoreService.shared.isPluginLinked(plugin, to: editor) {
                            Label("plugin.linked".localized, systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "puzzlepiece.extension",
                    title: "editor.notScanned".localized,
                    message: "editor.clickToScan".localized
                )
            }
        }
        .navigationTitle(editor.name)
        .onAppear {
            Task {
                if appState.pluginsByEditor[editor.id] == nil {
                    await appState.scanEditor(editor)
                }
            }
        }
    }
}
