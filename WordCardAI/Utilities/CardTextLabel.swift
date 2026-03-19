// CardTextLabel.swift
// UILabel ラッパー：SwiftUI Text の不正な折り返しを UIKit で根本解決
import SwiftUI
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
