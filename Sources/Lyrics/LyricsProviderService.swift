//
//  LyricsProviderService.swift
//  syllo
//
//  Created by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// Unified lyrics result from multi-provider engine.
enum LyricsProviderResult: Sendable, Equatable {
    case synced(source: String, lrcText: String, plainLyrics: String?)
    case plainOnly(source: String, plainText: String)
    case notFound
}

/// Multi-provider engine managing LRCLIB, NetEase Cloud Music, and Kugou with auto-failover.
final class LyricsProviderService: Sendable {

    static let shared = LyricsProviderService()

    private let lrclibClient = LRCLIBClient()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches lyrics attempting LRCLIB first, then NetEase, then Kugou.
    func fetchLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: Double? = nil
    ) async -> LyricsProviderResult {
        let cleanTitle = LRCLIBClient.cleanTrackTitle(title)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Primary: LRCLIB (Precise syllable/word-level synced lyrics)
        if let lrclibResult = try? await lrclibClient.fetchLyrics(
            title: cleanTitle,
            artist: cleanArtist,
            album: album,
            duration: duration
        ) {
            switch lrclibResult {
            case .synced(_, let lrcText, let plain):
                NSLog("[LyricsProvider] Matched via LRCLIB (Synced)")
                return .synced(source: "LRCLIB", lrcText: lrcText, plainLyrics: plain)
            case .plainOnly(_, let plainText):
                // If only plain text found on LRCLIB, check NetEase & Kugou for synced LRC first!
                if let netEaseLRC = await fetchNetEaseLyrics(title: cleanTitle, artist: cleanArtist) {
                    NSLog("[LyricsProvider] Upgraded to Synced via NetEase Cloud Music")
                    return .synced(source: "NetEase", lrcText: netEaseLRC, plainLyrics: plainText)
                }
                if let kugouLRC = await fetchKugouLyrics(title: cleanTitle, artist: cleanArtist) {
                    NSLog("[LyricsProvider] Upgraded to Synced via Kugou")
                    return .synced(source: "Kugou", lrcText: kugouLRC, plainLyrics: plainText)
                }
                return .plainOnly(source: "LRCLIB", plainText: plainText)
            case .notFound:
                break
            }
        }

        // 2. Secondary: NetEase Cloud Music API (Rich catalog for Asian, J-Pop, K-Pop, Indie & Indonesian pop)
        if let netEaseLRC = await fetchNetEaseLyrics(title: cleanTitle, artist: cleanArtist) {
            NSLog("[LyricsProvider] Matched via NetEase Cloud Music")
            return .synced(source: "NetEase", lrcText: netEaseLRC, plainLyrics: nil)
        }

        // 3. Tertiary: Kugou Music API (Vast fallback catalog for international & regional tracks)
        if let kugouLRC = await fetchKugouLyrics(title: cleanTitle, artist: cleanArtist) {
            NSLog("[LyricsProvider] Matched via Kugou Music")
            return .synced(source: "Kugou", lrcText: kugouLRC, plainLyrics: nil)
        }

        NSLog("[LyricsProvider] No lyrics found across all providers for: \(cleanArtist) - \(cleanTitle)")
        return .notFound
    }

    // MARK: - NetEase Cloud Music Provider

    private func fetchNetEaseLyrics(title: String, artist: String) async -> String? {
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&offset=0&total=true&limit=5") else {
            return nil
        }

        var req = URLRequest(url: searchUrl)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await session.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]], !songs.isEmpty else {
            return nil
        }

        let cleanArtist = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var bestID: Int?
        for s in songs {
            let name = (s["name"] as? String ?? "").lowercased()
            let artists = (s["artists"] as? [[String: Any]])?.compactMap { ($0["name"] as? String)?.lowercased() } ?? []
            let artistMatches = cleanArtist.isEmpty || artists.contains(where: { $0.contains(cleanArtist) || cleanArtist.contains($0) })
            let titleMatches = name.contains(cleanTitle) || cleanTitle.contains(name)

            if artistMatches && titleMatches {
                bestID = s["id"] as? Int
                break
            }
        }

        guard let songID = bestID ?? songs.first?["id"] as? Int,
              let lyricUrl = URL(string: "https://music.163.com/api/song/lyric?os=osx&id=\(songID)&lv=-1&kv=-1&tv=-1") else {
            return nil
        }

        var lyricReq = URLRequest(url: lyricUrl)
        lyricReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        lyricReq.timeoutInterval = 4.0

        guard let (lrcData, _) = try? await session.data(for: lyricReq),
              let lrcJson = try? JSONSerialization.jsonObject(with: lrcData) as? [String: Any],
              let lrcDict = lrcJson["lrc"] as? [String: Any],
              let lrcText = lrcDict["lyric"] as? String,
              !lrcText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return lrcText
    }

    // MARK: - Kugou Music Provider

    private func fetchKugouLyrics(title: String, artist: String) async -> String? {
        let query = "\(artist) \(title)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "http://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=\(encoded)&duration=0&hash=") else {
            return nil
        }

        var req = URLRequest(url: searchUrl)
        req.timeoutInterval = 4.0

        guard let (data, _) = try? await session.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let id = first["id"] as? String,
              let accesskey = first["accesskey"] as? String,
              let dlUrl = URL(string: "http://lyrics.kugou.com/download?ver=1&client=pc&id=\(id)&accesskey=\(accesskey)&fmt=lrc&charset=utf8") else {
            return nil
        }

        var dlReq = URLRequest(url: dlUrl)
        dlReq.timeoutInterval = 4.0

        guard let (dlData, _) = try? await session.data(for: dlReq),
              let dlJson = try? JSONSerialization.jsonObject(with: dlData) as? [String: Any],
              let b64 = dlJson["content"] as? String,
              let decodedData = Data(base64Encoded: b64),
              let lrcText = String(data: decodedData, encoding: .utf8),
              !lrcText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return lrcText
    }
}
