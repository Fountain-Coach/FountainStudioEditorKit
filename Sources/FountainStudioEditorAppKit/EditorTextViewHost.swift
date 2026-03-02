import AppKit
import Foundation
import FountainStudioEditorCore

@MainActor
public final class EditorTextViewHost: NSObject, NSTextViewDelegate {
    private let textBindingGet: () -> String
    private let textBindingSet: (String) -> Void
    public var configuration: EditorConfiguration
    public var markerProvider: any EditorMarkerProvider
    public var virtualizationPolicy: any EditorVirtualizationPolicy
    public var dragPayloadCodec: any EditorDragPayloadCodec
    public var onTextViewReady: ((NSTextView) -> Void)?
    public var onDiagnostic: ((EditorRuntimeDiagnostic) -> Void)?

    private var isApplyingExternalUpdate = false
    private var isVirtualizationMaskSuppressed = false
    private(set) weak var textView: NSTextView?

    public init(
        textBindingGet: @escaping () -> String,
        textBindingSet: @escaping (String) -> Void,
        configuration: EditorConfiguration,
        markerProvider: any EditorMarkerProvider = BasicMarkerProvider(),
        virtualizationPolicy: any EditorVirtualizationPolicy = BracketMarkerVirtualizationPolicy(),
        dragPayloadCodec: any EditorDragPayloadCodec = StorifyAnchorPayloadCodec(),
        onTextViewReady: ((NSTextView) -> Void)? = nil,
        onDiagnostic: ((EditorRuntimeDiagnostic) -> Void)? = nil
    ) {
        self.textBindingGet = textBindingGet
        self.textBindingSet = textBindingSet
        self.configuration = configuration
        self.markerProvider = markerProvider
        self.virtualizationPolicy = virtualizationPolicy
        self.dragPayloadCodec = dragPayloadCodec
        self.onTextViewReady = onTextViewReady
        self.onDiagnostic = onDiagnostic
    }

    public func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = configuration.theme.backgroundColor

        let textView = NSTextView()
        textView.isEditable = configuration.isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = configuration.font
        textView.textColor = configuration.theme.plainTextColor
        textView.backgroundColor = configuration.theme.backgroundColor
        textView.insertionPointColor = configuration.theme.plainTextColor
        textView.string = textBindingGet()
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        // Writing Tools API is intentionally not configured here to keep compatibility
        // across CI SDK/toolchain combinations.

