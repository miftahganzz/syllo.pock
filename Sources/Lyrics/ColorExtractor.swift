//
//  ColorExtractor.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import CoreGraphics

enum ColorExtractor {
    /// Extracts the most vibrant, readable color from an NSImage.
    /// Returns a boosted high-contrast NSColor suitable for dark/black backgrounds.
    static func extractDominantColor(from image: NSImage) -> NSColor? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            return nil
        }

        let width = min(cgImage.width, 32)
        let height = min(cgImage.height, 32)
        guard width > 0 && height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var bestColor: NSColor? = nil
        var maxScore: CGFloat = -1.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = CGFloat(rawData[offset]) / 255.0
                let g = CGFloat(rawData[offset + 1]) / 255.0
                let b = CGFloat(rawData[offset + 2]) / 255.0
                let a = CGFloat(rawData[offset + 3]) / 255.0

                guard a > 0.5 else { continue }

                let color = NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
                let hue = color.hueComponent
                let sat = color.saturationComponent
                let bri = color.brightnessComponent

                // Exclude near-black, near-white, or dull grays
                guard bri > 0.25 && sat > 0.20 else { continue }

                // Score based on vibrancy
                let score = sat * 1.6 + (bri > 0.5 ? 1.0 : bri)

                if score > maxScore {
                    maxScore = score
                    // Boost brightness to ensure high contrast against black Touch Bar (min 0.88)
                    let boostedBri = max(bri, 0.88)
                    bestColor = NSColor(calibratedHue: hue, saturation: min(sat, 0.85), brightness: boostedBri, alpha: 1.0)
                }
            }
        }

        return bestColor
    }
}
