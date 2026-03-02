import XCTest
@testable import FountainStudioEditorCore

final class VirtualizationIndexTests: XCTestCase {
    func testVisibleLineMappingSkipsVirtualizedLines() {
        let text = """
        [[CUT UNIT 1: SETUP]]
        A
        [[CUT UNIT 2: TURN]]
        B
        """
        let index = EditorVirtualization.buildIndex(in: text, policy: BracketMarkerVirtualizationPolicy())
        XCTAssertNil(index.visibleLineNumber(forSourceLine: 1))
        XCTAssertEqual(index.visibleLineNumber(forSourceLine: 2), 1)
        XCTAssertNil(index.visibleLineNumber(forSourceLine: 3))
        XCTAssertEqual(index.visibleLineNumber(forSourceLine: 4), 2)
    }
}