        scrollView.documentView = textView
        self.textView = textView
        applyVirtualizationMaskIfNeeded(to: textView)
        clampSelectionIfNeeded(in: textView)
        configureRulerIfNeeded(scrollView: scrollView, textView: textView, forceRecompute: true)
        onTextViewReady?(textView)
        return scrollView
    }

    public func update(scrollView: NSScrollView) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        scrollView.backgroundColor = configuration.theme.backgroundColor
        textView.font = configuration.font
        textView.isEditable = configuration.isEditable
        textView.textColor = configuration.theme.plainTextColor
        textView.insertionPointColor = configuration.theme.plainTextColor
        textView.backgroundColor = configuration.theme.backgroundColor

        let expected = textBindingGet()
        var forceRecompute = false
        if !textView.hasMarkedText(), textView.string != expected {
            isApplyingExternalUpdate = true
            let selected = textView.selectedRanges
            textView.string = expected
            textView.selectedRanges = selected
            isApplyingExternalUpdate = false
            forceRecompute = true
        }

        applyVirtualizationMaskIfNeeded(to: textView)
        clampSelectionIfNeeded(in: textView)
        configureRulerIfNeeded(scrollView: scrollView, textView: textView, forceRecompute: forceRecompute)
    }

    public func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalUpdate else { return }
        guard let textView else { return }
        textBindingSet(textView.string)
        applyVirtualizationMaskIfNeeded(to: textView)
        clampSelectionIfNeeded(in: textView)
        if let scrollView = textView.enclosingScrollView {
            configureRulerIfNeeded(scrollView: scrollView, textView: textView, forceRecompute: false)
        }
    }

    private func shouldUseGutterOverlay() -> Bool {
        configuration.featureFlags.markerPresentationMode == .gutterOverlay
    }

    private func shouldShowLineRuler() -> Bool {
        configuration.featureFlags.lineNumberMode == .visibleOnly || shouldUseGutterOverlay()
    }

    private func configureRulerIfNeeded(scrollView: NSScrollView, textView: NSTextView, forceRecompute: Bool) {
        guard shouldShowLineRuler() else {
            if let existing = scrollView.verticalRulerView as? EditorLineNumberRulerView {
                existing.detach()
            }
            scrollView.rulersVisible = false
            scrollView.hasVerticalRuler = false
            scrollView.verticalRulerView = nil
            return
        }

        let ruler: EditorLineNumberRulerView
        if let existing = scrollView.verticalRulerView as? EditorLineNumberRulerView {
            ruler = existing
            existing.attach(textView: textView, scrollView: scrollView)
        } else {
            ruler = EditorLineNumberRulerView(
                textView: textView,
                scrollView: scrollView,
                markerProvider: markerProvider,
                virtualizationPolicy: virtualizationPolicy,
                dragPayloadCodec: dragPayloadCodec
            )
            scrollView.verticalRulerView = ruler
        }
        ruler.featureFlags = effectiveFeatureFlags()
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        ruler.refresh(forceRecompute: forceRecompute)
    }

    private func effectiveFeatureFlags() -> EditorFeatureFlags {
        guard isVirtualizationMaskSuppressed,
              configuration.featureFlags.markerPresentationMode == .gutterOverlay else {
            return configuration.featureFlags
        }
        var flags = configuration.featureFlags
        flags.lineNumberMode = .sourceAbsolute
        return flags
    }

    private func applyVirtualizationMaskIfNeeded(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.removeAttribute(.paragraphStyle, range: fullRange)
        storage.removeAttribute(.font, range: fullRange)
        storage.addAttributes(
            [
                .font: configuration.font,
                .foregroundColor: configuration.theme.plainTextColor,
                .paragraphStyle: baseParagraphStyle()
            ],
            range: fullRange
        )

        if shouldUseGutterOverlay() {
            let index = EditorVirtualization.buildIndex(in: storage.string, policy: virtualizationPolicy)
            let nextSuppressed = index.lineCount > 0 && index.virtualizedSourceLines.count >= index.lineCount
            emitMaskSuppressionDiagnosticIfNeeded(
                wasSuppressed: isVirtualizationMaskSuppressed,
                isSuppressed: nextSuppressed,
                lineCount: index.lineCount,
                virtualizedLineCount: index.virtualizedSourceLines.count
            )
            isVirtualizationMaskSuppressed = nextSuppressed

            if !nextSuppressed {
                let hiddenAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.clear,
                    .font: NSFont.monospacedSystemFont(ofSize: 0.1, weight: .regular),
                    .paragraphStyle: collapsedParagraphStyle()
                ]
                let ranges = EditorVirtualization.virtualizedCharacterRanges(
                    in: storage.string,
                    policy: virtualizationPolicy
                )
                for range in ranges where range.length > 0 {
                    storage.addAttributes(hiddenAttributes, range: range)
                }
            }
        } else if isVirtualizationMaskSuppressed {
            emitMaskSuppressionDiagnosticIfNeeded(
                wasSuppressed: true,
                isSuppressed: false,
                lineCount: EditorVirtualization.lineCount(in: storage.string),
                virtualizedLineCount: 0
            )
            isVirtualizationMaskSuppressed = false
        }
        storage.endEditing()
    }

    private func clampSelectionIfNeeded(in textView: NSTextView) {
        guard shouldUseGutterOverlay() else { return }
        guard !isVirtualizationMaskSuppressed else { return }
        let blocked = EditorVirtualization.virtualizedCharacterRanges(
            in: textView.string,
            policy: virtualizationPolicy
        )
        guard !blocked.isEmpty else { return }
        let maxLength = (textView.string as NSString).length
        var updated: [NSValue] = []
        updated.reserveCapacity(textView.selectedRanges.count)
        var didChange = false

        for value in textView.selectedRanges {
            let original = value.rangeValue
            let clampedLocation = min(max(0, original.location), maxLength)
            let collapsed = NSRange(location: clampedLocation, length: 0)
            let adjustedLocation = nearestVisibleLocation(
                from: clampedLocation,
                blockedRanges: blocked,
                maxLength: maxLength
            )
            let adjusted = NSRange(location: adjustedLocation, length: 0)
            if adjusted != collapsed || original.length != 0 {
                didChange = true
            }
            updated.append(NSValue(range: adjusted))
        }

        if updated.isEmpty {
            updated = [NSValue(range: NSRange(location: nearestVisibleLocation(from: maxLength, blockedRanges: blocked, maxLength: maxLength), length: 0))]
            didChange = true
        }

        guard didChange else { return }
        textView.selectedRanges = updated
    }

    private func nearestVisibleLocation(from location: Int, blockedRanges: [NSRange], maxLength: Int) -> Int {
        func isBlocked(_ offset: Int) -> Bool {
            blockedRanges.contains { NSLocationInRange(offset, $0) }
        }
        if !isBlocked(location) {
            return location
        }
        var forward = location
        while forward <= maxLength {
            if !isBlocked(forward) {
                return forward
            }
            forward += 1
        }
        var backward = location
        while backward >= 0 {
            if !isBlocked(backward) {
                return backward
            }
            backward -= 1
        }
        return min(max(0, location), maxLength)
    }

    private func emitMaskSuppressionDiagnosticIfNeeded(
        wasSuppressed: Bool,
        isSuppressed: Bool,
        lineCount: Int,
        virtualizedLineCount: Int
    ) {
        guard wasSuppressed != isSuppressed else { return }
        let kind: EditorRuntimeDiagnosticKind = isSuppressed
            ? .virtualizationMaskSuppressed
            : .virtualizationMaskRestored
        onDiagnostic?(
            EditorRuntimeDiagnostic(
                kind: kind,
                reason: "all_lines_virtualized",
                lineCount: lineCount,
                virtualizedLineCount: virtualizedLineCount
            )
        )
    }

    private func baseParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3.0
        return style
    }

    private func collapsedParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        style.minimumLineHeight = 0.1
        style.maximumLineHeight = 0.1
        style.lineHeightMultiple = 0.01
        return style
    }
}

