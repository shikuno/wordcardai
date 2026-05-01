import SwiftUI

#if canImport(UIKit)
import UIKit

/// SwiftUI の Text では制御できない折り返し位置を
/// UILabel の lineBreakMode で正確に制御する
struct CardTextLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let alignment: NSTextAlignment

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = alignment
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.font = font
        uiView.textColor = color
        uiView.textAlignment = alignment
        uiView.text = text
    }
}
#elseif canImport(AppKit)
import AppKit

struct CardTextLabel: NSViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let alignment: NSTextAlignment

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.alignment = alignment
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.font = font
        nsView.textColor = color
        nsView.alignment = alignment
        nsView.stringValue = text
    }
}
#endif
