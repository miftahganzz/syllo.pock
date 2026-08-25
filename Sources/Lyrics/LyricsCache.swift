//
//  LyricsCache.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import CryptoKit

/// Cached state for a track's lyrics.
enum CachedLyricsState: Codable, Sendable, Equatable {
    case synced(lines: [LRCLine], rawLRC: String)
    case plainOnly(text: String)
    case notFound
}

/// A cached entry containing metadata and lyrics state.
struct CachedLyrics: Codable, Sendable, Equatable {
    let lrclibID: Int?
    let trackKey: String
    let lyricsState: CachedLyricsState
    let cachedAt: Date
}

/// Disk cache for lyrics.
final class LyricsCache: Sendable {

    private let cacheDirectory: URL

    /// Initializes cache at the specified directory URL.
    /// Defaults to `~/Library/Caches/io.github.ridhaaf.lirik/lyrics/`.
    init(directoryURL: URL? = nil) {
        if let customURL = directoryURL {
            self.cacheDirectory = customURL
        } else {
            let userCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = userCaches
                .appendingPathComponent("io.github.ridhaaf.lirik", isDirectory: true)
                .appendingPathComponent("lyrics", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Computes a stable, collision-resistant track ID key from track metadata.
    /// Combines normalized artist, title, and rounded duration into a SHA256 hash.
    static func makeTrackKey(title: String, artist: String, duration: TimeInterval? = nil) -> String {
        let normTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let durSec = duration != nil && duration! > 0 ? String(Int(duration!.rounded())) : "0"
        
        let signature = "\(normArtist)|\(normTitle)|\(durSec)"
        let digest = SHA256.hash(data: Data(signature.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Retrieves cached lyrics for a track, if available.
    func get(title: String, artist: String, duration: TimeInterval? = nil) -> CachedLyrics? {
        let key = Self.makeTrackKey(title: title, artist: artist, duration: duration)
        return get(byKey: key)
    }

    /// Retrieves cached lyrics directly by track key.
    func get(byKey key: String) -> CachedLyrics? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedLyrics.self, from: data)
    }

    /// Saves lyrics entry to disk.
    func save(_ entry: CachedLyrics) {
        let fileURL = cacheDirectory.appendingPathComponent("\(entry.trackKey).json")
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Clears all entries from the disk cache.
    func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the number of cached files.
    var count: Int {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) else { return 0 }
        return files.filter { $0.hasSuffix(".json") }.count
    }
}