private final class EditorLineNumberRulerView: NSRulerView, NSDraggingSource {
    var featureFlags: EditorFeatureFlags = EditorFeatureFlags()

    private weak var observedTextView: NSTextView?
    private weak var observedScrollView: NSScrollView?
    private let markerProvider: any EditorMarkerProvider
    private let virtualizationPolicy: any EditorVirtualizationPolicy
    private let dragPayloadCodec: any EditorDragPayloadCodec

    private var lineStartOffsets: [Int] = [0]
    private var lineStartOffsetSet: Set<Int> = [0]
    private var lineCount: Int = 1
    private var virtualizationIndex = EditorVirtualization.Index(lineCount: 1, virtualizedSourceLines: [])
    private var markersByLine: [Int: [EditorMarker]] = [:]
    private var primaryMarkerByLine: [Int: EditorMarker] = [:]
    private var orderedMarkers: [EditorMarker] = []
    private var iconRectsByLine: [Int: NSRect] = [:]
    private var markerLineRangesByLine: [Int: ClosedRange<Int>] = [:]
    private var markerCharacterRangesByLine: [Int: NSRange] = [:]
    private var cutUnitEnvelopesByUnitId: [Int: ClosedRange<Int>] = [:]
    private var cutUnitParentByUnitId: [Int: Int] = [:]

    private var labelFont: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let horizontalPadding: CGFloat = 8
    private let labelColor = NSColor(calibratedWhite: 0.35, alpha: 0.95)
    private let iconColumnWidth: CGFloat = 18
    private let iconColumnPadding: CGFloat = 8
    private let iconSize: CGFloat = 12
    private var trackingAreaRef: NSTrackingArea?
    private var hoveredMarkerLine: Int?
    private var highlightedCharacterRanges: [NSRange] = []
    private weak var hoverCard: EditorAnchorHoverCardView?

