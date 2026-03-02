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

    func testCutUnitHeadingWithoutBracketsIsVirtualized() {
        let text = """
        .CUT UNIT 7: INCITING INCIDENT
        BODY
        """
        let lines = EditorVirtualization.virtualizedLines(in: text, policy: BracketMarkerVirtualizationPolicy())
        XCTAssertEqual(lines, [1])
    }

    func testVisibleLineNumberMapIsContiguous() {
        let text = """
        [[CUT UNIT 1: SETUP]]
        A
        [[WINDOW:window-0 range=1-32]]
        B
        .CUT UNIT 2: TURN
        C
        """
        let mapping = EditorVirtualization.visibleLineNumberMap(
            in: text,
            policy: BracketMarkerVirtualizationPolicy()
        )
        XCTAssertEqual(mapping[2], 1)
        XCTAssertEqual(mapping[4], 2)
        XCTAssertEqual(mapping[6], 3)
        XCTAssertNil(mapping[1])
        XCTAssertNil(mapping[3])
        XCTAssertNil(mapping[5])
    }

    func testVirtualizedCharacterRangesCoverMarkerLines() {
        let text = """
        [[CUT UNIT 1: SETUP]]
        A
        [[WINDOW:window-0 range=1-32]]
        .CUT UNIT 2: TURN
        B
        """
        let ranges = EditorVirtualization.virtualizedCharacterRanges(
            in: text,
            policy: BracketMarkerVirtualizationPolicy()
        )
        XCTAssertFalse(ranges.isEmpty)
        let ns = text as NSString
        let snippets = ranges.map { ns.substring(with: $0) }
        XCTAssertTrue(snippets.contains(where: { $0.contains("[[CUT UNIT 1: SETUP]]") }))
        XCTAssertTrue(snippets.contains(where: { $0.contains("[[WINDOW:window-0 range=1-32]]") }))
        XCTAssertTrue(snippets.contains(where: { $0.contains(".CUT UNIT 2: TURN") }))
        XCTAssertFalse(snippets.contains(where: { $0.contains("\nA\n") }))
        XCTAssertFalse(snippets.contains(where: { $0.contains("\nB") }))
    }

    func testMarkerProviderParsesWindowAndCutUnitMarkers() {
        let text = """
        [[WINDOW:window-2 range=65-96]]
        CUT UNIT 3: Frame the stage
        BODY
        """
        let markers = BasicMarkerProvider().markers(for: text)
        XCTAssertEqual(markers.count, 2)
        XCTAssertEqual(markers[0].kind, .window)
        XCTAssertEqual(markers[0].metadata["windowId"], "window-2")
        XCTAssertEqual(markers[1].kind, .cutUnit)
        XCTAssertEqual(markers[1].metadata["unitId"], "3")
    }

    func testStorifyAnchorPayloadCodecRoundTrips() throws {
        let marker = EditorMarker(
            id: "m1",
            kind: .cutUnit,
            lineNumber: 44,
            rawText: "[[CUT UNIT 12: NESTED TEST]]",
            metadata: ["windowId": "window-2", "unitId": "12", "scopeDepth": "1"]
        )
        let encoded = try StorifyAnchorPayloadCodec().encode(marker: marker, range: 44...82)
        XCTAssertTrue(encoded.hasPrefix("storify-anchor:"))
        let decoded = try StorifyAnchorPayloadCodec().decode(encoded)
        XCTAssertEqual(decoded.kind, .cutUnit)
        XCTAssertEqual(decoded.rawText, marker.rawText)
        XCTAssertEqual(decoded.lineNumber, 44)
        XCTAssertEqual(decoded.metadata["windowId"], "window-2")
        XCTAssertEqual(decoded.metadata["unitId"], "12")
    }
}
