//
//  AlbumArtService.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import CryptoKit

/// Fetches and caches high-fidelity album artwork directly from Spotify/Music CDN with iTunes fallback.
final class AlbumArtService: @unchecked Sendable {

    // MARK: - Cache

    /// In-memory cache for instant access to recently-used artwork.
    private let memoryCache = NSCache<NSString, NSImage>()

    /// Directory for on-disk artwork cache.
    private let diskCacheDir: URL

    /// Tracks in-flight requests to avoid duplicate network calls.
    private var inFlight: [String: Task<NSImage?, Never>] = [:]
    private let lock = NSLock()

    // MARK: - Init

    init() {
        let userCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheDir = userCaches
            .appendingPathComponent("io.github.ridhaaf.lirik", isDirectory: true)
            .appendingPathComponent("artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)

        memoryCache.countLimit = 50
    }

    // MARK: - Public API

    /// Fetches exact album artwork using direct player URL when available, with intelligent iTunes track search fallback.
    func fetchArtwork(
        artist: String,
        album: String?,
        title: String? = nil,
        artworkURL: String? = nil
    ) async -> NSImage? {
        let key: String
        if let directURL = artworkURL, !directURL.isEmpty {
            key = Self.makeArtworkKey(fromURL: directURL)
        } else {
            key = Self.makeArtworkKey(artist: artist, album: album ?? "", title: title ?? "")
        }

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        // 3. Dedup in-flight requests
        lock.lock()
        if let existing = inFlight[key] {
            lock.unlock()
            return await existing.value
        }
        let task = Task<NSImage?, Never> { [weak self] in
            await self?.performFetch(artist: artist, album: album, title: title, directURL: artworkURL, key: key)
        }
        inFlight[key] = task
        lock.unlock()

        let image = await task.value

        lock.lock()
        inFlight.removeValue(forKey: key)
        lock.unlock()

        // 4. Cache in memory if successful
        if let image {
            memoryCache.setObject(image, forKey: key as NSString)
        }

        return image
    }

    // MARK: - Key Generation

    static func makeArtworkKey(artist: String, album: String, title: String = "") -> String {
        let normArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let signature = "\(normArtist)|\(normAlbum)|\(normTitle)"
        let digest = SHA256.hash(data: Data(signature.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func makeArtworkKey(fromURL urlStr: String) -> String {
        let digest = SHA256.hash(data: Data(urlStr.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Fetch Pipeline

    private func performFetch(
        artist: String,
        album: String?,
        title: String?,
        directURL: String?,
        key: String
    ) async -> NSImage? {
        // Priority 1: Exact Direct Artwork URL from Spotify / Media Player CDN
        if let directURLStr = directURL, let directURL = URL(string: directURLStr) {
            if let image = await downloadDirect(url: directURL, cacheKey: key) {
                return image
            }
        }

        let cleanTitle = cleanSearchTerm(title ?? "")
        let cleanArtist = cleanSearchTerm(artist)
        let cleanAlbum = cleanSearchTerm(album ?? "")

        // Priority 2: Precise Song Track Level Search (Title + Artist) on iTunes
        if !cleanTitle.isEmpty && !cleanArtist.isEmpty {
            if let image = await searchAndDownload(
                query: "\(cleanTitle) \(cleanArtist)",
                entity: "musicTrack",
                expectedArtist: cleanArtist,
                cacheKey: key
            ) {
                return image
            }
        }

        // Priority 3: Exact Album Search (Artist + Album) on iTunes
        if !cleanAlbum.isEmpty && !cleanArtist.isEmpty {
            if let image = await searchAndDownload(
                query: "\(cleanArtist) \(cleanAlbum)",
                entity: "album",
                expectedArtist: cleanArtist,
                cacheKey: key
            ) {
                return image
            }
        }

        // Priority 4: Broad fallback search
        if !cleanArtist.isEmpty {
            if let image = await searchAndDownload(
                query: cleanArtist,
                entity: "album",
                expectedArtist: nil,
                cacheKey: key
            ) {
                return image
            }
        }

        return nil
    }

    // MARK: - iTunes Search & Match

    private func searchAndDownload(
        query: String,
        entity: String,
        expectedArtist: String?,
        cacheKey: String
    ) async -> NSImage? {
        guard let encoded = query.trimmingCharacters(in: .whitespaces)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=\(entity)&limit=5") else {
            return nil
        }

        guard let (data, response) = try? await URLSession.shared.data(from: searchURL),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        struct SearchResult: Codable {
            let results: [AlbumResult]
        }
        struct AlbumResult: Codable {
            let artworkUrl60: String?
            let artworkUrl100: String?
            let collectionName: String?
            let trackName: String?
            let artistName: String?
        }

        guard let searchResult = try? JSONDecoder().decode(SearchResult.self, from: data),
              !searchResult.results.isEmpty else {
            return nil
        }

        // Select best candidate verifying artist matches to avoid featured tracks or wrong covers
        var bestResult: AlbumResult?
        if let expected = expectedArtist?.lowercased(), !expected.isEmpty {
            bestResult = searchResult.results.first(where: { result in
                guard let artName = result.artistName?.lowercased() else { return false }
                return artName.contains(expected) || expected.contains(artName)
            })
        }
        if bestResult == nil {
            bestResult = searchResult.results.first
        }

        guard let match = bestResult,
              let rawArtworkURL = match.artworkUrl100 ?? match.artworkUrl60 else {
            return nil
        }

        // Upgrade 100x100 to crisp 300x300 for high-density Retina Touch Bar displays
        let highResURLString = rawArtworkURL.replacingOccurrences(of: "100x100bb", with: "300x300bb")
        guard let artworkURL = URL(string: highResURLString) else { return nil }

        return await downloadDirect(url: artworkURL, cacheKey: cacheKey)
    }

    // MARK: - Direct Image Download & Cache

    private func downloadDirect(url: URL, cacheKey: String) async -> NSImage? {
        guard let (imageData, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: imageData) else {
            return nil
        }
        let resized = resizeImage(image, to: NSSize(width: 80, height: 80))
        saveToDisk(key: cacheKey, image: resized)
        return resized
    }

    // MARK: - Helper Methods

    private func cleanSearchTerm(_ term: String) -> String {
        var cleaned = term
        let patterns = [
            "\\(feat\\..*?\\)", "\\(featuring.*?\\)",
            "\\[.*?\\]", "\\(remastered.*?\\)", "\\(live.*?\\)", "\\(deluxe.*?\\)",
            " - Remastered.*", " - Live.*", " - Single.*"
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func diskCacheURL(for key: String) -> URL {
        return diskCacheDir.appendingPathComponent("\(key).png")
    }

    private func loadFromDisk(key: String) -> NSImage? {
        let url = diskCacheURL(for: key)
        guard let image = NSImage(contentsOf: url) else { return nil }
        return image
    }

    private func saveToDisk(key: String, image: NSImage) {
        let url = diskCacheURL(for: key)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        try? pngData.write(to: url, options: .atomic)
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }

    /// Clears all cached artwork from memory and disk.
    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheDir)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }
}
