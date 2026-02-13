import SwiftUI

struct PluginListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            PluginToolbarView()
            Divider()

            if appState.isLoading {
                LoadingView(message: "common.loading".localized)
            } else if appState.allPlugins.isEmpty {
                EmptyStateView(
                    icon: "puzzlepiece.extension",
                    title: "plugin.noPlugins".localized,
                    message: "plugin.noPluginsMessage".localized
                )
            } else {
                PluginTableView()
            }
        }
        .navigationTitle("plugin.title".localized)
    }
}

// MARK: - Plugin Toolbar

struct PluginToolbarView: View {
    @EnvironmentObject var appState: AppState

    private var selectedCount: Int {
        appState.selectedPlugins.count
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("plugin.searchPlaceholder".localized, text: $appState.searchText)
                    .textFieldStyle(.plain)

                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: 360)

            Text("plugin.count".localized(appState.filteredPlugins.count))
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Picker("sort.title".localized, selection: $appState.sortOption) {
                ForEach(AppState.SortOption.allCases, id: \.self) { option in
                    Text(option.localizedTitle).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            Menu {
                if appState.editors.isEmpty {
                    Text("editor.noneAvailable".localized)
                } else {
                    ForEach(appState.editors) { editor in
                        Button {
                            Task {
                                await appState.linkSelectedPluginsToEditor(editor)
                            }
                        } label: {
                            Label("plugin.linkToEditor".localized(editor.name), systemImage: "link")
                        }
                        .disabled(selectedCount == 0)
                    }

                    Divider()

                    Button {
                        Task {
                            let selectedPlugins = appState.allPlugins.filter { appState.selectedPlugins.contains($0.id) }
                            guard !selectedPlugins.isEmpty else { return }

                            for editor in appState.editors where editor.isEnabled {
                                await appState.linkPlugins(selectedPlugins, to: editor)
                            }
                            appState.selectedPlugins.removeAll()
                        }
                    } label: {
                        Label("plugin.linkToAllEnabled".localized, systemImage: "link.circle")
                    }
                    .disabled(selectedCount == 0)
                }
            } label: {
                Label("plugin.bulkActions".localized, systemImage: "ellipsis.circle")
            }
            .disabled(appState.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Plugin Table View

struct PluginTableView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Table(appState.filteredPlugins, selection: $appState.selectedPlugins) {
            TableColumn("duplicate.plugin".localized) { plugin in
                PluginNameCell(plugin: plugin)
            }
            .width(min: 280, ideal: 360, max: 520)

            TableColumn("plugin.publisher".localized) { plugin in
                Text(plugin.publisherId)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 120, ideal: 160, max: 220)

            TableColumn("plugin.version".localized) { plugin in
                HStack(spacing: 6) {
                    Text(plugin.version ?? "common.unknown".localized)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if plugin.hasUpdate {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                            .help("plugin.updateAvailable".localized)
                    }
                }
            }
            .width(min: 88, ideal: 100, max: 120)

            TableColumn("plugin.source".localized) { plugin in
                Text(plugin.source.displayText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 70, ideal: 84, max: 96)

            TableColumn("plugin.status".localized) { plugin in
                PluginStatusBadge(plugin: plugin)
            }
            .width(min: 88, ideal: 96, max: 112)

            TableColumn("nav.editors".localized) { plugin in
                PluginEditorsColumn(
                    plugin: plugin,
                    editors: appState.editors,
                    pluginsByEditor: appState.pluginsByEditor
                )
            }
            .width(min: 90, ideal: 120, max: 160)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Cells

struct PluginNameCell: View {
    let plugin: Plugin

    var body: some View {
        HStack(spacing: 8) {
            PluginIconView(plugin: plugin)

            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.displayName)
                    .lineLimit(1)

                Text(plugin.uniqueId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PluginEditorsColumn: View {
    let plugin: Plugin
    let editors: [Editor]
    let pluginsByEditor: [UUID: [Plugin]]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(linkedEditors.prefix(2)) { editor in
                Image(systemName: editor.type.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if linkedEditors.count > 2 {
                Text("+\(linkedEditors.count - 2)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if linkedEditors.isEmpty {
                Text("-")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var linkedEditors: [Editor] {
        editors.filter { editor in
            pluginsByEditor[editor.id]?.contains(where: { $0.uniqueId == plugin.uniqueId }) ?? false
        }
    }
}

// MARK: - Shared UI

struct PluginIconView: View {
    let plugin: Plugin
    @State private var iconImage: NSImage?

    var body: some View {
        Group {
            if let iconImage {
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "puzzlepiece.extension")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
        .onAppear { loadIcon() }
    }

    private func loadIcon() {
        guard !plugin.fullPath.isEmpty else { return }

        let iconPath = URL(fileURLWithPath: plugin.fullPath)
            .appendingPathComponent("icon.png")
            .path

        if FileManager.default.fileExists(atPath: iconPath) {
            iconImage = NSImage(contentsOfFile: iconPath)
        }
    }
}

struct PluginStatusBadge: View {
    let plugin: Plugin

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch plugin.source {
        case .local:
            return .blue
        case .linked:
            return .green
        case .marketplace:
            return .orange
        }
    }

    private var statusText: String {
        switch plugin.source {
        case .local:
            return "plugin.source.local".localized
        case .linked:
            return "plugin.source.linked".localized
        case .marketplace:
            return "plugin.source.marketplace".localized
        }
    }
}

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private extension PluginSource {
    var displayText: String {
        switch self {
        case .local:
            return "plugin.source.local".localized
        case .linked:
            return "plugin.source.linkedShort".localized
        case .marketplace:
            return "plugin.source.marketplace".localized
        }
    }
}

#Preview {
    PluginListView()
        .environmentObject(AppState())
        .frame(minWidth: 900, minHeight: 560)
}
