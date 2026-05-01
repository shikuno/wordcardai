// DisplaySettingsSheet.swift
// カード表示設定（裏から表示・ステータスフィルター等）

import SwiftUI

struct DisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var showBackFirst: Bool
    @Binding var filterStatuses: Set<LearningStatus>
    let allCards: [WordCard]
    let onApply: (Set<LearningStatus>) -> Void

    var body: some View {
        NavigationStack {
            List {
                // ── 表示順 ──
                Section("カード表示") {
                    Toggle(isOn: $showBackFirst) {
                        Label("裏面（英語）から表示", systemImage: "arrow.left.arrow.right")
                    }
                    .tint(.orange)
                }

                // ── ステータスフィルター ──
                Section {
                    ForEach(LearningStatus.allCases, id: \.self) { status in
                        let count = allCards.filter { $0.learningStatus == status }.count
                        HStack {
                            Image(systemName: filterStatuses.contains(status)
                                ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(filterStatuses.contains(status)
                                    ? statusColor(status) : .secondary)
                            Text(status.displayName)
                            Spacer()
                            Text("\(count)枚")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(status) }
                    }
                } header: {
                    Text("表示するステータス")
                } footer: {
                    Text("選択したステータスのカードのみ表示します")
                        .font(.caption2)
                }

                // ── 全選択・全解除 ──
                Section {
                    Button("すべて表示") {
                        filterStatuses = Set(LearningStatus.allCases)
                        onApply(filterStatuses)
                    }
                }
            }
            .navigationTitle("表示設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onApply(filterStatuses)
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggle(_ status: LearningStatus) {
        if filterStatuses.contains(status) {
            if filterStatuses.count > 1 { filterStatuses.remove(status) }
        } else {
            filterStatuses.insert(status)
        }
        onApply(filterStatuses)
    }

    private func statusColor(_ status: LearningStatus) -> Color {
        switch status {
        case .new:       return .blue
        case .notSure:   return .orange
        case .reviewing: return .purple
        case .mastered:  return .green
        }
    }
}
