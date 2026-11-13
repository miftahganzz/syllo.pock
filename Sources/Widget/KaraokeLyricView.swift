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
    /// Developer Code Syntax Highlighting (VS Code Dark+ multi-language paradigms with glowing neon red cursor).
    case codeSyntax = "codeSyntax"
}

final class KaraokeLyricView: NSView {

    // MARK: - Word Segmentation Structure

    struct WordSegment {
        let text: String
        let startCharOffset: Int
        let charCount: Int
    }

    // MARK: - Properties

    var text: String = "Lirik" {
        didSet {
            if oldValue != text {
                _cachedWords = nil
                _cachedMeasure = nil
                _cachedCode = nil
                _cachedCharWidths = nil
                needsDisplay = true
            }
        }
    }

    /// Current lyric line index (0-based) for deterministic code syntax variation.
    var lineIndex: Int = 0 {
        didSet {
            if oldValue != lineIndex {
                _cachedCode = nil
                needsDisplay = true
            }
        }
    }

    /// Current playing track title for deterministic code syntax variation.
    var trackTitle: String = "" {
        didSet {
            if oldValue != trackTitle {
                _cachedCode = nil
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
        didSet { if oldValue != activeColor { needsDisplay = true } }
    }

    var inactiveColor: NSColor = NSColor.white.withAlphaComponent(0.35) {
        didSet { if oldValue != inactiveColor { needsDisplay = true } }
    }

    var font: NSFont = NSFont.boldSystemFont(ofSize: 11) {
        didSet {
            if oldValue != font {
                _cachedWords = nil
                _cachedMeasure = nil
                _cachedCode = nil
                _cachedCharWidths = nil
                needsDisplay = true
            }
        }
    }

    var textAlignment: NSTextAlignment = .left {
        didSet { if oldValue != textAlignment { needsDisplay = true } }
    }

    var enableGlow: Bool = true

    var isHighlightEnabled: Bool = true {
        didSet { if oldValue != isHighlightEnabled { needsDisplay = true } }
    }

    var highlightStyle: LyricHighlightStyle = .lineFocus {
        didSet { if oldValue != highlightStyle { needsDisplay = true } }
    }

    // MARK: - Text Transition

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
        default: // slide
            transition.type = .push
            transition.subtype = .fromBottom
        }

        layer.add(transition, forKey: "lineTransition")
        self.text = newText
    }

    var isLineFocusMode: Bool {
        get { highlightStyle == .lineFocus }
        set {
            if newValue { highlightStyle = .lineFocus }
            else if highlightStyle == .lineFocus { highlightStyle = .wordBlock }
        }
    }

    // MARK: - Caches

    private var _cachedMeasure: (text: String, font: NSFont, size: NSSize)?
    private var _cachedWords: (text: String, font: NSFont, segments: [WordSegment])?
    private var _cachedCharWidths: (text: String, font: NSFont, widths: [CGFloat])?
    private var _cachedCode: (text: String, lineIndex: Int, trackTitle: String, font: NSFont,
                               dimmed: NSAttributedString, active: NSAttributedString)?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    // MARK: - Measurement Helpers

    /// Measure full text size (cached).
    private func textSize(str: NSString, font: NSFont) -> NSSize {
        if let c = _cachedMeasure, c.text == str as String, c.font == font { return c.size }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = str.size(withAttributes: attrs)
        _cachedMeasure = (text: str as String, font: font, size: size)
        return size
    }

    /// Compute cumulative pixel widths at each character boundary (cached).
    /// widths[i] = pixel offset from text start to end of character at index i (0-based).
    /// widths.count == text.count.  widths is empty if text is empty.
    private func charWidths(for str: String, font: NSFont) -> [CGFloat] {
        if let c = _cachedCharWidths, c.text == str, c.font == font { return c.widths }

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var result = [CGFloat](repeating: 0, count: str.count)
        var cumulative: CGFloat = 0

        for (i, char) in str.enumerated() {
            let charWidth = (String(char) as NSString).size(withAttributes: attrs).width
            cumulative += charWidth
            result[i] = cumulative
        }

        _cachedCharWidths = (text: str, font: font, widths: result)
        return result
    }

