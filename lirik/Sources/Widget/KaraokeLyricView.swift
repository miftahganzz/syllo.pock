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

final class KaraokeLyricView: NSView {

    var text: String = "Lirik" {
        didSet {
            if oldValue != text {
                cachedTextSize = nil
                needsDisplay = true
            }
        }
    }

    /// Progress through the current lyric line (0.0 to 1.0).
    var progress: CGFloat = 0.0 {
        didSet {
            let clamped = max(0.0, min(progress, 1.0))
            if abs(clamped - oldValue) > 0.002 {
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

    // Layout caching to prevent 60fps string measurement CPU spikes
    private var cachedTextSize: NSSize?
    private var cachedForString: String = ""
    private var cachedForFont: NSFont?

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = textAlignment
        paraStyle.lineBreakMode = .byTruncatingTail

        // 1. Inactive Background Text (Dimmed)
        let attrsInactive: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: inactiveColor,
            .paragraphStyle: paraStyle
        ]

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

        let textRect = NSRect(x: textX, y: textY, width: min(bounds.width - textX, textSize.width + 4), height: textSize.height)
        str.draw(in: textRect, withAttributes: attrsInactive)

        // 2. Progressive Word & Character Accurate Karaoke Glow & Fill Wipe
        guard progress > 0.001 else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.saveGState()

        // Measure precise character-by-character substring width to match exact letters & words
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
        let clipRect = NSRect(x: textRect.minX, y: 0, width: fillWidth, height: bounds.height)
        ctx.clip(to: clipRect)

        // Active highlighted text with subtle vibrant glow
        let shadow = NSShadow()
        if enableGlow {
            shadow.shadowColor = activeColor.withAlphaComponent(0.70)
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
    }
}