    init(
        textView: NSTextView,
        scrollView: NSScrollView,
        markerProvider: any EditorMarkerProvider,
        virtualizationPolicy: any EditorVirtualizationPolicy,
        dragPayloadCodec: any EditorDragPayloadCodec
    ) {
        self.markerProvider = markerProvider
        self.virtualizationPolicy = virtualizationPolicy
        self.dragPayloadCodec = dragPayloadCodec
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        attach(textView: textView, scrollView: scrollView)
        refresh(forceRecompute: true)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func attach(textView: NSTextView, scrollView: NSScrollView) {
        guard observedTextView !== textView || observedScrollView !== scrollView else { return }
        detachObservers()
        observedTextView = textView
        observedScrollView = scrollView
        clientView = textView
        let pointSize = max(10, (textView.font?.pointSize ?? 12) * 0.9)
        labelFont = .monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
        installObservers(textView: textView, scrollView: scrollView)
    }

    func detach() {
        detachObservers()
        observedTextView = nil
        observedScrollView = nil
        clearHoverHighlight()
        clearHoverCard()
        clientView = nil
    }

    func refresh(forceRecompute: Bool) {
        guard let textView = observedTextView else { return }
        let pointSize = max(10, (textView.font?.pointSize ?? 12) * 0.9)
        if abs(labelFont.pointSize - pointSize) > 0.01 {
            labelFont = .monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
        }
        if forceRecompute {
            recomputeIndexes()
        }
        let nextThickness = computedRuleThickness()
        if abs(ruleThickness - nextThickness) > 0.5 {
            ruleThickness = nextThickness
            observedScrollView?.tile()
        }
        invalidateHashMarks()
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = observedTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        NSColor.clear.setFill()
        rect.fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]
        let numberColumnWidth = computedNumberColumnWidth()
        let numberRightEdge = numberColumnWidth - horizontalPadding
        let iconColumnStart = numberColumnWidth + (iconColumnPadding * 0.5)
        let textInsetY = textView.textContainerInset.height
        let visibleBounds = observedScrollView?.contentView.bounds ?? .zero
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleBounds, in: textContainer)
        iconRectsByLine = [:]

        var rendered = false
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { [weak self] _, usedRect, _, glyphRange, _ in
            guard let self else { return }
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let characterOffset = min(max(0, charRange.location), self.textLength)
            guard self.lineStartOffsetSet.contains(characterOffset) else { return }
            let lineNumber = self.lineNumber(forCharacterOffset: characterOffset)
            let visibleLineNumber = self.featureFlags.lineNumberMode == .visibleOnly
                ? self.virtualizationIndex.visibleLineNumber(forSourceLine: lineNumber)
                : lineNumber
            let shouldDrawNumber = self.featureFlags.markerPresentationMode != .gutterOverlay || visibleLineNumber != nil
            let drawLineNumber = visibleLineNumber ?? lineNumber
            if shouldDrawNumber {
                let label = "\(drawLineNumber)" as NSString
                let labelSize = label.size(withAttributes: attributes)
                let lineYInTextView = usedRect.minY + textInsetY + max(0, (usedRect.height - labelSize.height) * 0.5)
                let converted = self.convert(NSPoint(x: 0, y: lineYInTextView), from: textView)
                let drawRect = NSRect(
                    x: numberRightEdge - labelSize.width,
                    y: converted.y,
                    width: labelSize.width,
                    height: labelSize.height
                )
                label.draw(in: drawRect, withAttributes: attributes)
                rendered = true
            }

            if self.featureFlags.markerPresentationMode == .gutterOverlay,
               let marker = self.primaryMarkerByLine[lineNumber] {
                let iconLineYInTextView = usedRect.minY + textInsetY + max(0, (usedRect.height - self.iconSize) * 0.5)
                let convertedIconY = self.convert(NSPoint(x: 0, y: iconLineYInTextView), from: textView).y
                let iconRect = NSRect(
                    x: iconColumnStart + ((self.iconColumnWidth - self.iconSize) * 0.5),
                    y: convertedIconY,
                    width: self.iconSize,
                    height: self.iconSize
                )
                self.drawMarkerIcon(marker: marker, in: iconRect)
                self.iconRectsByLine[lineNumber] = iconRect
                rendered = true
            }
        }

        if !rendered {
            let label = "1" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let origin = convert(NSPoint(x: 0, y: textView.textContainerInset.height), from: textView)
            label.draw(
                in: NSRect(x: numberRightEdge - labelSize.width, y: origin.y, width: labelSize.width, height: labelSize.height),
                withAttributes: attributes
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        trackingAreaRef = tracking
    }

    override func mouseMoved(with event: NSEvent) {
        guard featureFlags.markerPresentationMode == .gutterOverlay else {
            clearHoverCard()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let line = markerLine(at: point), let marker = primaryMarkerByLine[line] else {
            clearHoverCard()
            return
        }
        hoveredMarkerLine = line
        applyHoverHighlight(for: marker)
        showHoverCard(marker: marker)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        clearHoverCard()
    }

    override func mouseDown(with event: NSEvent) {
        guard featureFlags.markerPresentationMode == .gutterOverlay,
              featureFlags.dragAnchorsEnabled else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let line = markerLine(at: point), let marker = primaryMarkerByLine[line] else {
            super.mouseDown(with: event)
            return
        }
        beginMarkerDrag(marker, event: event)
    }

    private var textLength: Int {
        guard let textView = observedTextView else { return 0 }
        return (textView.string as NSString).length
    }

    private func installObservers(textView: NSTextView, scrollView: NSScrollView) {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextDidChange), name: NSText.didChangeNotification, object: textView)
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleClipViewBoundsDidChange), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    private func detachObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func handleTextDidChange(_ notification: Notification) {
        refresh(forceRecompute: true)
    }

