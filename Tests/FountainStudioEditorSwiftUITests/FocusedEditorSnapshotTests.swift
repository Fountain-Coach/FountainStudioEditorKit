import XCTest
import SwiftUI
import AppKit
@testable import FountainStudioEditorSwiftUI
@testable import FountainStudioEditorAppKit
@testable import FountainStudioEditorCore

@MainActor
final class FocusedEditorSnapshotTests: XCTestCase {
    func testFocusedEditorSnapshotsAreDeterministicLightDark() throws {
        let env = ProcessInfo.processInfo.environment
        let shouldRun = env["UI_SNAPSHOT"] == "1" || env["UPDATE_GOLDEN"] == "1"
        if !shouldRun {
            throw XCTSkip("FCIS-VRT UI snapshots are opt-in. Set UI_SNAPSHOT=1 to capture (or UPDATE_GOLDEN=1 to refresh baselines).")
        }

        _ = NSApplication.shared
        try snapshotRepeatPassLightDark(name: "focused-editor")
    }

    private func snapshotRepeatPassLightDark(name: String) throws {
        try snapshotRepeatPass(name: name, appearance: .aqua)
        try snapshotRepeatPass(name: "\(name)-dark", appearance: .darkAqua)
    }

    private func snapshotRepeatPass(name: String, appearance: NSAppearance.Name) throws {
        let size = CGSize(width: 1120, height: 760)
        let fixture = focusedFixtureText

        let pass1 = try capture(appearance: appearance, size: size, text: fixture)
        let pass2 = try capture(appearance: appearance, size: size, text: fixture)
        let pass3 = try capture(appearance: appearance, size: size, text: fixture)

        XCTAssertEqual(pass1, pass2, "Repeat-pass drift on pass2 for \(name)")
        XCTAssertEqual(pass2, pass3, "Repeat-pass drift on pass3 for \(name)")

        let paths = snapshotPaths(name: name)
        try FileManager.default.createDirectory(at: paths.outputDir, withIntermediateDirectories: true)
        try pass3.write(to: paths.outputFile)

        let shouldUpdate = ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1"
        if shouldUpdate {
            try FileManager.default.createDirectory(
                at: paths.baselineFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try pass3.write(to: paths.baselineFile)
        }

        if FileManager.default.fileExists(atPath: paths.baselineFile.path) {
            let golden = try Data(contentsOf: paths.baselineFile)
            XCTAssertEqual(golden, pass3, "Snapshot mismatch for \(name). output=\(paths.outputFile.path) baseline=\(paths.baselineFile.path)")
        } else {
            throw XCTSkip("No baseline yet. Captured snapshot at \(paths.outputFile.path). Promote with UPDATE_GOLDEN=1.")
        }
    }

    private func capture(appearance: NSAppearance.Name, size: CGSize, text: String) throws -> Data {
        var textState = text
        let config = EditorConfiguration(
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            theme: EditorTheme(backgroundColor: .white, plainTextColor: .black),
            isEditable: true,
            featureFlags: EditorFeatureFlags(
                lineNumberMode: .visibleOnly,
                markerPresentationMode: .gutterOverlay,
                dragAnchorsEnabled: true,
                writingToolsCompatMode: true,
                anchorPayloadPrefix: "storify-anchor:"
            )
        )
        let view = AnyView(
            FountainStudioEditor(
                text: Binding(get: { textState }, set: { textState = $0 }),
                configuration: config,
                markerProvider: BasicMarkerProvider(),
                virtualizationPolicy: BracketMarkerVirtualizationPolicy(),
                dragPayloadCodec: StorifyAnchorPayloadCodec()
            )
            .frame(width: size.width, height: size.height)
        )

        return try AppKitSnapshot.capture(size: size, appearance: appearance, view: view)
    }

    private var focusedFixtureText: String {
        """
        [[CUT UNIT 1: SETUP]]
        [[CUT UNIT 2: FRAME THE STAGE AND WITNESS]]
        CHARACTERS OF THE PLAY

        MEDEA, daughter of Aietes, King of Colchis.
        JASON, chief of the Argonauts; nephew of Pelias, King of Iolcos.

        [[CUT UNIT 3: JOURNAL FRAGMENT]]
        I write this down so the plan survives tonight.

        [[CUT UNIT 4: ORIGIN WOUND TO PRESENT RUPTURE]]
        Would God no Argo e'er had winged the seas.
        """
    }

    private func snapshotPaths(name: String) -> (outputDir: URL, outputFile: URL, baselineFile: URL) {
        let env = ProcessInfo.processInfo.environment
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let packageRoot = testsDir.deletingLastPathComponent().deletingLastPathComponent()
        let outputDir = URL(fileURLWithPath: env["SNAPSHOT_OUT"] ?? "Artifacts", relativeTo: packageRoot)
        let outputFile = outputDir.appendingPathComponent("ui-snapshot-\(name).png")
        let baselineFile = packageRoot.appendingPathComponent("Tests/Baselines/ui-snapshot-\(name).png")
        return (outputDir, outputFile, baselineFile)
    }
}

@MainActor
private enum AppKitSnapshot {
    static func capture(size: CGSize, appearance: NSAppearance.Name, view: AnyView) throws -> Data {
        let previousAppearance = NSApp.appearance
        let snapshotAppearance = NSAppearance(named: appearance)
            ?? NSAppearance(named: .aqua)
            ?? NSAppearance(named: .aqua)!
        NSApp.appearance = snapshotAppearance
        defer {
            NSApp.appearance = previousAppearance
        }

        let targetRect = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: targetRect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = snapshotAppearance

        let hostingView = NSHostingView(rootView: view)
        hostingView.appearance = snapshotAppearance
        hostingView.frame = targetRect
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        window.contentView = hostingView
        window.setContentSize(size)

        window.orderFront(nil)
        window.makeFirstResponder(nil)
        defer {
            window.orderOut(nil)
        }

        for _ in 0..<6 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
            window.makeFirstResponder(nil)
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "AppKitSnapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
        }
        rep.size = size
        hostingView.cacheDisplay(in: targetRect, to: rep)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "AppKitSnapshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        return data
    }
}
