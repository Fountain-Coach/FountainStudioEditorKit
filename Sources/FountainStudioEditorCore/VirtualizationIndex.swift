import Foundation

public enum EditorVirtualization {
    public struct Index: Sendable, Equatable {
        public let lineCount: Int
        public let virtualizedSourceLines: Set<Int>
        private let prefixVirtualized: [Int]

        public init(lineCount: Int, virtualizedSourceLines: Set<Int>) {
            self.lineCount = max(1, lineCount)
            self.virtualizedSourceLines = virtualizedSourceLines
            var prefix: [Int] = Array(repeating: 0, count: self.lineCount + 1)
            var running = 0
            if self.lineCount > 0 {
                for line in 1...self.lineCount {
                    if virtualizedSourceLines.contains(line) {
                        running += 1
                    }
                    prefix[line] = running
                }
            }
            self.prefixVirtualized = prefix
        }

        public func visibleLineNumber(forSourceLine sourceLine: Int) -> Int? {
            guard sourceLine >= 1, sourceLine <= lineCount else { return nil }
            guard !virtualizedSourceLines.contains(sourceLine) else { return nil }
            return sourceLine - prefixVirtualized[sourceLine]
        }
    }

    public static func lineCount(in text: String) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return max(1, lines.count)
    }

    public static func virtualizedLines(in text: String, policy: any EditorVirtualizationPolicy) -> [Int] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return [] }
        return lines.enumerated().compactMap { idx, raw in
            let lineNumber = idx + 1
            return policy.shouldVirtualize(line: raw, lineNumber: lineNumber) ? lineNumber : nil
        }
    }

    public static func buildIndex(in text: String, policy: any EditorVirtualizationPolicy) -> Index {
        let count = lineCount(in: text)
        let virtualized = Set(virtualizedLines(in: text, policy: policy))
        return Index(lineCount: count, virtualizedSourceLines: virtualized)
    }

    public static func visibleLineNumberMap(
        in text: String,
        policy: any EditorVirtualizationPolicy
    ) -> [Int: Int] {
        let index = buildIndex(in: text, policy: policy)
        var mapping: [Int: Int] = [:]
        mapping.reserveCapacity(max(1, index.lineCount - index.virtualizedSourceLines.count))
        for sourceLine in 1...index.lineCount {
            if let visible = index.visibleLineNumber(forSourceLine: sourceLine) {
                mapping[sourceLine] = visible
            }
        }
        return mapping
    }

    public static func virtualizedCharacterRanges(
        in text: String,
        policy: any EditorVirtualizationPolicy
    ) -> [NSRange] {
        let index = buildIndex(in: text, policy: policy)
        guard !index.virtualizedSourceLines.isEmpty else { return [] }
        let ns = text as NSString
        let lineStarts = lineStartOffsets(in: text)
        var ranges: [NSRange] = []
        var openStart: Int? = nil

        func lineStartOffset(for line: Int) -> Int? {
            guard line >= 1, line <= lineStarts.count else { return nil }
            return lineStarts[line - 1]
        }

        func lineEndOffset(for line: Int) -> Int {
            if line + 1 <= lineStarts.count {
                return lineStarts[line]
            }
            return ns.length
        }

        func closeRange(at endLine: Int) {
            guard let startLine = openStart else { return }
            guard let start = lineStartOffset(for: startLine) else {
                openStart = nil
                return
            }
            let end = lineEndOffset(for: endLine)
            let safeStart = min(max(0, start), ns.length)
            let safeEnd = min(max(safeStart, end), ns.length)
            if safeEnd > safeStart {
                ranges.append(NSRange(location: safeStart, length: safeEnd - safeStart))
            }
            openStart = nil
        }

        for line in 1...index.lineCount {
            if index.virtualizedSourceLines.contains(line) {
                if openStart == nil {
                    openStart = line
                }
            } else if openStart != nil {
                closeRange(at: line - 1)
            }
        }
        if openStart != nil {
            closeRange(at: index.lineCount)
        }
        return ranges
    }

    private static func lineStartOffsets(in text: String) -> [Int] {
        let ns = text as NSString
        let length = ns.length
        let lineCount = lineCount(in: text)
        var starts: [Int] = [0]
        var index = 0
        while index < length {
            let scalar = ns.character(at: index)
            if scalar == 13 { // CR
                if index + 1 < length, ns.character(at: index + 1) == 10 { // CRLF
                    starts.append(index + 2)
                    index += 1
                } else {
                    starts.append(index + 1)
                }
            } else if scalar == 10 { // LF
                starts.append(index + 1)
            }
            index += 1
        }
        if starts.count < lineCount {
            starts.append(contentsOf: Array(repeating: length, count: lineCount - starts.count))
        } else if starts.count > lineCount {
            starts = Array(starts.prefix(lineCount))
        }
        return starts
    }
}
