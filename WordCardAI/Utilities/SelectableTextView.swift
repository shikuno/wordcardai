// SelectableTextView.swift
// UITextView ラッパー：iOS の textSelection が効かない場合の部分コピー対応
import SwiftUI
import UIKit

/// テキスト選択・部分コピーができる読み取り専用テキストビュー
struct SelectableTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 16)
    var textColor: UIColor = .label
    var backgroundColor: UIColor = .clear

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.backgroundColor = backgroundColor
        tv.dataDetectorTypes = []
        // テキストコンテナの折り返しを単語単位に強制
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.font = font
        uiView.textColor = textColor
        uiView.backgroundColor = backgroundColor
        uiView.text = text
    }
}
