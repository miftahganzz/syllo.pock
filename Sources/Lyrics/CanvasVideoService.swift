//
//  CanvasVideoService.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Resolves REAL animated motion artwork videos (Apple Music Motion Artwork & Spotify Canvas).
//  Licensed under MIT License.
//

import Foundation
import SQLite3

final class CanvasVideoService: Sendable {

    private let cacheDirectory: URL

    init() {
        let userCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = userCaches
            .appendingPathComponent("io.github.ridhaaf.lirik", isDirectory: true)
            .appendingPathComponent("canvas", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Fetches the real motion video URL (Apple Music Motion Artwork or Spotify Canvas).
    func fetchCanvasURL(trackID: String?, title: String, artist: String, album: String? = nil) async -> URL? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        let trackKey = "\(cleanArtist)_\(cleanTitle)".replacingOccurrences(of: "/", with: "_")
        let cachedFileURL = cacheDirectory.appendingPathComponent("\(trackKey).mp4")

        // 1. Check local downloaded video cache
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            return cachedFileURL
        }

        // 2. Scan Apple Music Motion Artwork cache (com.apple.Music/MusicUIVideoArtworkCache)
        if let appleMusicMotionURL = await findAppleMusicMotionVideo(title: cleanTitle, artist: cleanArtist, album: album) {
            if appleMusicMotionURL.isFileURL {
                return appleMusicMotionURL
            }
            // If remote URL, download and cache
            if let (videoData, response) = try? await URLSession.shared.data(from: appleMusicMotionURL),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !videoData.isEmpty {
                try? videoData.write(to: cachedFileURL, options: .atomic)
                return cachedFileURL
            }
            return appleMusicMotionURL
        }

        // 3. Scan Spotify's local Canvas cache strictly for Spotify trackID
        if let rawTrackID = trackID, !rawTrackID.isEmpty {
            let cleanTrackID = rawTrackID.replacingOccurrences(of: "spotify:track:", with: "").trimmingCharacters(in: .whitespaces)
            if !cleanTrackID.isEmpty, let directCanvasURL = findCanvasURLInSpotifyCache(forTrackID: cleanTrackID) {
                // Download video to local disk cache for instant looping
                if let (videoData, response) = try? await URLSession.shared.data(from: directCanvasURL),
                   let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !videoData.isEmpty {
                    try? videoData.write(to: cachedFileURL, options: .atomic)
                    return cachedFileURL
                }
                return directCanvasURL
            }
        }

        return nil
    }

    // MARK: - Apple Music Motion Artwork Extraction

    private func findAppleMusicMotionVideo(title: String, artist: String, album: String?) async -> URL? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let musicCacheDb = homeDir.appendingPathComponent("Library/Caches/com.apple.Music/MusicUIVideoArtworkCache/Cache.db")
        let fsDataDir = homeDir.appendingPathComponent("Library/Caches/com.apple.Music/MusicUIVideoArtworkCache/fsCachedData")

        guard FileManager.default.fileExists(atPath: musicCacheDb.path) else { return nil }

        // Find collectionId via iTunes Search API
        guard let collectionId = await searchItunesCollectionId(title: title, artist: artist, album: album) else {
            return nil
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(musicCacheDb.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = """
        SELECT d.receiver_data, r.request_key
        FROM cfurl_cache_response r
        JOIN cfurl_cache_receiver_data d ON r.entry_ID = d.entry_ID
        WHERE r.request_key LIKE '%P\(collectionId)%' AND r.request_key LIKE '%.mp4%'
        ORDER BY r.entry_ID DESC LIMIT 1
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            if let uuidText = sqlite3_column_text(stmt, 0) {
                let uuid = String(cString: uuidText)
                let localFile = fsDataDir.appendingPathComponent(uuid)
                if FileManager.default.fileExists(atPath: localFile.path) {
                    NSLog("[CanvasVideoService] Found local Apple Music motion artwork in fsCachedData: \(uuid)")
                    return localFile
                }
            }
            if let urlText = sqlite3_column_text(stmt, 1) {
                let urlStr = String(cString: urlText)
                if let directURL = URL(string: urlStr) {
                    NSLog("[CanvasVideoService] Found remote Apple Music motion artwork: \(urlStr)")
                    return directURL
                }
            }
        }

        return nil
    }

    private func searchItunesCollectionId(title: String, artist: String, album: String?) async -> Int? {
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let term = (searchAlbum?.isEmpty == false ? "\(cleanArtist) \(searchAlbum!)" : "\(cleanArtist) \(title)")

        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=1") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let collectionId = first["collectionId"] as? Int else {
            return nil
        }

        return collectionId
    }

    // MARK: - Spotify Canvas Extraction

    /// Scans Spotify desktop client cache for canvaz.scdn.co video URLs strictly associated with the given track ID.
    private func findCanvasURLInSpotifyCache(forTrackID trackID: String) -> URL? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let searchDirectories = [
            homeDir.appendingPathComponent("Library/Caches/com.spotify.client/Browser/IndexedDB"),
            homeDir.appendingPathComponent("Library/Caches/com.spotify.client/Browser/Cache/Cache_Data"),
            homeDir.appendingPathComponent("Library/Application Support/Spotify/PersistentCache")
        ]

        let trackPrefix = "spotify:track:\(trackID)".data(using: .utf8)!
        let canvazPattern = #"https://canvaz\.scdn\.co/upload/[a-zA-Z0-9_/]+(?:\.cnvs\.mp4|\.thmb\.[0-9x]+\.jpg)"#
        guard let regex = try? NSRegularExpression(pattern: canvazPattern) else { return nil }

        for baseDir in searchDirectories {
            guard FileManager.default.fileExists(atPath: baseDir.path) else { continue }
            guard let enumerator = FileManager.default.enumerator(at: baseDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                      let size = values.fileSize, size > 0 && size < 15 * 1024 * 1024 else { continue }

                guard let fileData = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { continue }

                // Must contain both trackPrefix and canvaz domain
                guard fileData.range(of: trackPrefix) != nil else { continue }

                // Search for canvaz URL strictly within the chunk of this specific track
                var searchRange = fileData.startIndex..<fileData.endIndex
                while let matchRange = fileData.range(of: trackPrefix, options: [], in: searchRange) {
                    let chunkEnd = min(fileData.endIndex, matchRange.upperBound + 1500)
                    let subdata = fileData.subdata(in: matchRange.upperBound..<chunkEnd)

                    if let text = String(data: subdata, encoding: .ascii) ?? String(data: subdata, encoding: .utf8) {
                        let nsRange = NSRange(text.startIndex..., in: text)
                        if let firstMatch = regex.firstMatch(in: text, options: [], range: nsRange),
                           let range = Range(firstMatch.range, in: text) {
                            var urlString = String(text[range])
                            if urlString.contains(".thmb.") {
                                if let thmbRange = urlString.range(of: #"\.thmb\..*$"#, options: .regularExpression) {
                                    urlString.replaceSubrange(thmbRange, with: ".cnvs.mp4")
                                }
                            }
                            return URL(string: urlString)
                        }
                    }

                    searchRange = matchRange.upperBound..<fileData.endIndex
                }
            }
        }

        return nil
    }
}
