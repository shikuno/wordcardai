import SwiftUI

#if canImport(UIKit)
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
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
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

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let fallbackWidth = uiView.window?.windowScene?.screen.bounds.width ?? max(uiView.bounds.width, 320)
        let width = proposal.width ?? fallbackWidth
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let fitted = uiView.sizeThatFits(targetSize)
        return CGSize(width: width, height: ceil(fitted.height))
    }
}
#elseif canImport(AppKit)
import AppKit

struct SelectableTextView: NSViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 16)
    var textColor: UIColor = .label
    var backgroundColor: UIColor = .clear

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.string = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width,
              let textView = nsView.documentView as? NSTextView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else {
            return nil
        }

        textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        return CGSize(width: width, height: ceil(used.height))
    }
}
#endif
