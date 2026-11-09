//
//  SonoraBridge.swift
//  lirik
//
//  Created by Miftah on 2026.
//  Dissects & bridges Sonora music player state and worded lyrics in real-time.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import SQLite3

final class SonoraBridge: @unchecked Sendable {

    static let shared = SonoraBridge()

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var stateDbPath: String {
        return ("~/Library/Application Support/sonora/state.sqlite" as NSString).expandingTildeInPath
    }

    private var cacheDbPath: String {
        return ("~/Library/Caches/sonora/cache.sqlite" as NSString).expandingTildeInPath
    }

    private var lastObservedPosition: TimeInterval = 0.0
    private var lastObservedDate: Date = Date()

    // MARK: - Process Detection

    func isSonoraRunning() -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.nolight.sonora")
        return !apps.isEmpty
    }

    // MARK: - Live Playback State & Position Extraction

    func fetchCurrentTrack(mediaRemotePlaybackRate: Double = 1.0) -> NowPlayingTrack? {
        guard isSonoraRunning() else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(stateDbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT value FROM app_state WHERE key = 'runtime'"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let text = sqlite3_column_text(stmt, 0) else { return nil }

        let jsonStr = String(cString: text)
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resume = obj["resume"] as? [String: Any],
              let current = resume["current"] as? [String: Any] else { return nil }

        let id = current["id"] as? String ?? ""
        let name = current["name"] as? String ?? "Unknown Title"
        let artists = current["artists"] as? String ?? "Unknown Artist"
        let album = current["album"] as? String
        let cover = current["cover"] as? String
        let duration = current["seconds"] as? Double
        let position = resume["position"] as? Double ?? 0.0
        let provider = resume["provider"] as? String ?? "youtube"

        let isPlaying = mediaRemotePlaybackRate > 0.0

        let trackID = id.isEmpty ? nil : "\(provider):\(id)"

        // If cover is provided, cache it in memory
        if let coverURL = cover, !coverURL.isEmpty {
            if coverURL.hasPrefix("http") {
                // Network URL
            } else if FileManager.default.fileExists(atPath: coverURL),
                      let img = NSImage(contentsOfFile: coverURL) {
                AlbumArtService.shared.storeImageInMemory(img, artist: artists, album: album, title: name)
            }
        }

        return NowPlayingTrack(
            title: name,
            artist: artists,
            album: album,
            duration: duration,
            elapsedTime: position,
            isPlaying: isPlaying,
            source: .sonora,
            trackID: trackID,
            isAdvertisement: false,
            artworkURL: cover
        )
    }

    // MARK: - Cached Syllable/Word-Level Lyrics Extraction

    func fetchCachedLyrics(
        trackID: String?,
        title: String,
        artist: String
    ) -> (source: String, lines: [LRCLine], lrcText: String)? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(cacheDbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        var rawValue: String?

        // 1. Try direct trackID lookup (e.g. "youtube:XDbW5bXrm7I:lyrics")
        if let trackID = trackID, !trackID.isEmpty {
            let key = "\(trackID):lyrics"
            var stmt: OpaquePointer?
            let sql = "SELECT value FROM lyrics WHERE key = ?"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) {
                    rawValue = String(cString: text)
                }
                sqlite3_finalize(stmt)
            }
        }

        // 2. Fallback: Lookup by track title in lyrics table
        if rawValue == nil {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty {
                var stmt: OpaquePointer?
                let sql = "SELECT value FROM lyrics WHERE value LIKE ? ORDER BY stored DESC LIMIT 1"
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    let pattern = "%\(cleanTitle)%"
                    sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
                    if sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) {
                        rawValue = String(cString: text)
                    }
                    sqlite3_finalize(stmt)
                }
            }
        }

        guard let jsonStr = rawValue,
              let data = jsonStr.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = root["hits"] as? [[String: Any]] else {
            return nil
        }

        // Sonora's Ranking Model:
        // Prefers worded lyrics (has words array per line), higher trust beats lower trust
        var bestHit: [String: Any]?
        var bestSource: String = "Sonora"
        var bestTrust: Int = -1
        var bestHasWords = false
        var bestLinesData: [[String: Any]]?

        for h in hits {
            let src = h["source"] as? String ?? "Sonora"
            let trust = h["trust"] as? Int ?? 0
            guard let lyrics = h["lyrics"] as? [String: Any],
                  let synced = lyrics["Synced"] as? [String: Any],
                  let lines = synced["lines"] as? [[String: Any]], !lines.isEmpty else {
                continue
            }

            let hasWords = lines.contains { ($0["words"] as? [[String: Any]])?.isEmpty == false }
            if (!bestHasWords && hasWords) || (bestHasWords == hasWords && trust > bestTrust) {
                bestHit = h
                bestSource = src
                bestTrust = trust
                bestHasWords = hasWords
                bestLinesData = lines
            }
        }

        guard let linesData = bestLinesData, !linesData.isEmpty else {
            return nil
        }

        var parsedLines: [LRCLine] = []
        var reconstructedLRC: [String] = []

        for l in linesData {
            let startObj = l["start"] as? [String: Any] ?? [:]
            let startSecs = Double(startObj["secs"] as? Int ?? 0)
            let startNanos = Double(startObj["nanos"] as? Int ?? 0) / 1_000_000_000.0
            let start = startSecs + startNanos

            let lineText = l["text"] as? String ?? ""
            var words: [LRCWord] = []

            if let wArr = l["words"] as? [[String: Any]], !wArr.isEmpty {
                for w in wArr {
                    let wText = w["text"] as? String ?? ""
                    let wStartObj = w["start"] as? [String: Any] ?? [:]
                    let wStart = Double(wStartObj["secs"] as? Int ?? 0) + Double(wStartObj["nanos"] as? Int ?? 0) / 1_000_000_000.0
                    let wEndObj = w["end"] as? [String: Any] ?? [:]
                    let wEnd = Double(wEndObj["secs"] as? Int ?? 0) + Double(wEndObj["nanos"] as? Int ?? 0) / 1_000_000_000.0
                    let duration = max(0.05, wEnd - wStart)
                    words.append(LRCWord(timestamp: wStart, text: wText, duration: duration))
                }
            }

            parsedLines.append(LRCLine(timestamp: start, text: lineText, words: words))

            // Reconstruct LRC line with tags
            let mm = Int(start) / 60
            let ss = start.truncatingRemainder(dividingBy: 60)
            if !words.isEmpty {
                var lineWithWordTags = String(format: "[%02d:%05.2f]", mm, ss)
                for w in words {
                    let wmm = Int(w.timestamp) / 60
                    let wss = w.timestamp.truncatingRemainder(dividingBy: 60)
                    lineWithWordTags += String(format: "<%02d:%05.2f>%@", wmm, wss, w.text)
                }
                reconstructedLRC.append(lineWithWordTags)
            } else {
                reconstructedLRC.append(String(format: "[%02d:%05.2f]%@", mm, ss, lineText))
            }
        }

        parsedLines.sort { $0.timestamp < $1.timestamp }
        let lrcText = reconstructedLRC.joined(separator: "\n")

        NSLog("[SonoraBridge] Successfully extracted \(parsedLines.count) lines from Sonora cache (source: \(bestSource), trust: \(bestTrust), worded: \(bestHasWords))")
        return (source: "Sonora (\(bestSource))", lines: parsedLines, lrcText: lrcText)
    }
}
