import AppKit
import FountainStudioEditorCore

public struct EditorTheme: Equatable {
    public var backgroundColor: NSColor
    public var plainTextColor: NSColor

    public init(backgroundColor: NSColor, plainTextColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.plainTextColor = plainTextColor
    }

    public static var `default`: EditorTheme {
        EditorTheme(backgroundColor: .textBackgroundColor, plainTextColor: .labelColor)
    }
}

public struct EditorConfiguration: Equatable {
    public var font: NSFont
    public var theme: EditorTheme
    public var isEditable: Bool
    public var featureFlags: EditorFeatureFlags

    public init(
        font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular),
        theme: EditorTheme = .default,
        isEditable: Bool = true,
        featureFlags: EditorFeatureFlags = EditorFeatureFlags()
    ) {
        self.font = font
        self.theme = theme
        self.isEditable = isEditable
        self.featureFlags = featureFlags
    }
}
