import Foundation

public struct BracketMarkerVirtualizationPolicy: EditorVirtualizationPolicy {
    public init() {}

    public func shouldVirtualize(line: String, lineNumber: Int) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
            return true
        }
        return EditorMarkerParser.parseCutUnitHeading(from: trimmed) != nil
    }
}

public struct BasicMarkerProvider: EditorMarkerProvider {
    public init() {}

    public func markers(for text: String) -> [EditorMarker] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.enumerated().compactMap { idx, raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            let lineNumber = idx + 1
            if let bracket = EditorMarkerParser.parseBracketMarker(from: line, lineNumber: lineNumber) {
                return bracket
            }
            if let cutUnit = EditorMarkerParser.parseCutUnitHeading(from: line) {
                return EditorMarker(
                    id: "marker-\(lineNumber)",
                    kind: .cutUnit,
                    lineNumber: lineNumber,
                    rawText: cutUnit.rawText,
                    metadata: ["unitId": String(cutUnit.unitId)]
                )
            }
            return nil
        }
    }
}

public enum EditorMarkerParser {
    private static let cutUnitRegex = try? NSRegularExpression(
        pattern: #"^\s*\.?\s*CUT\s+UNIT\s+(\d+)\s*:\s*(.*?)\s*$"#,
        options: [.caseInsensitive]
    )

    public struct CutUnitMatch: Sendable, Equatable {
        public let unitId: Int
        public let title: String
        public let rawText: String
    }

    public static func parseBracketMarker(from line: String, lineNumber: Int) -> EditorMarker? {
        guard line.hasPrefix("[["), line.hasSuffix("]]") else { return nil }
        let upper = line.uppercased()
        if upper.contains("[[WINDOW:") {
            let windowId = extractWindowId(from: line)
            return EditorMarker(
                id: "marker-\(lineNumber)",
                kind: .window,
                lineNumber: lineNumber,
                rawText: line,
                metadata: windowId.map { ["windowId": $0] } ?? [:]
            )
        }
        if upper.contains("[[ATOM:") {
            return EditorMarker(
                id: "marker-\(lineNumber)",
                kind: .atom,
                lineNumber: lineNumber,
                rawText: line
            )
        }
        if let cutUnit = parseBracketCutUnit(from: line) {
            return EditorMarker(
                id: "marker-\(lineNumber)",
                kind: .cutUnit,
                lineNumber: lineNumber,
                rawText: cutUnit.rawText,
                metadata: ["unitId": String(cutUnit.unitId)]
            )
        }
        if upper.contains("[[BEAT") {
            return EditorMarker(
                id: "marker-\(lineNumber)",
                kind: .beat,
                lineNumber: lineNumber,
                rawText: line
            )
        }
        return EditorMarker(
            id: "marker-\(lineNumber)",
            kind: .generic,
            lineNumber: lineNumber,
            rawText: line
        )
    }

    public static func parseCutUnitHeading(from line: String) -> CutUnitMatch? {
        let range = NSRange(location: 0, length: (line as NSString).length)
        if let regex = cutUnitRegex,
           let match = regex.firstMatch(in: line, options: [], range: range),
           match.numberOfRanges >= 3 {
            let ns = line as NSString
            let idRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            let unitId = Int(ns.substring(with: idRange)) ?? 0
            guard unitId > 0 else { return nil }
            let title = titleRange.location != NSNotFound ? ns.substring(with: titleRange) : ""
            let canonical = "[[CUT UNIT \(unitId): \(title.uppercased())]]"
            return CutUnitMatch(unitId: unitId, title: title, rawText: canonical)
        }
        return nil
    }

    private static func parseBracketCutUnit(from line: String) -> CutUnitMatch? {
        let inner = line
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseCutUnitHeading(from: inner)
    }

    private static func extractWindowId(from line: String) -> String? {
        guard let match = line.range(
            of: #"^\[\[\s*WINDOW:([A-Za-z0-9_-]+)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        let matched = String(line[match])
        guard let tokenRange = matched.range(of: #"WINDOW:([A-Za-z0-9_-]+)"#, options: .regularExpression) else {
            return nil
        }
        let token = String(matched[tokenRange]).replacingOccurrences(of: "WINDOW:", with: "")
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct StorifyAnchorPayloadCodec: EditorDragPayloadCodec {
    public init() {}

    public func encode(marker: EditorMarker, range: ClosedRange<Int>?) throws -> String {
        let payload = EditorAnchorDragPayload(
            kind: marker.kind.rawValue,
            marker: marker.rawText,
            lineNumber: marker.lineNumber,
            windowId: marker.metadata["windowId"],
            unitId: Int(marker.metadata["unitId"] ?? ""),
            startLine: range?.lowerBound,
            endLine: range?.upperBound,
            scopeDepth: Int(marker.metadata["scopeDepth"] ?? "")
        )
        let data = try JSONEncoder().encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }
        return "storify-anchor:" + json
    }

    public func decode(_ payload: String) throws -> EditorMarker {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String
        if trimmed.hasPrefix("storify-anchor:") {
            json = String(trimmed.dropFirst("storify-anchor:".count))
        } else {
            json = trimmed
        }
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(EditorAnchorDragPayload.self, from: data)
        var metadata: [String: String] = [:]
        if let windowId = decoded.windowId {
            metadata["windowId"] = windowId
        }
        if let unitId = decoded.unitId {
            metadata["unitId"] = String(unitId)
        }
        if let scopeDepth = decoded.scopeDepth {
            metadata["scopeDepth"] = String(scopeDepth)
        }
        return EditorMarker(
            id: "decoded-\(decoded.lineNumber)",
            kind: EditorMarkerKind(rawValue: decoded.kind) ?? .generic,
            lineNumber: decoded.lineNumber,
            rawText: decoded.marker,
            metadata: metadata
        )
    }
}
