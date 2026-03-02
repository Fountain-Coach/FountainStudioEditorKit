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
}
