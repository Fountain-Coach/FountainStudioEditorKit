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
}