    @objc
    private func handleClipViewBoundsDidChange(_ notification: Notification) {
        invalidateHashMarks()
        needsDisplay = true
        if let line = hoveredMarkerLine, let marker = primaryMarkerByLine[line] {
            applyHoverHighlight(for: marker)
            showHoverCard(marker: marker)
        }
    }

    private func recomputeIndexes() {
        guard let textView = observedTextView else { return }
        let text = textView.string
        let ns = text as NSString
        let length = ns.length
        var starts: [Int] = [0]
        var index = 0
        while index < length {
            let scalar = ns.character(at: index)
            if scalar == 13 {
                if index + 1 < length, ns.character(at: index + 1) == 10 {
                    starts.append(index + 2)
                    index += 1
                } else {
                    starts.append(index + 1)
                }
            } else if scalar == 10 {
                starts.append(index + 1)
            }
            index += 1
        }
        lineStartOffsets = starts
        lineStartOffsetSet = Set(starts)
        lineCount = max(1, starts.count)
        virtualizationIndex = EditorVirtualization.buildIndex(in: text, policy: virtualizationPolicy)
        rebuildMarkers(from: text)
    }

    private func rebuildMarkers(from text: String) {
        orderedMarkers = markerProvider.markers(for: text).sorted { lhs, rhs in
            if lhs.lineNumber != rhs.lineNumber {
                return lhs.lineNumber < rhs.lineNumber
            }
            return markerPriority(lhs.kind) < markerPriority(rhs.kind)
        }
        markersByLine = Dictionary(grouping: orderedMarkers, by: \.lineNumber)
        primaryMarkerByLine = markersByLine.compactMapValues { markers in
            markers.min(by: { markerPriority($0.kind) < markerPriority($1.kind) })
        }

        markerLineRangesByLine = [:]
        markerCharacterRangesByLine = [:]
        for (offset, marker) in orderedMarkers.enumerated() {
            let startLine = max(1, marker.lineNumber)
            let nextLine = offset + 1 < orderedMarkers.count ? orderedMarkers[offset + 1].lineNumber : (lineCount + 1)
            let endLine = max(startLine, min(lineCount, max(startLine, nextLine - 1)))
            markerLineRangesByLine[marker.lineNumber] = startLine...endLine
            if let range = characterRange(forLineRange: startLine...endLine) {
                markerCharacterRangesByLine[marker.lineNumber] = range
            }
        }

        rebuildCutUnitScopes()
    }

    private func rebuildCutUnitScopes() {
        cutUnitEnvelopesByUnitId = [:]
        cutUnitParentByUnitId = [:]
        let cutMarkers: [(unitId: Int, line: Int)] = orderedMarkers.compactMap { marker in
            guard marker.kind == .cutUnit,
                  let raw = marker.metadata["unitId"],
                  let unitId = Int(raw),
                  unitId > 0 else {
                return nil
            }
            return (unitId, marker.lineNumber)
        }
        guard !cutMarkers.isEmpty else { return }

        var segmentsByUnitId: [Int: [ClosedRange<Int>]] = [:]
        for (index, marker) in cutMarkers.enumerated() {
            let startLine = max(1, marker.line)
            let nextStart = index + 1 < cutMarkers.count ? cutMarkers[index + 1].line : lineCount + 1
            let endLine = max(startLine, min(lineCount, max(startLine, nextStart - 1)))
            segmentsByUnitId[marker.unitId, default: []].append(startLine...endLine)
        }

        for (unitId, segments) in segmentsByUnitId {
            guard let first = segments.first else { continue }
            var lower = first.lowerBound
            var upper = first.upperBound
            for segment in segments.dropFirst() {
                lower = min(lower, segment.lowerBound)
                upper = max(upper, segment.upperBound)
            }
            cutUnitEnvelopesByUnitId[unitId] = lower...upper
        }

        let unitIds = cutUnitEnvelopesByUnitId.keys.sorted()
        for unitId in unitIds {
            guard let envelope = cutUnitEnvelopesByUnitId[unitId] else { continue }
            let candidates = unitIds.compactMap { candidateId -> (Int, ClosedRange<Int>)? in
                guard candidateId != unitId,
                      let candidate = cutUnitEnvelopesByUnitId[candidateId],
                      candidate.lowerBound <= envelope.lowerBound,
                      candidate.upperBound >= envelope.upperBound else {
                    return nil
                }
                if candidate.lowerBound == envelope.lowerBound && candidate.upperBound == envelope.upperBound {
                    return nil
                }
                return (candidateId, candidate)
            }
            let parent = candidates.min { lhs, rhs in
                let lhsSpan = lhs.1.upperBound - lhs.1.lowerBound
                let rhsSpan = rhs.1.upperBound - rhs.1.lowerBound
                if lhsSpan != rhsSpan {
                    return lhsSpan < rhsSpan
                }
                return lhs.0 < rhs.0
            }?.0
            cutUnitParentByUnitId[unitId] = parent
        }
    }

