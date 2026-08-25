//
//  KaraokeLyricView.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import QuartzCore

/// Available highlight styles for active lyrics.
enum LyricHighlightStyle: String, CaseIterable, Sendable {
    /// Apple Music / Spotify Active Line Focus (100% full line glow on active line).
    case lineFocus = "lineFocus"
    /// Discrete Word Snap / Block (Highlights whole words one-by-one in solid blocks without partial letter splits).
    case wordBlock = "wordBlock"
    /// Apple Music Sing Word Pill / Capsule (Glowing bubble/pill background jumping over the active word).
    case wordPill = "wordPill"
    /// Smooth Progressive Karaoke Wipe (Continuous smooth character sweep).
    case smoothSweep = "smoothSweep"
}

final class KaraokeLyricView: NSView {

    // MARK: - Word Segmentation Structure

    struct WordSegment {
        let text: String
        let range: Range<String.Index>
        let startCharOffset: Int
        let charCount: Int
    }

    // MARK: - Properties

    var text: String = "Lirik" {
        didSet {
            if oldValue != text {
                cachedWords = nil
                cachedTextSize = nil
                needsDisplay = true
            }
        }
    }

    /// Progress through the current lyric line (0.0 to 1.0).
    var progress: CGFloat = 0.0 {
        didSet {
            let clamped = max(0.0, min(progress, 1.0))
            if abs(clamped - oldValue) > 0.001 {
                needsDisplay = true
            }
        }
    }

    var activeColor: NSColor = .white {
        didSet {
            if oldValue != activeColor {
                needsDisplay = true
            }
        }
    }

    var inactiveColor: NSColor = NSColor.white.withAlphaComponent(0.35) {
        didSet {
            if oldValue != inactiveColor {
                needsDisplay = true
            }
        }
    }

    var font: NSFont = NSFont.boldSystemFont(ofSize: 11) {
        didSet {
            if oldValue != font {
                cachedWords = nil
                cachedTextSize = nil
                needsDisplay = true
            }
        }
    }

    var textAlignment: NSTextAlignment = .left {
        didSet {
            if oldValue != textAlignment {
                needsDisplay = true
            }
        }
    }

    var enableGlow: Bool = true

    /// Whether live lyric highlighting is active (if false, text renders statically bright with full brightness).
    var isHighlightEnabled: Bool = true {
        didSet {
            if oldValue != isHighlightEnabled {
                needsDisplay = true
            }
        }
    }

    /// Active highlight rendering style.
    var highlightStyle: LyricHighlightStyle = .lineFocus {
        didSet {
            if oldValue != highlightStyle {
                needsDisplay = true
            }
        }
    }

    /// Updates text with a smooth line transition animation (slide, fade, pop, instant).
    func updateText(_ newText: String, animation: String) {
        guard self.text != newText else { return }

        guard animation != "instant", wantsLayer, let layer = self.layer else {
            self.text = newText
            return
        }

        layer.removeAnimation(forKey: "lineTransition")
        layer.removeAnimation(forKey: "popScale")

        let transition = CATransition()
        transition.duration = 0.26
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)

