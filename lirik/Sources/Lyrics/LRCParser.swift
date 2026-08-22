//
//  LRCParser.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// A single timestamped word/syllable inside an LRC line.
struct LRCWord: Equatable, Sendable, Codable {
    let timestamp: TimeInterval
    let text: String
}

/// A single timestamped lyric line parsed from LRC format.
struct LRCLine: Equatable, Sendable, Codable {
    /// Timestamp in seconds from the start of the track.
    let timestamp: TimeInterval
    /// The lyric text for this line (may be empty for instrumental gaps).
    let text: String
    /// Optional word-by-word timestamps if Enhanced LRC format is present.
    let words: [LRCWord]

    init(timestamp: TimeInterval, text: String, words: [LRCWord] = []) {
        self.timestamp = timestamp
        self.text = text
        self.words = words
    }
}

/// Parses raw LRC text into sorted, timestamped lyric lines.
enum LRCParser {

    // Matches line headers "[mm:ss.xx]" or "[mm:ss.xxx]" or "[mm:ss]"
    private static let timestampPattern = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]"#,
        options: []
    )

    // Matches inline word tags "<mm:ss.xx>word"
    private static let wordTagPattern = try! NSRegularExpression(
        pattern: #"<(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?>([^<]*)"#,
        options: []
    )

    /// Parses raw LRC text into an array of `LRCLine`, sorted by timestamp.
    static func parse(_ lrcText: String) -> [LRCLine] {
        guard !lrcText.isEmpty else { return [] }

        var lines: [LRCLine] = []

        for rawLine in lrcText.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let nsLine = trimmed as NSString
            let matches = timestampPattern.matches(
                in: trimmed,
                options: [],
                range: NSRange(location: 0, length: nsLine.length)
            )

            if matches.isEmpty { continue }
            guard matches[0].range.location == 0 else { continue }

            var lastMatchEnd = 0
            var timestamps: [TimeInterval] = []

            for match in matches {
                if match.range.location > lastMatchEnd {
                    break
                }
                lastMatchEnd = match.range.location + match.range.length

                guard match.numberOfRanges > 2,
                      let minutes = extractInt(from: trimmed, range: match.range(at: 1)),
                      let seconds = extractInt(from: trimmed, range: match.range(at: 2)) else {
                    continue
                }

                let fractional: Double
                if match.numberOfRanges > 3 {
                    let fractionalRange = match.range(at: 3)
                    if fractionalRange.location != NSNotFound,
                       let fracStr = extractString(from: trimmed, range: fractionalRange) {
                        let padded = fracStr.padding(toLength: 3, withPad: "0", startingAt: 0)
                        fractional = (Double(padded) ?? 0) / 1000.0
                    } else {
                        fractional = 0
                    }
                } else {
                    fractional = 0
                }

                let timestamp = Double(minutes) * 60.0 + Double(seconds) + fractional
                timestamps.append(timestamp)
            }

            if timestamps.isEmpty { continue }

            let remainingText = String(nsLine.substring(from: lastMatchEnd))
                .trimmingCharacters(in: .whitespaces)

            // Check if line has Enhanced LRC inline word timestamps: "<00:12.34>word"
            let (cleanText, words) = parseEnhancedWords(remainingText)

            for ts in timestamps {
                lines.append(LRCLine(timestamp: ts, text: cleanText, words: words))
            }
        }

        // Sort by timestamp
        lines.sort { $0.timestamp < $1.timestamp }
        return lines
    }

    private static func parseEnhancedWords(_ text: String) -> (cleanText: String, words: [LRCWord]) {
        let nsText = text as NSString
        let matches = wordTagPattern.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        guard !matches.isEmpty else {
            return (text, [])
        }

        var clean = ""
        var words: [LRCWord] = []

        for match in matches {
            guard match.numberOfRanges > 4,
                  let minutes = extractInt(from: text, range: match.range(at: 1)),
                  let seconds = extractInt(from: text, range: match.range(at: 2)),
                  let wordContent = extractString(from: text, range: match.range(at: 4)) else {
                continue
            }

            let fractional: Double
            if match.numberOfRanges > 3 {
                let fracRange = match.range(at: 3)
                if fracRange.location != NSNotFound,
                   let fracStr = extractString(from: text, range: fracRange) {
                    let padded = fracStr.padding(toLength: 3, withPad: "0", startingAt: 0)
                    fractional = (Double(padded) ?? 0) / 1000.0
                } else {
                    fractional = 0
                }
            } else {
                fractional = 0
            }

            let wordTimestamp = Double(minutes) * 60.0 + Double(seconds) + fractional
            clean += wordContent
            words.append(LRCWord(timestamp: wordTimestamp, text: wordContent))
        }

        return (clean.trimmingCharacters(in: .whitespaces), words)
    }

    // MARK: - Helpers

    private static func extractString(from string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.location + range.length <= (string as NSString).length,
              let swiftRange = Range(range, in: string) else { return nil }
        return String(string[swiftRange])
    }

    private static func extractInt(from string: String, range: NSRange) -> Int? {
        guard let str = extractString(from: string, range: range) else { return nil }
        return Int(str)
    }
}
