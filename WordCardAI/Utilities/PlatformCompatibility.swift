import SwiftUI

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

typealias UIColor = NSColor
typealias UIFont = NSFont

extension NSColor {
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemBackground: NSColor { .underPageBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var label: NSColor { .labelColor }
}

extension Color {
    init(uiColor: NSColor) {
        self.init(nsColor: uiColor)
    }
}
#endif
