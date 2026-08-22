//
//  CanvasVideoService.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

final class CanvasVideoService: Sendable {

    private let cacheDirectory: URL

    init() {
        let userCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = userCaches
            .appendingPathComponent("io.github.ridhaaf.lirik", isDirectory: true)
            .appendingPathComponent("canvas", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Fetches the Spotify Canvas video URL strictly for the given track ID.
    func fetchCanvasURL(trackID: String?, title: String, artist: String) async -> URL? {
        guard let rawTrackID = trackID, !rawTrackID.isEmpty else {
            return nil
        }
        let cleanTrackID = rawTrackID.replacingOccurrences(of: "spotify:track:", with: "").trimmingCharacters(in: .whitespaces)
        guard !cleanTrackID.isEmpty else { return nil }

        // 1. Check local downloaded video cache
        let cachedFileURL = cacheDirectory.appendingPathComponent("\(cleanTrackID).mp4")
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            return cachedFileURL
        }

        // 2. Scan Spotify's local cache strictly for this exact cleanTrackID
        if let directCanvasURL = findCanvasURLInSpotifyCache(forTrackID: cleanTrackID) {
            // Download video to local disk cache for instant looping
            if let (videoData, response) = try? await URLSession.shared.data(from: directCanvasURL),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !videoData.isEmpty {
                try? videoData.write(to: cachedFileURL, options: .atomic)
                return cachedFileURL
            }
            return directCanvasURL
        }

        return nil
    }

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
