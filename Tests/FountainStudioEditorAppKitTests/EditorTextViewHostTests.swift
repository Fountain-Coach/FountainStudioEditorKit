import XCTest
import AppKit
@testable import FountainStudioEditorAppKit

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
}
