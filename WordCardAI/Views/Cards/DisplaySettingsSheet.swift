// DisplaySettingsSheet.swift
// カード表示設定（裏から表示・ステータスフィルター等）

import SwiftUI

struct DisplaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var showBackFirst: Bool
    let cards: [WordCard]
    @Binding var currentIndex: Int

    // フィルター（表示するステータス）
    @State private var filterStatuses: Set<LearningStatus> = Set(LearningStatus.allCases)

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
                        let count = cards.filter { $0.learningStatus == status }.count
                        HStack {
                            Label {
                                Text(status.displayName)
                            } icon: {
                                Image(systemName: filterStatuses.contains(status) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(filterStatuses.contains(status) ? statusColor(status) : .secondary)
                            }
                            Spacer()
                            Text("\(count)枚")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggleFilter(status) }
                    }
                } header: {
                    Text("表示するステータス")
                } footer: {
                    Text("オフにしたステータスのカードはスキップされます（準備中）")
                        .font(.caption2)
                }
            }
            .navigationTitle("表示設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func toggleFilter(_ status: LearningStatus) {
        if filterStatuses.contains(status) {
            // 最低1つは残す
            if filterStatuses.count > 1 { filterStatuses.remove(status) }
        } else {
            filterStatuses.insert(status)
        }
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
