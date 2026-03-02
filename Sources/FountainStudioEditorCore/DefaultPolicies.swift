import Foundation

public struct BracketMarkerVirtualizationPolicy: EditorVirtualizationPolicy {
    public init() {}

    public func shouldVirtualize(line: String, lineNumber: Int) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]" )
    }
}

public struct BasicMarkerProvider: EditorMarkerProvider {
    public init() {}

    public func markers(for text: String) -> [EditorMarker] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.enumerated().compactMap { idx, raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("[["), line.hasSuffix("]]" ) else { return nil }
            return EditorMarker(
                id: "marker-\(idx + 1)",
                kind: .generic,
                lineNumber: idx + 1,
                rawText: line
            )
        }
    }
}