        switch animation {
        case "fade":
            transition.type = .fade
        case "pop":
            transition.type = .fade
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0.93, 1.04, 1.0]
            pop.keyTimes = [0.0, 0.55, 1.0]
            pop.duration = 0.26
            pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(pop, forKey: "popScale")
        case "slide":
            fallthrough
        default:
            transition.type = .push
            transition.subtype = .fromBottom
        }

        layer.add(transition, forKey: "lineTransition")
        self.text = newText
    }

    /// Compatibility accessor for legacy toggles.
    var isLineFocusMode: Bool {
        get { highlightStyle == .lineFocus }
        set {
            if newValue {
                highlightStyle = .lineFocus
            } else if highlightStyle == .lineFocus {
                highlightStyle = .wordBlock
            }
        }
    }

    // MARK: - Layout & Word Caching

    private var cachedTextSize: NSSize?
    private var cachedForString: String = ""
    private var cachedForFont: NSFont?

    private var cachedWords: [WordSegment]?
    private var cachedWordsForString: String = ""

    override var isOpaque: Bool {
        return false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    // MARK: - Word Segmentation

    private func extractWordSegments() -> [WordSegment] {
        if let cached = cachedWords, cachedWordsForString == text {
            return cached
        }

        var segments: [WordSegment] = []
        let components = text.components(separatedBy: " ")
        var searchStart = text.startIndex

        for (i, word) in components.enumerated() {
            guard !word.isEmpty else {
                if i < components.count - 1 && searchStart < text.endIndex {
                    searchStart = text.index(after: searchStart)
                }
                continue
            }

            if let wordRange = text.range(of: word, range: searchStart..<text.endIndex) {
                let startOffset = text.distance(from: text.startIndex, to: wordRange.lowerBound)
                segments.append(WordSegment(
                    text: word,
                    range: wordRange,
                    startCharOffset: startOffset,
                    charCount: word.count
                ))
                searchStart = wordRange.upperBound
            }
        }

        cachedWords = segments
        cachedWordsForString = text
        return segments
    }

    private func getActiveWordIndex(from segments: [WordSegment], progress: CGFloat) -> Int {
        guard !segments.isEmpty else { return 0 }
        if progress <= 0.001 { return -1 }
        if progress >= 0.999 { return segments.count - 1 }

        let totalLength = max(1, text.count)
        let currentProgressChar = Int(floor(progress * CGFloat(totalLength)))

        for (index, segment) in segments.enumerated() {
            let segEnd = segment.startCharOffset + segment.charCount
            if currentProgressChar <= segEnd {
                return index
            }
        }
        return segments.count - 1
    }

    private func measureTextSize(for str: NSString, font: NSFont) -> NSSize {
        if let size = cachedTextSize, cachedForString == (str as String), cachedForFont == font {
            return size
        }
        let size = str.size(withAttributes: [.font: font])
        cachedTextSize = size
        cachedForString = str as String
        cachedForFont = font
        return size
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = textAlignment
        paraStyle.lineBreakMode = .byTruncatingTail

        let str = text as NSString
        let textSize = measureTextSize(for: str, font: font)
        let textY = max(0, (bounds.height - textSize.height) / 2)

        let textX: CGFloat
        switch textAlignment {
        case .center:
            textX = max(0, (bounds.width - textSize.width) / 2)
        case .right:
            textX = max(0, bounds.width - textSize.width)
        default:
            textX = 0
        }

        let textRect = NSRect(
            x: textX,
            y: textY,
            width: min(bounds.width - textX, textSize.width + 4),
            height: textSize.height
        )

        // MARK: 1. Apple Music Line Focus Mode / Static Full Brightness (Highlight Disabled)
        if !isHighlightEnabled || highlightStyle == .lineFocus || progress >= 0.999 {
            let shadow = NSShadow()
            if enableGlow {
                shadow.shadowColor = activeColor.withAlphaComponent(0.75)
                shadow.shadowBlurRadius = 5.5
                shadow.shadowOffset = .zero
            }

            let attrsActive: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: activeColor,
                .shadow: shadow,
                .paragraphStyle: paraStyle
            ]
            str.draw(in: textRect, withAttributes: attrsActive)
            return
        }

        // Draw Inactive Dimmed Background Text
        let attrsInactive: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: inactiveColor,
            .paragraphStyle: paraStyle
        ]
        str.draw(in: textRect, withAttributes: attrsInactive)

        guard progress > 0.001 else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // MARK: 2. Word Snap / Discrete Whole-Word Block Mode ("1 kata seblok ga jalan 1")
        if highlightStyle == .wordBlock {
            let segments = extractWordSegments()
            let activeIdx = getActiveWordIndex(from: segments, progress: progress)
            guard activeIdx >= 0, activeIdx < segments.count else { return }

            let activeSegment = segments[activeIdx]
            let endCharCount = min(text.count, activeSegment.startCharOffset + activeSegment.charCount)
            let activePrefix = String(text.prefix(endCharCount)) as NSString
            let blockWidth = min(textRect.width, activePrefix.size(withAttributes: [.font: font]).width)

            ctx.saveGState()
            let clipRect = NSRect(x: textRect.minX, y: 0, width: blockWidth, height: bounds.height)
            ctx.clip(to: clipRect)

            let shadow = NSShadow()
            if enableGlow {
                shadow.shadowColor = activeColor.withAlphaComponent(0.85)
                shadow.shadowBlurRadius = 5.0
                shadow.shadowOffset = .zero
            }

            let attrsActive: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: activeColor,
                .shadow: shadow,
                .paragraphStyle: paraStyle
            ]
            str.draw(in: textRect, withAttributes: attrsActive)
            ctx.restoreGState()
            return
        }

        // MARK: 3. Word Pill / Capsule Bubble Mode
        if highlightStyle == .wordPill {
            let segments = extractWordSegments()
            let activeIdx = getActiveWordIndex(from: segments, progress: progress)
            guard activeIdx >= 0, activeIdx < segments.count else { return }

            // Highlight previous words (0 ..< activeIdx)
            if activeIdx > 0 {
                let prevSegment = segments[activeIdx - 1]
                let passedEnd = min(text.count, prevSegment.startCharOffset + prevSegment.charCount)
                let passedPrefix = String(text.prefix(passedEnd)) as NSString
                let passedWidth = min(textRect.width, passedPrefix.size(withAttributes: [.font: font]).width)

                ctx.saveGState()
                ctx.clip(to: NSRect(x: textRect.minX, y: 0, width: passedWidth, height: bounds.height))
                let attrsPassed: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: activeColor.withAlphaComponent(0.75),
                    .paragraphStyle: paraStyle
                ]
                str.draw(in: textRect, withAttributes: attrsPassed)
                ctx.restoreGState()
            }

            // Draw glowing pill capsule behind active word
            let activeSegment = segments[activeIdx]
            let prefixBefore = String(text.prefix(activeSegment.startCharOffset)) as NSString
            let startX = textRect.minX + prefixBefore.size(withAttributes: [.font: font]).width
            let wordWidth = (activeSegment.text as NSString).size(withAttributes: [.font: font]).width

            let pillRect = NSRect(
                x: startX - 3,
                y: textY - 2,
                width: wordWidth + 6,
                height: textSize.height + 4
            )
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
            activeColor.withAlphaComponent(0.28).setFill()
            pillPath.fill()

            // Draw glowing active word inside pill
            ctx.saveGState()
            let wordClipRect = NSRect(x: startX - 1, y: 0, width: wordWidth + 2, height: bounds.height)
            ctx.clip(to: wordClipRect)
            let shadow = NSShadow()
            if enableGlow {
                shadow.shadowColor = activeColor.withAlphaComponent(0.9)
                shadow.shadowBlurRadius = 6.0
                shadow.shadowOffset = .zero
            }
            let attrsActive: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: activeColor,
                .shadow: shadow,
                .paragraphStyle: paraStyle
            ]
            str.draw(in: textRect, withAttributes: attrsActive)
            ctx.restoreGState()
            return
        }

        // MARK: 4. Smooth Progressive Karaoke Sweep Mode
        let totalChars = text.count
        let rawCharProgress = progress * CGFloat(totalChars)
        let baseCharCount = min(totalChars, Int(floor(rawCharProgress)))
        let charFraction = rawCharProgress - CGFloat(baseCharCount)

        let activeSubstring = String(text.prefix(baseCharCount)) as NSString
        let baseWidth = activeSubstring.size(withAttributes: [.font: font]).width

        let nextCharWidth: CGFloat
        if baseCharCount < totalChars {
            let nextCharIndex = text.index(text.startIndex, offsetBy: baseCharCount)
            let nextCharStr = String(text[nextCharIndex]) as NSString
            nextCharWidth = nextCharStr.size(withAttributes: [.font: font]).width
        } else {
            nextCharWidth = 0
        }

        let fillWidth = min(textRect.width, baseWidth + (nextCharWidth * charFraction))

        ctx.saveGState()
        let clipRect = NSRect(x: textRect.minX, y: 0, width: fillWidth, height: bounds.height)
        ctx.clip(to: clipRect)

        let shadow = NSShadow()
        if enableGlow {
            shadow.shadowColor = activeColor.withAlphaComponent(0.75)
            shadow.shadowBlurRadius = 5.5
            shadow.shadowOffset = .zero
        }

        let attrsActive: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: activeColor,
            .shadow: shadow,
            .paragraphStyle: paraStyle
        ]

        str.draw(in: textRect, withAttributes: attrsActive)
        ctx.restoreGState()
    }
}
