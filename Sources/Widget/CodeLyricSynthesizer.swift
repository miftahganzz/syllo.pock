//
//  CodeLyricSynthesizer.swift
//  lirik
//
//  Created by Miftah on 2026.
//  Transforms real-time lyrics into rich, authentic programming code syntax statements.
//  Features authentic VS Code Dark+ styling with diverse multi-language programming paradigms.
//  Licensed under MIT License.
//

import AppKit

public struct CodeToken: Sendable {
    public enum Role: Sendable {
        case keyword       // Blue #569CD6 (func, let, mut, const, var, await, async, return, def, fn, select, case, match, with, guard, Ok, Some)
        case flowKeyword   // Purple #C586C0 (if, else, try, catch, throws, yield, for, in, do, end, loop, break)
        case type          // Teal #4EC9B0 (String, Text, Vibe, Audio, Player, Track, Soul, Result, Mood, Live)
        case method        // Light Yellow #DCDCAA (sing, express, resonate, drop, emit, spit, flow, listen, echo, unwrap, map, filter, pipe)
        case variable      // Light Blue #9CDCFE (heart, mic, voice, vibe, singer, soul, stream, track, me, you, we, it, crowd)
        case property      // Purple #C586C0 (feel:, with:, echo:, key:, tempo:, mood:, beat:, status:)
        case bracket       // Gold #FFD700 ( (, ), {, }, [, ], | )
        case punctuation   // Light Gray #D4D4D4 ( ., ,, :, ;, ->, =>, ::, <-, <<, |> )
        case string        // Orange #CE9178 ( "..." )
        case comment       // Green #6A9955 ( // ... )
        case number        // Light Green #B5CEA8 ( 100, 200, 42 )
        case plain         // White #D4D4D4
    }

    public let text: String
    public let role: Role

    public init(_ text: String, _ role: Role) {
        self.text = text
        self.role = role
    }

    public var color: NSColor {
        switch role {
        case .keyword:
            return NSColor(red: 0x56 / 255.0, green: 0x9C / 255.0, blue: 0xD6 / 255.0, alpha: 1.0)
        case .flowKeyword:
            return NSColor(red: 0xC5 / 255.0, green: 0x86 / 255.0, blue: 0xC0 / 255.0, alpha: 1.0)
        case .type:
            return NSColor(red: 0x4E / 255.0, green: 0xC9 / 255.0, blue: 0xB0 / 255.0, alpha: 1.0)
        case .method:
            return NSColor(red: 0xDC / 255.0, green: 0xDC / 255.0, blue: 0xAA / 255.0, alpha: 1.0)
        case .variable:
            return NSColor(red: 0x9C / 255.0, green: 0xDC / 255.0, blue: 0xFE / 255.0, alpha: 1.0)
        case .property:
            return NSColor(red: 0xC5 / 255.0, green: 0x86 / 255.0, blue: 0xC0 / 255.0, alpha: 1.0)
        case .bracket:
            return NSColor(red: 1.0, green: 0xD7 / 255.0, blue: 0.0, alpha: 1.0)
        case .punctuation:
            return NSColor(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0, alpha: 1.0)
        case .string:
            return NSColor(red: 0xCE / 255.0, green: 0x91 / 255.0, blue: 0x78 / 255.0, alpha: 1.0)
        case .comment:
            return NSColor(red: 0x6A / 255.0, green: 0x99 / 255.0, blue: 0x55 / 255.0, alpha: 1.0)
        case .number:
            return NSColor(red: 0xB5 / 255.0, green: 0xCE / 255.0, blue: 0xA8 / 255.0, alpha: 1.0)
        case .plain:
            return NSColor(red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0, alpha: 1.0)
        }
    }
}

public final class CodeLyricSynthesizer: Sendable {

    public static let shared = CodeLyricSynthesizer()

