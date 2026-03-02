import XCTest
import SwiftUI
@testable import FountainStudioEditorSwiftUI

final class FountainStudioEditorSmokeTests: XCTestCase {
    @MainActor
    func testEditorConstructs() {
        var text = "hello"
        _ = FountainStudioEditor(text: Binding(get: { text }, set: { text = $0 }))
        XCTAssertEqual(text, "hello")
    }
}
