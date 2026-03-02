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
}
