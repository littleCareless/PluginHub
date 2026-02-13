import SwiftUI

// MARK: - Duplicate List View

struct DuplicateListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button {
                    Task {
                        await appState.detectDuplicates()
                    }
                } label: {
                    Label("duplicate.detect".localized, systemImage: "magnifyingglass")
                }
                .disabled(appState.isLoading)

                Spacer()

                if let report = appState.duplicateReport {
                    Label("\(report.totalDuplicates) \("duplicate.count".localized)", systemImage: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 重复列表
            if let report = appState.duplicateReport {
                DuplicateReportContentView(report: report)
            } else {
                EmptyStateView(
                    icon: "doc.on.doc",
                    title: "duplicate.noDuplicates".localized,
                    message: "duplicate.noDuplicatesMessage".localized
                )
            }
        }
        .navigationTitle("duplicate.title".localized)
    }
}

// MARK: - Duplicate Report Content

struct DuplicateReportContentView: View {
    let report: DuplicateReport
    @EnvironmentObject var appState: AppState
    @State private var selectedGroup: DuplicatePluginGroup?
    @State private var showingOptimizationPlan = false

    var body: some View {
        VStack(spacing: 0) {
            // 统计摘要
            DuplicateSummaryView(report: report)

            Divider()

            // 重复组列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(report.groups) { group in
                        DuplicateGroupCard(
                            group: group,
                            isSelected: selectedGroup?.id == group.id,
                            onSelect: {
                                selectedGroup = group
                            }
                        )
                    }
                }
                .padding()
            }

            // 操作按钮
            HStack {
                Button("duplicate.optimizationSuggestions".localized) {
                    showingOptimizationPlan = true
                }

                Spacer()

                Button("duplicate.applyToAll".localized) {
                    Task {
                        await applyOptimization()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showingOptimizationPlan) {
            OptimizationPlanSheet(report: report)
        }
    }

    private func applyOptimization() async {
        let plan = DeduplicatorService.shared.createOptimizationPlan(for: report)

        do {
            try await DeduplicatorService.shared.executePlan(plan) { progress in
                // 更新进度
            }

            await appState.detectDuplicates()
        } catch {
            appState.errorMessage = error.localizedDescription
            appState.showingError = true
        }
    }
}

// MARK: - Duplicate Summary

struct DuplicateSummaryView: View {
    let report: DuplicateReport

    var body: some View {
        HStack(spacing: 24) {
            StatCard(
                title: "duplicate.stats.plugins".localized,
                value: "\(report.groups.count)",
                icon: "doc.on.doc",
                color: .orange
            )

            StatCard(
                title: "duplicate.stats.instances".localized,
                value: "\(report.totalDuplicates)",
                icon: "square.on.square",
                color: .red
            )

            StatCard(
                title: "duplicate.stats.space".localized,
                value: report.formattedWastedSpace,
                icon: "internaldrive",
                color: .green
            )

            StatCard(
                title: "duplicate.stats.editors".localized,
                value: "\(report.editors.count)",
                icon: "chevron.left.forwardslash.chevron.right",
                color: .blue
            )
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Duplicate Group Card

struct DuplicateGroupCard: View {
    let group: DuplicatePluginGroup
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack {
                Text(group.displayName)
                    .font(.headline)

                Spacer()

                if group.isVersionConflict {
                    Label("duplicate.versionConflict".localized, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // 实例列表
            VStack(spacing: 4) {
                ForEach(Array(group.instances.enumerated()), id: \.element.id) { index, instance in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text(instance.editorName)
                            .font(.caption)

                        if let version = instance.version {
                            Text("v\(version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(instance.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if index == 0 {
                            Label("duplicate.masterCopy".localized, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Optimization Plan Sheet

struct OptimizationPlanSheet: View {
    let report: DuplicateReport
    @Environment(\.dismiss) private var dismiss
    @State private var plan: OptimizationPlan?
    @State private var isExecuting = false
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("duplicate.optimizationSuggestions".localized)
                    .font(.headline)

                Spacer()

                Button("common.close".localized) {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 内容
            if let plan = plan {
                List {
                    Section("duplicate.summary".localized) {
                        HStack {
                            Text("duplicate.stats.space".localized)
                            Spacer()
                            Text(plan.formattedSpaceSaved)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("duplicate.actionCount".localized)
                            Spacer()
                            Text("\(plan.actions.count)")
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("duplicate.estimatedTime".localized)
                            Spacer()
                            Text("duplicate.estimatedTimeSeconds".localized(plan.estimatedTime))
                                .fontWeight(.medium)
                        }
                    }

                    Section("duplicate.actionDetails".localized) {
                        ForEach(Array(plan.actions.prefix(20).enumerated()), id: \.element) { index, action in
                            HStack {
                                switch action {
                                case .link(_, _, let targetPath, let editorName):
                                    Image(systemName: "link")
                                        .foregroundStyle(.blue)
                                    Text("duplicate.action.link".localized(URL(fileURLWithPath: targetPath).lastPathComponent, editorName))

                                case .remove(_, let path, let editorName):
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                    Text("duplicate.action.remove".localized(URL(fileURLWithPath: path).lastPathComponent, editorName))

                                case .cleanup(let path):
                                    Image(systemName: "trash")
                                        .foregroundStyle(.orange)
                                    Text("duplicate.action.cleanup".localized(URL(fileURLWithPath: path).lastPathComponent))
                                }
                            }
                        }

                        if plan.actions.count > 20 {
                            Text("...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 进度条
                if isExecuting {
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "duplicate.generatingPlan".localized,
                    systemImage: "gear",
                    description: Text("duplicate.analyzing".localized)
                )
                .frame(height: 200)
            }

            Divider()

            // 操作按钮
            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }

                Spacer()

                Button("duplicate.executeOptimization".localized) {
                    executePlan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            plan = DeduplicatorService.shared.createOptimizationPlan(for: report)
        }
    }

    private func executePlan() {
        guard let plan = plan else { return }

        isExecuting = true

        Task {
            do {
                try await DeduplicatorService.shared.executePlan(plan) { progressValue in
                    Task { @MainActor in
                        progress = progressValue
                    }
                }
                dismiss()
            } catch {
                // 处理错误
            }
        }
    }
}

// MARK: - Duplicate Report Sheet

struct DuplicateReportSheet: View {
    let report: DuplicateReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DuplicateReportContentView(report: report)
                .navigationTitle("duplicate.reportTitle".localized)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done".localized) {
                            dismiss()
                        }
                    }
                }
        }
    }
}
