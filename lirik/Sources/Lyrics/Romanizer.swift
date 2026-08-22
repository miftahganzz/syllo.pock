//
//  Romanizer.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import CoreFoundation

enum Romanizer {

    /// Checks whether a string contains East Asian / non-Latin scripts (Japanese, Korean, Chinese, Cyrillic, Arabic).
    static func containsNonLatin(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // Check ranges for CJK, Hangul, Hiragana, Katakana, Cyrillic, Arabic
            let val = scalar.value
            if (val >= 0x3040 && val <= 0x309F) || // Hiragana
               (val >= 0x30A0 && val <= 0x30FF) || // Katakana
               (val >= 0x4E00 && val <= 0x9FFF) || // CJK Unified Ideographs
               (val >= 0xAC00 && val <= 0xD7AF) || // Hangul Syllables
               (val >= 0x0400 && val <= 0x04FF) || // Cyrillic
               (val >= 0x0600 && val <= 0x06FF) {   // Arabic
                return true
            }
        }
        return false
    }

    /// Converts non-Latin characters into clean, readable Latin/Romaji transliteration.
    static func romanize(_ text: String) -> String {
        guard containsNonLatin(text) else { return text }

        let mutableString = NSMutableString(string: text) as CFMutableString
        // Step 1: Transliterate to Latin
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        // Step 2: Strip tone/combining diacritics for clean reading
        CFStringTransform(mutableString, nil, kCFStringTransformStripCombiningMarks, false)

        let result = (mutableString as String).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? text : result
    }
}
