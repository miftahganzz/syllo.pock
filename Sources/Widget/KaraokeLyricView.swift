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

    /// Compute exact pixel widths at each character boundary with authentic typography & kerning (cached).
    /// widths[i] = exact typographic pixel offset from text start to character i + 1.
    private func charWidths(for str: String, font: NSFont) -> [CGFloat] {
        if let c = _cachedCharWidths, c.text == str, c.font == font { return c.widths }

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let ns = str as NSString
        let count = str.count
        guard count > 0 else { return [] }

        var result = [CGFloat](repeating: 0, count: count)
        for i in 1...count {
            let sub = ns.substring(to: i) as NSString
            result[i - 1] = sub.size(withAttributes: attrs).width
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
        let monoFont = NSFont.monospacedSystemFont(ofSize: max(10.0, font.pointSize - 0.5), weight: .semibold)

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
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Wipe the layer backing store completely on every frame to kill all ghosting & artifacts
        ctx.clear(bounds)
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
        paraStyle.alignment = .left
        paraStyle.lineBreakMode = .byClipping

        let ns = text as NSString
        let tsz = textSize(str: ns, font: font)
        let textY = max(0, (bounds.height - tsz.height) / 2)
        let availableW = max(10, bounds.width)

        var textX: CGFloat
        if tsz.width > availableW {
            // Horizontal auto-pan for lyrics longer than the available Touch Bar width
            let overflow = tsz.width - availableW
            let scrollProgress = min(1.0, max(0.0, (p - 0.15) / 0.70))
            textX = -(overflow * CGFloat(scrollProgress))
        } else {
            switch textAlignment {
            case .center: textX = max(0, (availableW - tsz.width) / 2)
            case .right:  textX = max(0, availableW - tsz.width)
            default:      textX = 0
            }
        }

        let drawPoint = NSPoint(x: textX, y: textY)

        let glowShadow = NSShadow()
        if enableGlow {
            glowShadow.shadowColor = activeColor.withAlphaComponent(0.80)
            glowShadow.shadowBlurRadius = 5.0
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
            ctx.saveGState()
            ctx.clip(to: bounds)
            ns.draw(at: drawPoint, withAttributes: activeAttrs)
            ctx.restoreGState()
            return
        }

        ctx.saveGState()
        ctx.clip(to: bounds)

        // Draw dimmed base text at exact origin
        ns.draw(at: drawPoint, withAttributes: inactiveAttrs)

        guard p > 0.001 else {
            ctx.restoreGState()
            return
        }

        let cwidths = charWidths(for: text, font: font)
        let totalWidth = cwidths.last ?? tsz.width

        // ─────────────────────────────────────────────
        // MARK: Mode 2 · Word Snap (whole-word block)
        // ─────────────────────────────────────────────
        if highlightStyle == .wordBlock {
            let segs = wordSegments(for: text)
            let idx  = activeWordIndex(from: segs, progress: p)
            if idx >= 0, idx < segs.count {
                let seg = segs[idx]
                let clipEnd = seg.startCharOffset + seg.charCount
                let clipW = prefixWidth(widths: cwidths, charCount: clipEnd)

                ctx.saveGState()
                ctx.clip(to: NSRect(x: textX, y: 0, width: clipW, height: bounds.height))
                ns.draw(at: drawPoint, withAttributes: activeAttrs)
                ctx.restoreGState()
            }
            ctx.restoreGState()
            return
        }

        // ─────────────────────────────────────────────
        // MARK: Mode 3 · Word Pill (capsule bubble)
        // ─────────────────────────────────────────────
        if highlightStyle == .wordPill {
            let segs = wordSegments(for: text)
            let idx  = activeWordIndex(from: segs, progress: p)
            if idx >= 0, idx < segs.count {
                // Past words at 75% alpha
                if idx > 0 {
                    let prevEnd = segs[idx - 1].startCharOffset + segs[idx - 1].charCount
                    let pastW = prefixWidth(widths: cwidths, charCount: prevEnd)
                    if pastW > 0 {
                        let pastAttrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: activeColor.withAlphaComponent(0.72),
                            .paragraphStyle: paraStyle
                        ]
                        ctx.saveGState()
                        ctx.clip(to: NSRect(x: textX, y: 0, width: pastW, height: bounds.height))
                        ns.draw(at: drawPoint, withAttributes: pastAttrs)
                        ctx.restoreGState()
                    }
                }

                // Pill background behind active word
                let seg = segs[idx]
                let segStartW = prefixWidth(widths: cwidths, charCount: seg.startCharOffset)
                let segEndW = prefixWidth(widths: cwidths, charCount: seg.startCharOffset + seg.charCount)
                let wordPxWidth = max(2, segEndW - segStartW)
                let pillRect = NSRect(x: textX + segStartW - 3, y: textY - 2, width: wordPxWidth + 6, height: tsz.height + 4)
                let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
                activeColor.withAlphaComponent(0.26).setFill()
                pillPath.fill()

                // Active glowing word
                ctx.saveGState()
                ctx.clip(to: NSRect(x: textX + segStartW - 2, y: 0, width: wordPxWidth + 4, height: bounds.height))
                ns.draw(at: drawPoint, withAttributes: activeAttrs)
                ctx.restoreGState()
            }
            ctx.restoreGState()
            return
        }

        // ─────────────────────────────────────────────
        // MARK: Mode 4 · Smooth Karaoke Sweep (progressive fill)
        // ─────────────────────────────────────────────
        let totalChars = text.count
        let rawCharPos = Double(p) * Double(totalChars)
        let baseChar = min(totalChars - 1, Int(floor(rawCharPos)))
        let fraction = rawCharPos - Double(baseChar)

        let baseW = prefixWidth(widths: cwidths, charCount: baseChar)
        let nextW: CGFloat
        if baseChar + 1 <= totalChars {
            let wEnd = prefixWidth(widths: cwidths, charCount: baseChar + 1)
            nextW = wEnd - baseW
        } else {
            nextW = 0
        }

        let fillW = min(totalWidth, baseW + nextW * CGFloat(fraction))
        if fillW > 0 {
            ctx.saveGState()
            ctx.clip(to: NSRect(x: textX, y: 0, width: fillW, height: bounds.height))
            ns.draw(at: drawPoint, withAttributes: activeAttrs)
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }

    // MARK: - Code Syntax Drawing (Glitch-Free Non-Overlapping Subpixel Architecture)

    private func drawCodeSyntax(progress p: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let (dimmed, active) = codeAttributedStrings()

        let totalLen = active.length
        guard totalLen > 0 else { return }

        let fullSize = active.size()
        let textY = max(0, (bounds.height - fullSize.height) / 2)
        let textX: CGFloat = 2.0
        let availableW = max(10, bounds.width - 6)

        let effectiveP = isHighlightEnabled ? p : 1.0

        // Smooth horizontal pan if line exceeds available width
        var drawX = textX
        let naturalW = fullSize.width
        if naturalW > availableW {
            let overflow = naturalW - availableW
            let scrollProgress = min(1.0, max(0.0, (effectiveP - 0.15) / 0.70))
            drawX = textX - (overflow * CGFloat(scrollProgress))
        }

        // Strict clip to bounds to prevent drawing outside view
        ctx.saveGState()
        ctx.clip(to: bounds)

        let targetW = naturalW * effectiveP
        var activePixelWidth: CGFloat = 0.0

        if effectiveP >= 0.999 {
            activePixelWidth = naturalW
        } else if effectiveP > 0.001 {
            var accW: CGFloat = 0
            for i in 0..<totalLen {
                let charAttr = active.attributedSubstring(from: NSRange(location: i, length: 1))
                let charW = charAttr.size().width
                if accW + charW > targetW { break }
                accW += charW
            }
            activePixelWidth = accW
        }

        let drawPoint = NSPoint(x: drawX, y: textY)

        // 1. Draw base dimmed code line (100% of tokens in dimmed syntax)
        dimmed.draw(at: drawPoint)

        // 2. Draw active typed code line clipped exactly up to activePixelWidth (1:1 subpixel match, zero glyph drift)
        if activePixelWidth > 0 {
            ctx.saveGState()
            ctx.clip(to: NSRect(x: drawX, y: 0, width: activePixelWidth, height: bounds.height))
            active.draw(at: drawPoint)
            ctx.restoreGState()
        }

        // 3. Draw Neon Red Glowing Cursor (#FF3B3B)
        let isTyping = effectiveP > 0.001 && effectiveP < 0.999
        let cursorX = drawX + activePixelWidth + 1.0
        let cursorH = max(8.0, fullSize.height - 2.0)

        let blinkCycle: Double = 1.0
        let cursorVisible = isTyping || (fmod(CACurrentMediaTime(), blinkCycle) < (blinkCycle * 0.55))

        if cursorVisible && cursorX >= -2 && cursorX < bounds.width - 2 {
            let cursorRect = NSRect(x: cursorX, y: textY + 1.0, width: 4.5, height: cursorH)
            let cursorPath = NSBezierPath(roundedRect: cursorRect, xRadius: 1.2, yRadius: 1.2)

            ctx.saveGState()
            let glowColor = NSColor(red: 1.0, green: 0.23, blue: 0.23, alpha: 0.95).cgColor
            ctx.setShadow(offset: .zero, blur: 4.5, color: glowColor)
            NSColor(red: 1.0, green: 0.23, blue: 0.23, alpha: 1.0).setFill()
            cursorPath.fill()
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }
}
