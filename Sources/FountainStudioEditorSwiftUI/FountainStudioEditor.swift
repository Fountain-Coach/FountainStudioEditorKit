import SwiftUI
import AppKit
import FountainStudioEditorAppKit

public struct FountainStudioEditor: NSViewRepresentable {
    @Binding private var text: String
    private let configuration: EditorConfiguration

    public init(text: Binding<String>, configuration: EditorConfiguration = EditorConfiguration()) {
        self._text = text
        self.configuration = configuration
    }

    public func makeCoordinator() -> EditorTextViewHost {
        EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: configuration
        )
    }

    public func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.update(scrollView: nsView)
    }
}
