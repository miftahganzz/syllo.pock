//
//  QuoteCardGenerator.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit

enum QuoteCardGenerator {

    /// Generates a high-resolution aesthetic lyric quote image and copies it to clipboard.
    static func generateAndCopy(
        title: String,
        artist: String,
        lyricQuote: String,
        artwork: NSImage?,
        highlightColor: NSColor?
    ) -> String? {
        let size = NSSize(width: 1080, height: 1080)
        let image = NSImage(size: size)

        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        let bounds = NSRect(origin: .zero, size: size)

        // 1. Draw Background (Dark Gradient)
        let themeColor = highlightColor ?? NSColor(red: 0.95, green: 0.45, blue: 0.65, alpha: 1.0)
        let darkBg = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)

        darkBg.setFill()
        bounds.fill()

        // 2. Draw Blurred/Ambient Artwork Glow
        if let artwork = artwork {
            ctx.saveGState()
            ctx.setAlpha(0.35)
            artwork.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 0.35)
            ctx.restoreGState()

            // Dark overlay gradient over artwork
            let overlayColor = NSColor(white: 0.05, alpha: 0.75)
            overlayColor.setFill()
            bounds.fill()
        }

        // Radial glow from theme color in center
        ctx.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let glowColors = [themeColor.withAlphaComponent(0.28).cgColor, NSColor.clear.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 540, y: 540),
                startRadius: 50,
                endCenter: CGPoint(x: 540, y: 540),
                endRadius: 520,
                options: []
            )
        }
        ctx.restoreGState()

        // 3. Top Header: "L I R I K"
        let headerFont = NSFont.systemFont(ofSize: 22, weight: .bold)
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.65),
            .kern: 4.0
        ]
        let headerStr = "L I R I K" as NSString
        let headerSize = headerStr.size(withAttributes: headerAttrs)
        headerStr.draw(at: NSPoint(x: (1080 - headerSize.width) / 2, y: 980), withAttributes: headerAttrs)

        // 4. Album Artwork in Card
        let artSize: CGFloat = 200
        let artRect = NSRect(x: (1080 - artSize) / 2, y: 720, width: artSize, height: artSize)

        // Artwork Shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.6).cgColor)
        let artPath = NSBezierPath(roundedRect: artRect, xRadius: 24, yRadius: 24)
        NSColor.black.setFill()
        artPath.fill()
        ctx.restoreGState()

        if let artwork = artwork {
            ctx.saveGState()
            let clipPath = NSBezierPath(roundedRect: artRect, xRadius: 24, yRadius: 24)
            clipPath.addClip()
            artwork.draw(in: artRect)
            ctx.restoreGState()
        }

        // 5. Song Title & Artist
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let titleStr = title as NSString
        let titleSize = titleStr.size(withAttributes: titleAttrs)
        titleStr.draw(at: NSPoint(x: (1080 - titleSize.width) / 2, y: 650), withAttributes: titleAttrs)

        let artistAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.70)
        ]
        let artistStr = artist as NSString
        let artistSize = artistStr.size(withAttributes: artistAttrs)
        artistStr.draw(at: NSPoint(x: (1080 - artistSize.width) / 2, y: 610), withAttributes: artistAttrs)

        // 6. Quotation Marks
        let quoteMarkAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 90, weight: .black),
            .foregroundColor: themeColor.withAlphaComponent(0.85)
        ]
        let quoteMark = "“" as NSString
        let qmSize = quoteMark.size(withAttributes: quoteMarkAttrs)
        quoteMark.draw(at: NSPoint(x: (1080 - qmSize.width) / 2, y: 460), withAttributes: quoteMarkAttrs)

        // 7. Lyric Quote Text (Centered Paragraph)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .center
        paraStyle.lineSpacing = 10

        let quoteFont = NSFont.systemFont(ofSize: 42, weight: .bold)
        let quoteAttrs: [NSAttributedString.Key: Any] = [
            .font: quoteFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paraStyle
        ]

        let quoteRect = NSRect(x: 100, y: 220, width: 880, height: 260)
        let cleanedQuote = lyricQuote.replacingOccurrences(of: "❙❙ ", with: "").replacingOccurrences(of: "⏸ ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        (cleanedQuote as NSString).draw(in: quoteRect, withAttributes: quoteAttrs)

        // 8. Footer Badge: "NOW PLAYING • TOUCH BAR"
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: themeColor.withAlphaComponent(0.9),
            .kern: 1.5
        ]
        let footerStr = "NOW PLAYING ON TOUCH BAR" as NSString
        let footerSize = footerStr.size(withAttributes: footerAttrs)
        footerStr.draw(at: NSPoint(x: (1080 - footerSize.width) / 2, y: 70), withAttributes: footerAttrs)

        image.unlockFocus()

        // Write to Clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
            if let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                pasteboard.setData(pngData, forType: .png)

                // Also save to Downloads folder
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let safeTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
                let filePath = downloads.appendingPathComponent("Lirik_Quote_\(safeTitle).png")
                try? pngData.write(to: filePath, options: .atomic)
                return filePath.path
            }
        }

        return nil
    }
}