    private func markerPriority(_ kind: EditorMarkerKind) -> Int {
        switch kind {
        case .cutUnit: return 0
        case .beat: return 1
        case .window: return 2
        case .atom: return 3
        case .generic: return 4
        }
    }

    private func computedRuleThickness() -> CGFloat {
        var width = computedNumberColumnWidth()
        if featureFlags.markerPresentationMode == .gutterOverlay {
            width += iconColumnWidth + iconColumnPadding
        }
        return width
    }

    private func computedNumberColumnWidth() -> CGFloat {
        let countForDigits: Int = {
            if featureFlags.lineNumberMode == .visibleOnly {
                let visibleCount = lineCount - virtualizationIndex.virtualizedSourceLines.count
                return max(1, visibleCount)
            }
            return max(1, lineCount)
        }()
        let digits = String(countForDigits).count
        let sample = String(repeating: "8", count: max(2, digits)) as NSString
        let sampleWidth = sample.size(withAttributes: [.font: labelFont]).width
        return max(30, ceil(sampleWidth + (horizontalPadding * 2)))
    }

    private func lineNumber(forCharacterOffset offset: Int) -> Int {
        let clamped = min(max(0, offset), max(0, textLength))
        var low = 0
        var high = lineStartOffsets.count
        while low < high {
            let mid = (low + high) / 2
            if lineStartOffsets[mid] <= clamped {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return max(1, low)
    }

    private func markerLine(at point: NSPoint) -> Int? {
        for (line, rect) in iconRectsByLine where rect.contains(point) {
            return line
        }
        return nil
    }

    private func drawMarkerIcon(marker: EditorMarker, in rect: NSRect) {
        let fill = markerAccentColor(marker).withAlphaComponent(hoveredMarkerLine == marker.lineNumber ? 0.95 : 0.78)
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()

        let symbol = markerSymbol(marker) as NSString
        let font = NSFont.systemFont(ofSize: 8, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let size = symbol.size(withAttributes: attributes)
        let drawRect = NSRect(
            x: rect.midX - (size.width * 0.5),
            y: rect.midY - (size.height * 0.5),
            width: size.width,
            height: size.height
        )
        symbol.draw(in: drawRect, withAttributes: attributes)
    }

    private func markerAccentColor(_ marker: EditorMarker) -> NSColor {
        switch marker.kind {
        case .window:
            return .systemBlue
        case .atom:
            return .systemTeal
        case .cutUnit:
            return .systemOrange
        case .beat:
            return .systemPurple
        case .generic:
            return .systemGray
        }
    }

    private func markerSymbol(_ marker: EditorMarker) -> String {
        switch marker.kind {
        case .window:
            return "W"
        case .atom:
            return "A"
        case .cutUnit:
            return "U"
        case .beat:
            return "B"
        case .generic:
            return "M"
        }
    }

    private func markerTitle(_ marker: EditorMarker) -> String {
        switch marker.kind {
        case .window:
            return "Window marker"
        case .atom:
            return "Atom marker"
        case .cutUnit:
            return "Cut unit marker"
        case .beat:
            return "Beat marker"
        case .generic:
            return "Marker"
        }
    }

    private func ensureHoverCard() -> EditorAnchorHoverCardView? {
        guard let scrollView = observedScrollView,
              let host = scrollView.window?.contentView else { return nil }
        if let hoverCard {
            if hoverCard.superview == nil {
                host.addSubview(hoverCard)
            } else if hoverCard.superview !== host {
                hoverCard.removeFromSuperview()
                host.addSubview(hoverCard)
            }
            return hoverCard
        }
        let card = EditorAnchorHoverCardView()
        host.addSubview(card)
        hoverCard = card
        return card
    }

    private func showHoverCard(marker: EditorMarker) {
        guard featureFlags.markerPresentationMode == .gutterOverlay else {
            clearHoverCard()
            return
        }
        guard let hoverCard = ensureHoverCard(),
              let scrollView = observedScrollView,
              let iconRect = iconRectsByLine[marker.lineNumber] else {
            clearHoverCard()
            return
        }
        hoverCard.update(
            title: "\(markerTitle(marker)) - line \(marker.lineNumber)",
            body: marker.rawText,
            accentColor: markerAccentColor(marker)
        )
        guard let host = scrollView.window?.contentView else { return }
        let iconInHost = host.convert(iconRect, from: self)
        let size = hoverCard.preferredSize(maxWidth: 340)
        var origin = NSPoint(x: iconInHost.maxX + 12, y: iconInHost.midY - (size.height * 0.5))
        let minX = host.bounds.minX + 6
        let maxX = host.bounds.maxX - size.width - 6
        origin.x = min(max(origin.x, minX), maxX)
        let minY = host.bounds.minY + 6
        let maxY = host.bounds.maxY - size.height - 6
        origin.y = min(max(origin.y, minY), maxY)
        hoverCard.frame = NSRect(origin: origin, size: size)
        hoverCard.isHidden = false
        hoverCard.needsLayout = true
    }

    private func clearHoverCard() {
        hoveredMarkerLine = nil
        clearHoverHighlight()
        hoverCard?.isHidden = true
        needsDisplay = true
    }

    private func beginMarkerDrag(_ marker: EditorMarker, event: NSEvent) {
        let lineRange = markerLineRangesByLine[marker.lineNumber]
        let scopeDepth: Int? = {
            guard marker.kind == .cutUnit,
                  let unitIdRaw = marker.metadata["unitId"],
                  let unitId = Int(unitIdRaw) else {
                return nil
            }
            var depth = 0
            var cursor = cutUnitParentByUnitId[unitId] ?? nil
            while let parent = cursor {
                depth += 1
                cursor = cutUnitParentByUnitId[parent] ?? nil
            }
            return depth
        }()
        var payloadMetadata = marker.metadata
        if let scopeDepth {
            payloadMetadata["scopeDepth"] = String(scopeDepth)
        }
        let markerForPayload = EditorMarker(
            id: marker.id,
            kind: marker.kind,
            lineNumber: marker.lineNumber,
            rawText: marker.rawText,
            metadata: payloadMetadata
        )
        guard let encoded = try? dragPayloadCodec.encode(marker: markerForPayload, range: lineRange) else {
            return
        }
        let payload = encoded.hasPrefix(featureFlags.anchorPayloadPrefix)
            ? encoded
            : featureFlags.anchorPayloadPrefix + encoded

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(payload, forType: .string)
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let previewImage = markerDragPreviewImage(marker)
        let dragRect = NSRect(origin: .zero, size: previewImage.size)
        draggingItem.setDraggingFrame(dragRect, contents: previewImage)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    private func markerDragPreviewImage(_ marker: EditorMarker) -> NSImage {
        let size = NSSize(width: 260, height: 72)
        let image = NSImage(size: size)
        image.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        markerAccentColor(marker).withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        markerAccentColor(marker).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        let title = "\(markerTitle(marker)) - line \(marker.lineNumber)" as NSString
        title.draw(
            in: NSRect(x: 10, y: 46, width: 240, height: 18),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        (marker.rawText as NSString).draw(
            in: NSRect(x: 10, y: 10, width: 240, height: 34),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        image.unlockFocus()
        return image
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    private func characterRange(forLineRange lineRange: ClosedRange<Int>) -> NSRange? {
        guard !lineStartOffsets.isEmpty else { return nil }
        let startIndex = min(max(1, lineRange.lowerBound), lineStartOffsets.count) - 1
        let start = lineStartOffsets[startIndex]
        let end: Int
        let nextLine = lineRange.upperBound + 1
        if nextLine >= 1, nextLine <= lineStartOffsets.count {
            end = lineStartOffsets[nextLine - 1]
        } else {
            end = textLength
        }
        let safeStart = min(max(0, start), textLength)
        let safeEnd = min(max(safeStart, end), textLength)
        return NSRange(location: safeStart, length: max(0, safeEnd - safeStart))
    }

    private func applyHoverHighlight(for marker: EditorMarker) {
        guard featureFlags.markerPresentationMode == .gutterOverlay else {
            clearHoverHighlight()
            return
        }
        guard let textView = observedTextView, let layoutManager = textView.layoutManager else { return }
        clearHoverHighlight()
        var highlights: [(NSRange, Int)] = []

        if marker.kind == .cutUnit,
           let rawUnit = marker.metadata["unitId"],
           let unitId = Int(rawUnit) {
            var units: [(Int, Int)] = [(unitId, 0)]
            var idx = 0
            while idx < units.count {
                let (nextUnitId, depth) = units[idx]
                idx += 1
                for (candidateId, parentId) in cutUnitParentByUnitId where parentId == nextUnitId {
                    units.append((candidateId, depth + 1))
                }
            }
            for (uId, depth) in units {
                guard let envelope = cutUnitEnvelopesByUnitId[uId] else { continue }
                for sourceLine in envelope {
                    guard let visible = featureFlags.lineNumberMode == .visibleOnly
                        ? virtualizationIndex.visibleLineNumber(forSourceLine: sourceLine)
                        : sourceLine,
                          visible > 0 else { continue }
                    _ = visible
                }
                if let range = characterRange(forLineRange: envelope), range.length > 0 {
                    highlights.append((range, depth))
                }
            }
        } else if let range = markerCharacterRangesByLine[marker.lineNumber], range.length > 0 {
            highlights.append((range, 0))
        }

        for (range, depth) in highlights {
            let alpha = max(0.06, 0.22 - (CGFloat(depth) * 0.04))
            let color = markerAccentColor(marker).withAlphaComponent(alpha)
            layoutManager.addTemporaryAttributes([.backgroundColor: color], forCharacterRange: range)
            highlightedCharacterRanges.append(range)
        }
    }

    private func clearHoverHighlight() {
        guard let textView = observedTextView, let layoutManager = textView.layoutManager else {
            highlightedCharacterRanges = []
            return
        }
        for range in highlightedCharacterRanges {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        }
        highlightedCharacterRanges = []
    }
}

private final class EditorAnchorHoverCardView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let bodyField = NSTextField(labelWithString: "")
    private let padding = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.zPosition = 9_999

        titleField.font = .systemFont(ofSize: 11, weight: .semibold)
        titleField.textColor = .secondaryLabelColor
        bodyField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        bodyField.textColor = .labelColor
        bodyField.maximumNumberOfLines = 4
        bodyField.lineBreakMode = .byWordWrapping
        addSubview(titleField)
        addSubview(bodyField)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, body: String, accentColor: NSColor) {
        titleField.stringValue = title
        bodyField.stringValue = body
        layer?.borderColor = accentColor.withAlphaComponent(0.7).cgColor
        layer?.backgroundColor = accentColor.withAlphaComponent(0.12).blended(withFraction: 0.85, of: .windowBackgroundColor)?.cgColor
        needsLayout = true
    }

    func preferredSize(maxWidth: CGFloat) -> NSSize {
        let contentWidth = max(180, maxWidth - padding.left - padding.right)
        let titleSize = measureLabel(titleField, width: contentWidth)
        let bodySize = measureLabel(bodyField, width: contentWidth)
        let width = min(maxWidth, max(titleSize.width, bodySize.width) + padding.left + padding.right)
        let height = titleSize.height + bodySize.height + padding.top + padding.bottom + 4
        return NSSize(width: width, height: max(56, height))
    }

    override func layout() {
        super.layout()
        let contentWidth = bounds.width - padding.left - padding.right
        let titleSize = measureLabel(titleField, width: contentWidth)
        let bodySize = measureLabel(bodyField, width: contentWidth)
        let titleY = bounds.height - padding.top - titleSize.height
        titleField.frame = NSRect(x: padding.left, y: titleY, width: contentWidth, height: titleSize.height)
        let bodyY = max(padding.bottom, titleY - 4 - bodySize.height)
        bodyField.frame = NSRect(x: padding.left, y: bodyY, width: contentWidth, height: bodySize.height)
    }

    private func measureLabel(_ label: NSTextField, width: CGFloat) -> NSSize {
        let source = label.attributedStringValue.string
        let attributes: [NSAttributedString.Key: Any] = [
            .font: label.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        let rect = (source as NSString).boundingRect(
            with: NSSize(width: max(0, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return NSSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}
