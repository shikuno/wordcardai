// ConversationView.swift
// ロールプレイ会話練習画面

import SwiftUI

struct ConversationView: View {
    let cards: [WordCard]
    let collectionTitle: String

    @StateObject private var vm = ConversationViewModel()
    @Environment(\.dismiss) private var dismiss

    // 設定
    @State private var turnCount: Int = 5
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .loading:
                    loadingView
                case .error(let msg):
                    errorView(msg)
                case .finished:
                    finishedView
                default:
                    practiceView
                }
            }
            .navigationTitle("会話練習")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        vm.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(vm.session == nil)
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
        }
        .task {
            await vm.start(cards: cards, turnCount: turnCount)
        }
        .interactiveDismissDisabled(vm.session != nil)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text("AIが会話を生成中…")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("使用フレーズ数: \(min(turnCount, cards.count))個")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Practice

    private var practiceView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 進捗
                HStack {
                    Text("ターン \(vm.progress)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // 相手のセリフカード
                if let turn = vm.currentTurn {
                    partnerCard(turn: turn)
                    myResponseCard(turn: turn)
                }

                actionButtons
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
    }

    // 相手のセリフ
    private func partnerCard(turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("相手のセリフ", systemImage: "person.bubble.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            // 英語
            Text(turn.partnerEnglish)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            // 日本語訳
            Text(turn.partnerJapanese)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 再生ボタン
            Button {
                vm.speakPartner()
            } label: {
                Label("もう一度聞く", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // 自分の返答エリア
    private func myResponseCard(turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("あなたの返答", systemImage: "person.fill")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            switch vm.phase {

            case .partnerSpeaking:
                // 相手が話している間はヒントを隠す
                VStack(alignment: .leading, spacing: 8) {
                    Text("どう返しますか？考えてみましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        vm.showHintAndCountdown()
                    } label: {
                        Text("ヒントを見てシンキングタイムへ")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .showHint, .thinkingCountdown:
                // ヒント表示 + カウントダウン
                VStack(alignment: .leading, spacing: 10) {
                    Text("ヒント（日本語）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(turn.myHintJapanese)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    HStack {
                        Text("英語で言ってみよう")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        // カウントダウン
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: CGFloat(vm.countdown) / CGFloat(max(vm.thinkingSeconds, 1)))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: vm.countdown)
                            Text("\(vm.countdown)")
                                .font(.headline.monospacedDigit())
                        }
                    }

                    Button {
                        vm.revealAnswer()
                    } label: {
                        Text("答えを見る")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }

            case .showAnswer, .nextReady:
                // 正解表示
                VStack(alignment: .leading, spacing: 8) {
                    Text("ヒント（日本語）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(turn.myHintJapanese)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Text("正解の英語")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(turn.myEnglish)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)

                    if case .nextReady = vm.phase {
                        Button {
                            vm.speakAnswer()
                        } label: {
                            Label("もう一度聞く", systemImage: "speaker.wave.2.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("読み上げ中…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

            default:
                EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // アクションボタン
    private var actionButtons: some View {
        Group {
            if case .nextReady = vm.phase {
                Button {
                    vm.goNext()
                } label: {
                    HStack(spacing: 8) {
                        Text(vm.isLastTurn ? "練習を終了" : "次のターンへ")
                            .fontWeight(.semibold)
                        Image(systemName: vm.isLastTurn ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            Text("練習完了！")
                .font(.largeTitle.bold())
            Text("\(vm.session?.turns.count ?? 0)つのフレーズを使った会話を練習しました")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button {
                    Task { await vm.start(cards: cards, turnCount: turnCount) }
                } label: {
                    Label("もう一度（別の会話）", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    vm.stop()
                    dismiss()
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("会話を生成できませんでした")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.start(cards: cards, turnCount: turnCount) }
            } label: {
                Label("もう一度試す", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "ターン数: \(min(turnCount, cards.count))問",
                        value: $turnCount,
                        in: 1...min(10, cards.count)
                    )
                    Stepper(
                        "シンキングタイム: \(vm.thinkingSeconds)秒",
                        value: $vm.thinkingSeconds,
                        in: 3...30
                    )
                } header: {
                    Text("練習設定")
                } footer: {
                    Text("設定変更は次の練習から反映されます")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
