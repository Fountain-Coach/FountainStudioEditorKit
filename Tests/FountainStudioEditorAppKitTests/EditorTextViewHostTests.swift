import XCTest
import AppKit
@testable import FountainStudioEditorAppKit
@testable import FountainStudioEditorCore

@MainActor
final class EditorTextViewHostTests: XCTestCase {
    func testHostRoundTripsTextFromTextView() {
        var text = "A"
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: EditorConfiguration()
        )
        let scroll = host.makeScrollView()
        guard let textView = scroll.documentView as? NSTextView else {
            return XCTFail("missing text view")
        }
        textView.string = "B"
        host.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        XCTAssertEqual(text, "B")
    }

    func testFocusedOverlayEnablesVerticalRuler() {
        var text = "[[CUT UNIT 1: SETUP]]\nBODY\n"
        let config = EditorConfiguration(
            featureFlags: EditorFeatureFlags(
                lineNumberMode: .visibleOnly,
                markerPresentationMode: .gutterOverlay,
                dragAnchorsEnabled: true
            )
        )
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: config
        )
        let scroll = host.makeScrollView()
        XCTAssertTrue(scroll.hasVerticalRuler)
        XCTAssertNotNil(scroll.verticalRulerView)
    }

    func testInlineModeDisablesVerticalRulerByDefault() {
        var text = "[[CUT UNIT 1: SETUP]]\nBODY\n"
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: EditorConfiguration()
        )
        let scroll = host.makeScrollView()
        XCTAssertFalse(scroll.hasVerticalRuler)
        XCTAssertNil(scroll.verticalRulerView)
    }

    func testGutterOverlayMasksVirtualMarkerGlyphsInline() {
        var text = """
        [[CUT UNIT 1: SETUP]]
        BODY
        .CUT UNIT 2: TURN
        """
        let config = EditorConfiguration(
            featureFlags: EditorFeatureFlags(
                lineNumberMode: .visibleOnly,
                markerPresentationMode: .gutterOverlay,
                dragAnchorsEnabled: true
            )
        )
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: config
        )
        let scroll = host.makeScrollView()
        guard let textView = scroll.documentView as? NSTextView,
              let storage = textView.textStorage else {
            return XCTFail("missing text storage")
        }
        let ns = text as NSString
        let marker1 = ns.range(of: "[[CUT UNIT 1: SETUP]]")
        let marker2 = ns.range(of: ".CUT UNIT 2: TURN")
        let body = ns.range(of: "BODY")
        XCTAssertNotEqual(marker1.location, NSNotFound)
        XCTAssertNotEqual(marker2.location, NSNotFound)
        XCTAssertNotEqual(body.location, NSNotFound)

        let marker1Font = storage.attribute(.font, at: marker1.location, effectiveRange: nil) as? NSFont
        let marker2Font = storage.attribute(.font, at: marker2.location, effectiveRange: nil) as? NSFont
        let bodyFont = storage.attribute(.font, at: body.location, effectiveRange: nil) as? NSFont

        XCTAssertLessThan(marker1Font?.pointSize ?? 99, 1.0)
        XCTAssertLessThan(marker2Font?.pointSize ?? 99, 1.0)
        XCTAssertGreaterThanOrEqual(bodyFont?.pointSize ?? 0, 10.0)
    }

    func testGutterOverlaySuppressesMaskWhenAllLinesWouldVirtualize() {
        var text = """
        [[CUT UNIT 1: SETUP]]
        [[WINDOW:window-0 range=1-32]]
        .CUT UNIT 2: TURN
        """
        var diagnostics: [EditorRuntimeDiagnostic] = []
        let config = EditorConfiguration(
            featureFlags: EditorFeatureFlags(
                lineNumberMode: .visibleOnly,
                markerPresentationMode: .gutterOverlay,
                dragAnchorsEnabled: true
            )
        )
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: config,
            onDiagnostic: { diagnostics.append($0) }
        )
        let scroll = host.makeScrollView()
        guard let textView = scroll.documentView as? NSTextView,
              let storage = textView.textStorage else {
            return XCTFail("missing text storage")
        }
        let ns = text as NSString
        let marker = ns.range(of: "[[CUT UNIT 1: SETUP]]")
        XCTAssertNotEqual(marker.location, NSNotFound)
        let markerFont = storage.attribute(.font, at: marker.location, effectiveRange: nil) as? NSFont
        XCTAssertGreaterThanOrEqual(markerFont?.pointSize ?? 0, 10.0)
        XCTAssertEqual(diagnostics.last?.kind, .virtualizationMaskSuppressed)
    }

    func testGutterOverlayRestoresMaskAfterVisibleContentReturns() {
        var text = """
        [[CUT UNIT 1: SETUP]]
        [[WINDOW:window-0 range=1-32]]
        """
        var diagnostics: [EditorRuntimeDiagnostic] = []
        let config = EditorConfiguration(
            featureFlags: EditorFeatureFlags(
                lineNumberMode: .visibleOnly,
                markerPresentationMode: .gutterOverlay,
                dragAnchorsEnabled: true
            )
        )
        let host = EditorTextViewHost(
            textBindingGet: { text },
            textBindingSet: { text = $0 },
            configuration: config,
            onDiagnostic: { diagnostics.append($0) }
        )
        let scroll = host.makeScrollView()
        text = """
        [[CUT UNIT 1: SETUP]]
        BODY
        """
        host.update(scrollView: scroll)
        guard let textView = scroll.documentView as? NSTextView,
              let storage = textView.textStorage else {
            return XCTFail("missing text storage")
        }
        let ns = text as NSString
        let marker = ns.range(of: "[[CUT UNIT 1: SETUP]]")
        XCTAssertNotEqual(marker.location, NSNotFound)
        let markerFont = storage.attribute(.font, at: marker.location, effectiveRange: nil) as? NSFont
        XCTAssertLessThan(markerFont?.pointSize ?? 99, 1.0)
        XCTAssertEqual(diagnostics.map(\.kind), [.virtualizationMaskSuppressed, .virtualizationMaskRestored])
    }
}
