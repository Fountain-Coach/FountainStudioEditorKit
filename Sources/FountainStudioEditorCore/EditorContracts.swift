import Foundation

public enum EditorMarkerKind: String, Sendable, Equatable {
    case cutUnit
    case window
    case atom
    case beat
    case generic
}

public struct EditorMarker: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: EditorMarkerKind
    public let lineNumber: Int
    public let rawText: String
    public let metadata: [String: String]

    public init(
        id: String,
        kind: EditorMarkerKind,
        lineNumber: Int,
        rawText: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.lineNumber = lineNumber
        self.rawText = rawText
        self.metadata = metadata
    }
}

public struct EditorAnchor: Sendable, Equatable {
    public let id: String
    public let kind: String

    public init(id: String, kind: String) {
        self.id = id
        self.kind = kind
    }
}

public protocol EditorMarkerProvider: Sendable {
    func markers(for text: String) -> [EditorMarker]
}

public protocol EditorVirtualizationPolicy: Sendable {
    func shouldVirtualize(line: String, lineNumber: Int) -> Bool
}

public protocol EditorNavigationResolver: Sendable {
    func targetOffset(for anchor: EditorAnchor, in text: String) -> Int?
}

public struct OverlayCardContent: Sendable, Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public protocol EditorOverlayCardProvider: Sendable {
    func card(for marker: EditorMarker) -> OverlayCardContent
}

public protocol EditorDragPayloadCodec: Sendable {
    func encode(marker: EditorMarker, range: ClosedRange<Int>?) throws -> String
    func decode(_ payload: String) throws -> EditorMarker
}

public struct EditorAnchorDragPayload: Sendable, Equatable, Codable {
    public var kind: String
    public var marker: String
    public var lineNumber: Int
    public var windowId: String?
    public var unitId: Int?
    public var startLine: Int?
    public var endLine: Int?
    public var scopeDepth: Int?

    public init(
        kind: String,
        marker: String,
        lineNumber: Int,
        windowId: String? = nil,
        unitId: Int? = nil,
        startLine: Int? = nil,
        endLine: Int? = nil,
        scopeDepth: Int? = nil
    ) {
        self.kind = kind
        self.marker = marker
        self.lineNumber = lineNumber
        self.windowId = windowId
        self.unitId = unitId
        self.startLine = startLine
        self.endLine = endLine
        self.scopeDepth = scopeDepth
    }
}

public enum EditorLineNumberMode: String, Sendable {
    case sourceAbsolute
    case visibleOnly
}

public enum EditorMarkerPresentationMode: String, Sendable {
    case inlineVisible
    case gutterOverlay
}

public struct EditorFeatureFlags: Sendable, Equatable {
    public var lineNumberMode: EditorLineNumberMode
    public var markerPresentationMode: EditorMarkerPresentationMode
    public var dragAnchorsEnabled: Bool
    public var writingToolsCompatMode: Bool
    public var anchorPayloadPrefix: String

    public init(
        lineNumberMode: EditorLineNumberMode = .sourceAbsolute,
        markerPresentationMode: EditorMarkerPresentationMode = .inlineVisible,
        dragAnchorsEnabled: Bool = false,
        writingToolsCompatMode: Bool = true,
        anchorPayloadPrefix: String = "storify-anchor:"
    ) {
        self.lineNumberMode = lineNumberMode
        self.markerPresentationMode = markerPresentationMode
        self.dragAnchorsEnabled = dragAnchorsEnabled
        self.writingToolsCompatMode = writingToolsCompatMode
        self.anchorPayloadPrefix = anchorPayloadPrefix
    }
}

public enum EditorRuntimeDiagnosticKind: String, Sendable, Equatable {
    case virtualizationMaskSuppressed
    case virtualizationMaskRestored
}

public struct EditorRuntimeDiagnostic: Sendable, Equatable {
    public let kind: EditorRuntimeDiagnosticKind
    public let reason: String
    public let lineCount: Int
    public let virtualizedLineCount: Int

    public init(
        kind: EditorRuntimeDiagnosticKind,
        reason: String,
        lineCount: Int,
        virtualizedLineCount: Int
    ) {
        self.kind = kind
        self.reason = reason
        self.lineCount = lineCount
        self.virtualizedLineCount = virtualizedLineCount
    }
}
