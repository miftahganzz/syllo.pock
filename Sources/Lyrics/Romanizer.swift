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

    private static var cache: [String: String] = [:]
    private static let lock = NSLock()

    /// Checks whether a string contains East Asian or non-Latin scripts (Korean Hangul, Japanese Kanji/Kana, Chinese Hanzi, Cyrillic, Greek, Arabic, Thai).
    static func containsNonLatin(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let val = scalar.value
            if (val >= 0x1100 && val <= 0x11FF) || // Hangul Jamo
               (val >= 0x3040 && val <= 0x309F) || // Hiragana
               (val >= 0x30A0 && val <= 0x30FF) || // Katakana
               (val >= 0x3130 && val <= 0x318F) || // Hangul Compatibility Jamo
               (val >= 0x31F0 && val <= 0x31FF) || // Katakana Phonetic Extensions
               (val >= 0x3400 && val <= 0x4DBF) || // CJK Extension A
               (val >= 0x4E00 && val <= 0x9FFF) || // CJK Unified Ideographs
               (val >= 0xAC00 && val <= 0xD7AF) || // Hangul Syllables
               (val >= 0xA960 && val <= 0xA97F) || // Hangul Jamo Extended-A
               (val >= 0xD7B0 && val <= 0xD7FF) || // Hangul Jamo Extended-B
               (val >= 0x0370 && val <= 0x03FF) || // Greek
               (val >= 0x0400 && val <= 0x04FF) || // Cyrillic
               (val >= 0x0500 && val <= 0x052F) || // Cyrillic Supplement
               (val >= 0x0600 && val <= 0x06FF) || // Arabic
               (val >= 0x0E00 && val <= 0x0E7F) {   // Thai
                return true
            }
        }
        return false
    }

    /// Converts non-Latin characters into clean, readable Latin/Romaji/Romaja transliteration.
    static func romanize(_ text: String) -> String {
        guard containsNonLatin(text) else { return text }

        lock.lock()
        if let cached = cache[text] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let mutableString = NSMutableString(string: text) as CFMutableString
        // Step 1: Transliterate to Latin
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        // Step 2: Strip tone and combining marks for clean reading & singing
        CFStringTransform(mutableString, nil, kCFStringTransformStripCombiningMarks, false)

        let result = (mutableString as String).trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStr = result.isEmpty ? text : result

        lock.lock()
        if cache.count > 1000 { cache.removeAll() }
        cache[text] = finalStr
        lock.unlock()

        return finalStr
    }
}