    /// Width of text prefix up to `charCount` characters using pre-built cumulative widths.
    private func prefixWidth(widths: [CGFloat], charCount: Int) -> CGFloat {
        guard charCount > 0, charCount <= widths.count else { return 0 }
        return widths[charCount - 1]
    }

    // MARK: - Word Segmentation (crash-safe, duplicate-word-safe)

    private func wordSegments(for str: String) -> [WordSegment] {
        if let c = _cachedWords, c.text == str, c.font == font { return c.segments }

        var segments: [WordSegment] = []
        var charIdx = 0
        let chars = Array(str)

        // Walk character-by-character to build words, keeping exact char offsets.
        var wordStart: Int? = nil

        func flushWord(to endIdx: Int) {
            guard let ws = wordStart else { return }
            let wordChars = Array(chars[ws..<endIdx])
            if !wordChars.isEmpty {
                segments.append(WordSegment(
                    text: String(wordChars),
                    startCharOffset: ws,
                    charCount: wordChars.count
                ))
            }
            wordStart = nil
        }

        while charIdx < chars.count {
            if chars[charIdx] == " " {
                flushWord(to: charIdx)
            } else {
                if wordStart == nil { wordStart = charIdx }
            }
            charIdx += 1
        }
        flushWord(to: chars.count)

        _cachedWords = (text: str, font: font, segments: segments)
        return segments
    }

    private func activeWordIndex(from segments: [WordSegment], progress: CGFloat) -> Int {
        guard !segments.isEmpty else { return 0 }
        if progress <= 0.001 { return -1 }
        if progress >= 0.999 { return segments.count - 1 }

        let totalLength = max(1, text.count)
        let targetChar = Int(floor(Double(progress) * Double(totalLength)))

        for (i, seg) in segments.enumerated() {
            if targetChar <= seg.startCharOffset + seg.charCount {
                return i
            }
        }
        return segments.count - 1
    }

    // MARK: - Code Syntax Cache

