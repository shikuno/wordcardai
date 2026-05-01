import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// 翻訳・AI生成の候補を一覧表示して選択させるシート
struct CandidatePickerSheet: View {
    let title: String
    let candidates: [String]
    let targetLabel: String
    let debugInfo: String?        // デバッグ情報（プロンプト・AI生出力）
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var showDebugAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("\(targetLabel)に入れる内容を選んでください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("キャンセル") { onCancel() }
                    .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if candidates.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("生成中…")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                            Button {
                                onSelect(candidate)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(candidate)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 5)
                                    .onEnded { _ in
                                        guard index == 1, debugInfo != nil else { return }
                                        showDebugAlert = true
                                    }
                            )

                            if index < candidates.count - 1 {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
        .alert("AI デバッグ情報", isPresented: $showDebugAlert) {
            Button("クリップボードにコピー") {
                #if os(iOS)
                UIPasteboard.general.string = debugInfo ?? "(なし)"
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(debugInfo ?? "(なし)", forType: .string)
                #endif
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(debugInfo ?? "(なし)")
        }
    }
}

#Preview {
    CandidatePickerSheet(
        title: "翻訳結果",
        candidates: [
            "I'll take care of it.",
            "Leave it to me.",
            "I've got it covered."
        ],
        targetLabel: "裏面",
        debugInfo: "【入力テキスト】\nよろしくお願いします\n【プロンプト】\n...\n【AI生出力】\nI'll take care of it.",
        onSelect: { _ in },
        onCancel: {}
    )
}