    private let actors = ["me", "you", "we", "it", "they", "singer", "vibe", "soul", "crowd"]
    private let dslMethods = ["say", "cant", "keep", "wont", "sing", "stitch", "feel", "hold", "drop", "flow"]
    private let dslKeys = ["be", "stitch", "hold", "feel", "vibe", "echo", "status", "mood"]

    // MARK: - Synthesis Entry Point

    // Touch Bar lyric zone ≈ 230px wide, monospace font ≈ 6.5px/char → ~35 chars max per token
    // We keep part1 ≤ 18 chars and part2 ≤ 18 chars so the full code expression fits.
    private static let maxPartChars = 18

    public func synthesizeTokens(lyric: String, trackTitle: String, lineIndex: Int) -> [CodeToken] {
        var clean = lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("❙❙ ") {
            clean = String(clean.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        // Instrumental / Silence Detection
        if clean.isEmpty || clean.hasPrefix("♪") || clean.lowercased().contains("instrumental") {
            return [
                CodeToken("// ♪ ", .comment),
                CodeToken("awaiting...", .comment)
            ]
        }

        // Outro / Up Next Countdown Detection
        if clean.lowercased().contains("up next") || clean.lowercased().contains("outro") {
            return [
                CodeToken("queue", .variable),
                CodeToken(".", .punctuation),
                CodeToken("next", .method),
                CodeToken("() ", .bracket),
                CodeToken("// outro", .comment)
            ]
        }

        let split = splitLyric(clean)
        // Truncate to maxPartChars to prevent overflow
        let part1 = truncate(escapeStringLiteral(split.part1), to: Self.maxPartChars)
        let part2 = split.part2.map { truncate(escapeStringLiteral($0), to: Self.maxPartChars) }

        // Deterministic Seed per Line & Track
        let rawSeed = abs(clean.hashValue ^ (trackTitle.hashValue &* 31) ^ (lineIndex &* 101))
        let archetype = rawSeed % 16

        return buildArchetype(index: archetype, part1: part1, part2: part2, seed: rawSeed)
    }

    private func truncate(_ s: String, to maxChars: Int) -> String {
        guard s.count > maxChars else { return s }
        let truncIdx = s.index(s.startIndex, offsetBy: maxChars - 1)
        return String(s[..<truncIdx]) + "…"
    }

    // MARK: - Smart Split Logic

    private func splitLyric(_ text: String) -> (part1: String, part2: String?) {
        // 1. Natural Punctuation Split
        let delimiters = [", ", " - ", " / ", "; "]
        for delim in delimiters {
            if let range = text.range(of: delim) {
                let p1 = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let p2 = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !p1.isEmpty && !p2.isEmpty {
                    return (p1, p2)
                }
            }
        }

        let words = text.components(separatedBy: " ").filter { !$0.isEmpty }
        if words.count <= 2 {
            return (text, nil)
        }

        if words.count == 3 {
            return (words[0] + " " + words[1], words[2])
        }

        // 2. Conjunction-aware Midpoint Split
        let conjunctions: Set<String> = ["and", "or", "but", "when", "with", "that", "how", "so", "for", "cause", "then", "like"]
        let minIdx = Int(Double(words.count) * 0.35)
        let maxIdx = Int(Double(words.count) * 0.65)

        for i in minIdx...maxIdx {
            let lower = words[i].lowercased()
            if conjunctions.contains(lower) {
                let p1 = words[0..<i].joined(separator: " ")
                let p2 = words[i...].joined(separator: " ")
                return (p1, p2)
            }
        }

        // 3. Exact Center Split
        let mid = words.count / 2
        let p1 = words[0..<mid].joined(separator: " ")
        let p2 = words[mid...].joined(separator: " ")
        return (p1, p2)
    }

    private func escapeStringLiteral(_ str: String) -> String {
        return str.replacingOccurrences(of: "\"", with: "'")
    }

    // MARK: - Multi-Language Syntax Archetypes

    private func buildArchetype(index: Int, part1: String, part2: String?, seed: Int) -> [CodeToken] {
        let p2 = part2 ?? ""

        switch index {
        case 0:
            // TypeScript / ES2024 Fluent Chaining
            if !p2.isEmpty {
                return [
                    CodeToken("await ", .keyword),
                    CodeToken("singer", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("express", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("then", .method),
                    CodeToken("(", .bracket),
                    CodeToken("beat", .variable),
                    CodeToken(" => \"", .punctuation),
                    CodeToken(p2, .string),
                    CodeToken("\")", .bracket)
                ]
            } else {
                return [
                    CodeToken("await ", .keyword),
                    CodeToken("player", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("express", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket)
                ]
            }

        case 1:
            // User's Requested DSL Pattern with Dynamic Actors & Methods
            let actor = actors[(seed / 3) % actors.count]
            let method = dslMethods[(seed / 5) % dslMethods.count]
            let key = dslKeys[(seed / 7) % dslKeys.count]

            if !p2.isEmpty {
                return [
                    CodeToken(actor, .variable),
                    CodeToken(".", .punctuation),
                    CodeToken(method, .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") { ", .bracket),
                    CodeToken("\(key): ", .property),
                    CodeToken("\"\(p2)\"", .string),
                    CodeToken(" }", .bracket)
                ]
            } else {
                return [
                    CodeToken(actor, .variable),
                    CodeToken(".", .punctuation),
                    CodeToken(method, .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket)
                ]
            }

        case 2:
            // Swift / SwiftUI Declarative View Modifier
            if !p2.isEmpty {
                return [
                    CodeToken("Text", .type),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("resonate", .method),
                    CodeToken("(", .bracket),
                    CodeToken("with: ", .property),
                    CodeToken("\"\(p2)\"", .string),
                    CodeToken(")", .bracket)
                ]
            } else {
                return [
                    CodeToken("Text", .type),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("foregroundStyle", .method),
                    CodeToken("(", .bracket),
                    CodeToken(".accent", .variable),
                    CodeToken(")", .bracket)
                ]
            }

        case 3:
            // Rust Pattern Matching
            if !p2.isEmpty {
                return [
                    CodeToken("match ", .keyword),
                    CodeToken("soul", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("state", .method),
                    CodeToken(" { ", .bracket),
                    CodeToken("Live", .type),
                    CodeToken(" => \"", .punctuation),
                    CodeToken(part1, .string),
                    CodeToken("\", ", .bracket),
                    CodeToken("_", .keyword),
                    CodeToken(" => \"", .punctuation),
                    CodeToken(p2, .string),
                    CodeToken("\" }", .bracket)
                ]
            } else {
                return [
                    CodeToken("match ", .keyword),
                    CodeToken("vibe", .variable),
                    CodeToken(" { ", .bracket),
                    CodeToken("Some", .type),
                    CodeToken("(_) => \"", .punctuation),
                    CodeToken(part1, .string),
                    CodeToken("\" }", .bracket)
                ]
            }

        case 4:
            // Rust Result / Option Handling
            if !p2.isEmpty {
                return [
                    CodeToken("let ", .keyword),
                    CodeToken("mut ", .keyword),
                    CodeToken("sound", .variable),
                    CodeToken(" = ", .punctuation),
                    CodeToken("Ok", .type),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("unwrap_or", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\");", .bracket)
                ]
            } else {
                return [
                    CodeToken("let ", .keyword),
                    CodeToken("vocal", .variable),
                    CodeToken(" = ", .punctuation),
                    CodeToken("Ok", .type),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("unwrap", .method),
                    CodeToken("();", .bracket)
                ]
            }

        case 5:
            // Python Context Manager
            if !p2.isEmpty {
                return [
                    CodeToken("with ", .keyword),
                    CodeToken("audio", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("stage", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") ", .bracket),
                    CodeToken("as ", .keyword),
                    CodeToken("mic", .variable),
                    CodeToken(": ", .punctuation),
                    CodeToken("mic", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("drop", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\")", .bracket)
                ]
            } else {
                return [
                    CodeToken("with ", .keyword),
                    CodeToken("melody", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("flow", .method),
                    CodeToken("(): ", .bracket),
                    CodeToken("yield ", .flowKeyword),
                    CodeToken("\"\(part1)\"", .string)
                ]
            }

        case 6:
            // Python Decorator & Return Statement
            if !p2.isEmpty {
                return [
                    CodeToken("@listen", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") ", .bracket),
                    CodeToken("-> ", .punctuation),
                    CodeToken("return ", .flowKeyword),
                    CodeToken("\"\(p2)\"", .string)
                ]
            } else {
                return [
                    CodeToken("@chorus", .method),
                    CodeToken("\ndef ", .keyword),
                    CodeToken("drop", .method),
                    CodeToken("(): ", .bracket),
                    CodeToken("return ", .flowKeyword),
                    CodeToken("\"\(part1)\"", .string)
                ]
            }

        case 7:
            // Go Goroutine & Channel Communication
            if !p2.isEmpty {
                return [
                    CodeToken("go ", .keyword),
                    CodeToken("func", .keyword),
                    CodeToken("() { ", .bracket),
                    CodeToken("mic", .variable),
                    CodeToken(" <- \"", .punctuation),
                    CodeToken(part1, .string),
                    CodeToken("\" ", .bracket),
                    CodeToken("/* \(p2) */", .comment),
                    CodeToken(" }()", .bracket)
                ]
            } else {
                return [
                    CodeToken("go ", .keyword),
                    CodeToken("func", .keyword),
                    CodeToken("() { ", .bracket),
                    CodeToken("mic", .variable),
                    CodeToken(" <- \"", .punctuation),
                    CodeToken(part1, .string),
                    CodeToken("\" }()", .bracket)
                ]
            }

        case 8:
            // Go Select & Channel Receive
            if !p2.isEmpty {
                return [
                    CodeToken("select ", .keyword),
                    CodeToken("{ ", .bracket),
                    CodeToken("case ", .keyword),
                    CodeToken("beat", .variable),
                    CodeToken(" := <-", .punctuation),
                    CodeToken("mic", .variable),
                    CodeToken(": ", .punctuation),
                    CodeToken("sing", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\", \"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\") }", .bracket)
                ]
            } else {
                return [
                    CodeToken("select ", .keyword),
                    CodeToken("{ ", .bracket),
                    CodeToken("case ", .keyword),
                    CodeToken("<-", .punctuation),
                    CodeToken("mic", .variable),
                    CodeToken(": ", .punctuation),
                    CodeToken("sing", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") }", .bracket)
                ]
            }

        case 9:
            // Kotlin Scope Chaining
            if !p2.isEmpty {
                return [
                    CodeToken("melody", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("let ", .method),
                    CodeToken("{ ", .bracket),
                    CodeToken("it", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("sing", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") }", .bracket),
                    CodeToken(".", .punctuation),
                    CodeToken("also ", .method),
                    CodeToken("{ ", .bracket),
                    CodeToken("vibe", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\") }", .bracket)
                ]
            } else {
                return [
                    CodeToken("melody", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("run ", .method),
                    CodeToken("{ ", .bracket),
                    CodeToken("sing", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") }", .bracket)
                ]
            }

        case 10:
            // Swift Guard Clause
            if !p2.isEmpty {
                return [
                    CodeToken("guard ", .keyword),
                    CodeToken("vocal", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("flow", .method),
                    CodeToken("() ", .bracket),
                    CodeToken("else ", .flowKeyword),
                    CodeToken("{ ", .bracket),
                    CodeToken("return ", .flowKeyword),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" } ", .bracket),
                    CodeToken("// \(p2)", .comment)
                ]
            } else {
                return [
                    CodeToken("guard ", .keyword),
                    CodeToken("soul", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("alive ", .method),
                    CodeToken("else ", .flowKeyword),
                    CodeToken("{ ", .bracket),
                    CodeToken("return ", .flowKeyword),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" }", .bracket)
                ]
            }

        case 11:
            // Elixir Pipe Operator
            if !p2.isEmpty {
                return [
                    CodeToken("sound", .variable),
                    CodeToken(" |> ", .punctuation),
                    CodeToken("echo", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket),
                    CodeToken(" |> ", .punctuation),
                    CodeToken("broadcast", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\")", .bracket)
                ]
            } else {
                return [
                    CodeToken("sound", .variable),
                    CodeToken(" |> ", .punctuation),
                    CodeToken("broadcast", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket)
                ]
            }

        case 12:
            // Ruby Block & Iteration
            if !p2.isEmpty {
                return [
                    CodeToken("vibe", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("loop", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\") ", .bracket),
                    CodeToken("do ", .flowKeyword),
                    CodeToken("|", .bracket),
                    CodeToken("flow", .variable),
                    CodeToken("| ", .bracket),
                    CodeToken("flow", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("spit", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\") ", .bracket),
                    CodeToken("end", .flowKeyword)
                ]
            } else {
                return [
                    CodeToken("track", .variable),
                    CodeToken(".", .punctuation),
                    CodeToken("play ", .method),
                    CodeToken("do ", .flowKeyword),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" end", .flowKeyword)
                ]
            }

        case 13:
            // SQL Soul Query
            if !p2.isEmpty {
                return [
                    CodeToken("SELECT ", .keyword),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" FROM ", .keyword),
                    CodeToken("mood", .variable),
                    CodeToken(" WHERE ", .keyword),
                    CodeToken("lyric", .property),
                    CodeToken(" = ", .punctuation),
                    CodeToken("\"\(p2)\"", .string),
                    CodeToken(";", .punctuation)
                ]
            } else {
                return [
                    CodeToken("SELECT ", .keyword),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" FROM ", .keyword),
                    CodeToken("heart", .variable),
                    CodeToken(";", .punctuation)
                ]
            }

        case 14:
            // UNIX Shell Pipeline
            if !p2.isEmpty {
                return [
                    CodeToken("echo ", .method),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" | ", .punctuation),
                    CodeToken("grep ", .method),
                    CodeToken("--sound", .property),
                    CodeToken("=\"", .punctuation),
                    CodeToken(p2, .string),
                    CodeToken("\"", .punctuation)
                ]
            } else {
                return [
                    CodeToken("echo ", .method),
                    CodeToken("\"\(part1)\"", .string),
                    CodeToken(" | ", .punctuation),
                    CodeToken("say", .method)
                ]
            }

        case 15:
            fallthrough
        default:
            // React / Modern Hooks API
            if !p2.isEmpty {
                return [
                    CodeToken("const ", .keyword),
                    CodeToken("[", .bracket),
                    CodeToken("mood", .variable),
                    CodeToken(", ", .punctuation),
                    CodeToken("setVibe", .method),
                    CodeToken("] = ", .punctuation),
                    CodeToken("useSong", .method),
                    CodeToken("(\"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\", \"", .bracket),
                    CodeToken(p2, .string),
                    CodeToken("\")", .bracket)
                ]
            } else {
                return [
                    CodeToken("useMood", .method),
                    CodeToken("(() => \"", .bracket),
                    CodeToken(part1, .string),
                    CodeToken("\")", .bracket)
                ]
            }
        }
    }

    // MARK: - Comment Formatting for Upcoming Subline

    public func formatUpcomingComment(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }
        if clean.hasPrefix("⤷ ") {
            clean = String(clean.dropFirst(2))
        }
        return "// next: \"\(clean.replacingOccurrences(of: "\"", with: "'"))\""
    }
}
