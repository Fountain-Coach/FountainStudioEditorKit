import Foundation

public enum EditorFixtureFactory {
    public static func markerDenseText(unitCount: Int = 8) -> String {
        var lines: [String] = []
        for i in 1...max(1, unitCount) {
            lines.append("[[CUT UNIT \(i): UNIT \(i)]]")
            lines.append("INT. ROOM \(i) - DAY")
            lines.append("")
            lines.append("NARRATOR")
            lines.append("Unit \(i) text.")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