    private func codeAttributedStrings() -> (dimmed: NSAttributedString, active: NSAttributedString) {
        if let c = _cachedCode,
           c.text == text, c.lineIndex == lineIndex,
           c.trackTitle == trackTitle, c.font == font {
            return (c.dimmed, c.active)
        }

        let tokens = CodeLyricSynthesizer.shared.synthesizeTokens(
            lyric: text, trackTitle: trackTitle, lineIndex: lineIndex
        )
        let monoFont = NSFont.monospacedSystemFont(ofSize: max(9.5, font.pointSize - 0.5), weight: .medium)

        let dimmedAttr = NSMutableAttributedString()
        let activeAttr = NSMutableAttributedString()

        for token in tokens {
            let vibrant = token.color
            let dim = vibrant.withAlphaComponent(0.28)
            dimmedAttr.append(NSAttributedString(
                string: token.text,
                attributes: [.font: monoFont, .foregroundColor: dim]
            ))
            activeAttr.append(NSAttributedString(
                string: token.text,
                attributes: [.font: monoFont, .foregroundColor: vibrant]
            ))
        }

        _cachedCode = (text: text, lineIndex: lineIndex, trackTitle: trackTitle, font: font,
                       dimmed: dimmedAttr, active: activeAttr)
        return (dimmed: dimmedAttr, active: activeAttr)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        // All progress values clamped defensively
        let p = max(0.0, min(1.0, progress))

        // ─────────────────────────────────────────────
        // MARK: Mode 0 · Code Syntax (VS Code Dark+ + neon cursor)
        // ─────────────────────────────────────────────
        if highlightStyle == .codeSyntax {
            drawCodeSyntax(progress: p)
            return
        }

        // ─────────────────────────────────────────────
        // Shared layout for modes 1-4
        // ─────────────────────────────────────────────
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = textAlignment
        paraStyle.lineBreakMode = .byTruncatingTail

        let ns = text as NSString
        let tsz = textSize(str: ns, font: font)
        let textY = max(0, (bounds.height - tsz.height) / 2)
        let textX: CGFloat
        switch textAlignment {
        case .center: textX = max(0, (bounds.width - tsz.width) / 2)
        case .right:  textX = max(0, bounds.width - tsz.width)
        default:      textX = 0
        }
        let textRect = NSRect(x: textX, y: textY,
                              width: min(bounds.width - textX, tsz.width + 4),
                              height: tsz.height)

        // Build glow shadow once
        let glowShadow = NSShadow()
        if enableGlow {
            glowShadow.shadowColor = activeColor.withAlphaComponent(0.78)
            glowShadow.shadowBlurRadius = 5.5
            glowShadow.shadowOffset = .zero
        }

        let activeAttrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: activeColor,
            .shadow: glowShadow, .paragraphStyle: paraStyle
        ]
        let inactiveAttrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: inactiveColor,
            .paragraphStyle: paraStyle
        ]

        // ─────────────────────────────────────────────
        // MARK: Mode 1 · Line Focus / Highlight Disabled
        // ─────────────────────────────────────────────
        if !isHighlightEnabled || highlightStyle == .lineFocus || p >= 0.999 {
            ns.draw(in: textRect, withAttributes: activeAttrs)
            return
        }

        // Draw dimmed base layer (all modes below need it)
        ns.draw(in: textRect, withAttributes: inactiveAttrs)

        guard p > 0.001 else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Pre-compute cumulative char widths once per text+font
        let cwidths = charWidths(for: text, font: font)
        let totalWidth = cwidths.last ?? 0

        // ─────────────────────────────────────────────
        // MARK: Mode 2 · Word Snap (whole-word block)
        // ─────────────────────────────────────────────
        if highlightStyle == .wordBlock {
            let segs = wordSegments(for: text)
            let idx  = activeWordIndex(from: segs, progress: p)
            guard idx >= 0, idx < segs.count else { return }

            let seg      = segs[idx]
            let clipEnd  = seg.startCharOffset + seg.charCount
            let clipW    = min(textRect.width, prefixWidth(widths: cwidths, charCount: clipEnd))

            ctx.saveGState()
            ctx.clip(to: NSRect(x: textRect.minX, y: 0, width: clipW, height: bounds.height))
            ns.draw(in: textRect, withAttributes: activeAttrs)
            ctx.restoreGState()
            return
        }

        // ─────────────────────────────────────────────
        // MARK: Mode 3 · Word Pill (capsule bubble)
        // ─────────────────────────────────────────────
        if highlightStyle == .wordPill {
            let segs = wordSegments(for: text)
            let idx  = activeWordIndex(from: segs, progress: p)
            guard idx >= 0, idx < segs.count else { return }

            // 1. Draw all PAST words at 75% brightness (non-overlapping with active)
            if idx > 0 {
                let prevEnd = segs[idx - 1].startCharOffset + segs[idx - 1].charCount
                let pastW   = min(textRect.width, prefixWidth(widths: cwidths, charCount: prevEnd))
                if pastW > 0 {
                    let pastAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: activeColor.withAlphaComponent(0.72),
                        .paragraphStyle: paraStyle
                    ]
                    ctx.saveGState()
                    ctx.clip(to: NSRect(x: textRect.minX, y: 0, width: pastW, height: bounds.height))
                    ns.draw(in: textRect, withAttributes: pastAttrs)
                    ctx.restoreGState()
                }
            }

            // 2. Pill background behind active word (no overlap with past region)
            let seg         = segs[idx]
            let segStartW   = prefixWidth(widths: cwidths, charCount: seg.startCharOffset)
            let segEndW     = prefixWidth(widths: cwidths, charCount: seg.startCharOffset + seg.charCount)
            let wordPxWidth = max(2, segEndW - segStartW)
            let pillX       = textRect.minX + segStartW - 3
            let pillW       = wordPxWidth + 6
            let pillRect    = NSRect(x: pillX, y: textY - 2, width: pillW, height: tsz.height + 4)
            let pillPath    = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
            activeColor.withAlphaComponent(0.26).setFill()
            pillPath.fill()

            // 3. Active word glowing text (strict clip to pill word only, no past overlap)
            let activeWordAttrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: activeColor,
                .shadow: glowShadow, .paragraphStyle: paraStyle
            ]
            ctx.saveGState()
            let wordClipX = textRect.minX + max(0, segStartW - 2)
            let wordClipW = wordPxWidth + 4
            ctx.clip(to: NSRect(x: wordClipX, y: 0, width: wordClipW, height: bounds.height))
            ns.draw(in: textRect, withAttributes: activeWordAttrs)
            ctx.restoreGState()
            return
        }

        // ─────────────────────────────────────────────
        // MARK: Mode 4 · Smooth Karaoke Sweep (progressive fill)
        // ─────────────────────────────────────────────
        // Use cumulative widths for pixel-perfect, glitch-free sweep
        let totalChars   = text.count
        guard totalChars > 0 else { return }
        let rawCharPos   = Double(p) * Double(totalChars)
        let baseChar     = min(totalChars - 1, Int(floor(rawCharPos)))
        let fraction     = rawCharPos - Double(baseChar)

        // Width at end of baseChar
        let baseW        = prefixWidth(widths: cwidths, charCount: baseChar)
        // Width of the NEXT char (baseChar + 1)
        let nextW: CGFloat
        if baseChar + 1 <= totalChars {
            let wEnd = prefixWidth(widths: cwidths, charCount: baseChar + 1)
            nextW = wEnd - baseW
        } else {
            nextW = 0
        }

        let fillW = min(totalWidth, min(textRect.width, baseW + nextW * CGFloat(fraction)))
        guard fillW > 0 else { return }

        ctx.saveGState()
        ctx.clip(to: NSRect(x: textRect.minX, y: 0, width: fillW, height: bounds.height))
        ns.draw(in: textRect, withAttributes: activeAttrs)
        ctx.restoreGState()
    }

    // MARK: - Code Syntax Drawing

    private func drawCodeSyntax(progress p: CGFloat) {
        let (dimmed, active) = codeAttributedStrings()
        let fullSize = active.size()
        let textY = max(0, (bounds.height - fullSize.height) / 2)
        let textX: CGFloat = 2.0

        // 1. Ghost background (dimmed full line)
        dimmed.draw(at: NSPoint(x: textX, y: textY))

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let totalLen = active.length
        guard totalLen > 0 else { return }

        let effectiveP = isHighlightEnabled ? p : 1.0

        // Smooth pixel-based clip rather than NSRange substring size
        // → measure cumulative width of active attributed string token-by-token
        let fullWidth = active.size().width
        let targetWidth = fullWidth * effectiveP

        var activeWidth: CGFloat = 0
        if effectiveP > 0.001 {
            if effectiveP >= 0.999 {
                activeWidth = fullWidth
            } else {
                // Build a temporary NSAttributedString up to the target pixel column
                // by scanning character by character (safe for emoji & multi-codepoint)
                var accW: CGFloat = 0
                var scanIdx = 0
                while scanIdx < totalLen {
                    let charRange = NSRange(location: scanIdx, length: 1)
                    let charAttr  = active.attributedSubstring(from: charRange)
                    let charW     = charAttr.size().width
                    if accW + charW > targetWidth { break }
                    accW += charW
                    scanIdx += 1
                }
                activeWidth = accW
            }

            if activeWidth > 0 {
                ctx.saveGState()
                ctx.clip(to: NSRect(x: textX, y: 0, width: activeWidth, height: bounds.height))
                active.draw(at: NSPoint(x: textX, y: textY))
                ctx.restoreGState()
            }
        }

        // 2. Neon red blinking cursor — only during active typing phase
        let isTyping = effectiveP > 0.001 && effectiveP < 0.999
        if isTyping {
            let cursorX = textX + activeWidth + 1.0
            guard cursorX < bounds.width - 2.0 else { return }

            // Use display-link-safe blink: 1.2s cycle, 50% duty
            let blinkCycle: Double = 1.2
            let phase = fmod(CACurrentMediaTime(), blinkCycle)
            let cursorOn = phase < blinkCycle * 0.55 // 55% on, 45% off — feels snappier

            if cursorOn {
                let cursorH = max(8.0, fullSize.height - 2.0)
                let cursorRect = NSRect(x: cursorX, y: textY + 1, width: 6, height: cursorH)
                let cursorPath = NSBezierPath(roundedRect: cursorRect, xRadius: 1, yRadius: 1)

                ctx.saveGState()
                // Neon glow (shadow drawn first in CoreGraphics space)
                let glowColor = NSColor(red: 1.0, green: 0.23, blue: 0.23, alpha: 0.90)
                ctx.setShadow(offset: .zero, blur: 5.0,
                              color: glowColor.cgColor)
                NSColor(red: 1.0, green: 0.23, blue: 0.23, alpha: 1.0).setFill()
                cursorPath.fill()
                ctx.restoreGState()
            }
        }
    }
}
