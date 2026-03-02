import AppKit
import Foundation
import FountainStudioEditorCore

@MainActor
public final class EditorTextViewHost: NSObject, NSTextViewDelegate {
    private let textBindingGet: () -> String
    private let textBindingSet: (String) -> Void
    public var configuration: EditorConfiguration
    private var isApplyingExternalUpdate = false
    private(set) weak var textView: NSTextView?

    public init(
        textBindingGet: @escaping () -> String,
        textBindingSet: @escaping (String) -> Void,
        configuration: EditorConfiguration
    ) {
        self.textBindingGet = textBindingGet
        self.textBindingSet = textBindingSet
        self.configuration = configuration
    }

    public func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = configuration.theme.backgroundColor

        let textView = NSTextView()
        textView.isEditable = configuration.isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = configuration.font
        textView.textColor = configuration.theme.plainTextColor
        textView.backgroundColor = configuration.theme.backgroundColor
        textView.insertionPointColor = configuration.theme.plainTextColor
        textView.string = textBindingGet()
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self

        scrollView.documentView = textView
        self.textView = textView
        return scrollView
    }

    public func update(scrollView: NSScrollView) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        scrollView.backgroundColor = configuration.theme.backgroundColor
        textView.font = configuration.font
        textView.isEditable = configuration.isEditable
        textView.textColor = configuration.theme.plainTextColor
        textView.insertionPointColor = configuration.theme.plainTextColor
        textView.backgroundColor = configuration.theme.backgroundColor

        let expected = textBindingGet()
        guard !textView.hasMarkedText() else { return }
        guard textView.string != expected else { return }
        isApplyingExternalUpdate = true
        let selected = textView.selectedRanges
        textView.string = expected
        textView.selectedRanges = selected
        isApplyingExternalUpdate = false
    }

    public func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalUpdate else { return }
        guard let textView else { return }
        textBindingSet(textView.string)
    }
}
