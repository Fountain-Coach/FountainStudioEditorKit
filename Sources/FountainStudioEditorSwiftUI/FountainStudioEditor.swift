import SwiftUI
import AppKit
import FountainStudioEditorAppKit
import FountainStudioEditorCore

public struct FountainStudioEditor: NSViewRepresentable {
    @Binding private var text: String
    private let configuration: EditorConfiguration
    private let markerProvider: any EditorMarkerProvider
    private let virtualizationPolicy: any EditorVirtualizationPolicy
    private let dragPayloadCodec: any EditorDragPayloadCodec
    private let onTextViewReady: ((NSTextView) -> Void)?

    public init(
        text: Binding<String>,
        configuration: EditorConfiguration = EditorConfiguration(),
        markerProvider: any EditorMarkerProvider = BasicMarkerProvider(),
        virtualizationPolicy: any EditorVirtualizationPolicy = BracketMarkerVirtualizationPolicy(),
        dragPayloadCodec: any EditorDragPayloadCodec = StorifyAnchorPayloadCodec(),
        onTextViewReady: ((NSTextView) -> Void)? = nil
    ) {
        self._text = text
        self.configuration = configuration
        self.markerProvider = markerProvider
        self.virtualizationPolicy = virtualizationPolicy
        self.dragPayloadCodec = dragPayloadCodec
        self.onTextViewReady = onTextViewReady
    }

    public func makeCoordinator() -> EditorTextViewHost {
        EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: configuration,
            markerProvider: markerProvider,
            virtualizationPolicy: virtualizationPolicy,
            dragPayloadCodec: dragPayloadCodec,
            onTextViewReady: onTextViewReady
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
