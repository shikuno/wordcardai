// AIChatView.swift
import SwiftUI

struct AIChatView: View {
    @StateObject private var vm = AIChatViewModel()
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "「なるほど」を英語で自然に言うには？",
        "I see と I understand の違いは？",
        "ビジネスメールで使える丁寧な断り方を教えて",
        "「お疲れ様です」に近い英語表現は？",
        "会話で使えるつなぎ言葉を教えて",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // メッセージ一覧
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if vm.messages.isEmpty {
                                suggestionsView
                            } else {
                                ForEach(vm.messages) { msg in
                                    MessageBubble(message: msg)
                                        .id(msg.id)
                                }
                                if vm.isLoading {
                                    loadingBubble
                                }
                                if let err = vm.errorMessage {
                                    errorBubble(err)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isLoading) { _, loading in
                        if loading, let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                inputBar
            }
            .navigationTitle("AI相談")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.messages.isEmpty {
                        Button {
                            withAnimation { vm.clear() }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("英語について何でも聞いてください", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit { vm.send() }

            Button {
                vm.send()
                inputFocused = false
            } label: {
                Image(systemName: vm.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - サジェスト（初期表示）

    private var suggestionsView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52))
                .foregroundColor(.blue.opacity(0.6))
            Text("英語学習について\n何でも相談できます")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        vm.inputText = s
                        vm.send()
                    } label: {
                        Text(s)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 20)
        }
    }

    // MARK: - ローディング

    private var loadingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            aiBadge
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: vm.isLoading
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            Spacer()
        }
        .id("loading")
    }

    private func errorBubble(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(msg).font(.caption).foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var aiBadge: some View {
        ZStack {
            Circle().fill(Color.blue).frame(width: 28, height: 28)
            Image(systemName: "sparkles").font(.system(size: 12)).foregroundColor(.white)
        }
    }
}

// MARK: - メッセージバブル

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
            } else {
                ZStack {
                    Circle().fill(Color.blue).frame(width: 28, height: 28)
                    Image(systemName: "sparkles").font(.system(size: 12)).foregroundColor(.white)
                }
                Text(.init(message.text))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    AIChatView()
}
