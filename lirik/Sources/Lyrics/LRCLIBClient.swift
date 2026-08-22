//
//  LRCLIBClient.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// Explicit result of an LRCLIB lookup — handles "no match found" explicitly.
enum LRCLIBResult: Sendable, Equatable {
    /// Synced LRC lyrics found.
    case synced(id: Int, lrcText: String, plainLyrics: String?)
    /// Only plain text lyrics found (not time-synced).
    case plainOnly(id: Int, plainText: String)
    /// Explicitly no lyrics found on LRCLIB (HTTP 404).
    case notFound
}

/// Errors that represent actual network or system failures (not "not found").
enum LRCLIBError: Error, LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case rateLimited
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LRCLIB API URL request."
        case .networkError(let message):
            return "Network request failed: \(message)"
        case .rateLimited:
            return "LRCLIB rate limit exceeded (HTTP 429)."
        case .serverError(let code):
            return "LRCLIB server error (HTTP \(code))."
        }
    }
}

/// DTO for decoding LRCLIB JSON API responses.
private struct LRCLIBResponseDTO: Decodable {
    let id: Int
    let name: String?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

/// Client for LRCLIB REST API (`https://lrclib.net/api/get` & `https://lrclib.net/api/search`).
final class LRCLIBClient: Sendable {

    private let getBaseURL = "https://lrclib.net/api/get"
    private let searchBaseURL = "https://lrclib.net/api/search"
    private let userAgent = "Lirik/2.0 (macOS TouchBar Lyric Widget)"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sanitizes track titles by stripping common YouTube/Video noise, resolutions, subtitles, remaster tags
    static func cleanTrackTitle(_ title: String) -> String {
        var cleaned = title

        // 1. Remove file extensions
        let extensions = [
            "\\.mp4", "\\.mkv", "\\.mov", "\\.avi", "\\.mp3", "\\.m4a", "\\.flac",
            "\\.wav", "\\.webm", "\\.aac", "\\.ogg", "\\.opus", "\\.wmv", "\\.m4v"
        ]
        for ext in extensions {
            cleaned = cleaned.replacingOccurrences(of: ext + "$", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // 2. Remove resolution & codec patterns in parentheses/brackets
        let noisePatterns = [
            "\\(\\s*\\d{3,4}p[^\\)]*\\)",
            "\\[\\s*\\d{3,4}p[^\\]]*\\]",
            "\\(\\s*(?:4k|2k|hd|fhd|uhd|hevc|h264|h265|x264|x265|aac|flac)[^\\)]*\\)",
            "\\[\\s*(?:4k|2k|hd|fhd|uhd|hevc|h264|h265|x264|x265|aac|flac)[^\\]]*\\]",
            "\\(?\\b(?:official\\s+video|official\\s+music\\s+video|official\\s+audio|official\\s+mv|music\\s+video|lyric\\s+video|lyrics\\s+video|visualizer|audio\\s+track|performance\\s+video)\\b\\)?",
            "\\[?\\b(?:official\\s+video|official\\s+music\\s+video|official\\s+audio|official\\s+mv|music\\s+video|lyric\\s+video|lyrics\\s+video|visualizer|audio\\s+track|performance\\s+video)\\b\\]?",
            "\\(?\\b(?:lirik\\s+terjemahan\\s+indonesia|lirik\\s+terjemahan|terjemahan\\s+indonesia|arti\\s+lirik|sub\\s+indo|lirik\\s+lagu|lirik\\s+video|lirik|terjemahan)\\b\\)?",
            "\\[?\\b(?:lirik\\s+terjemahan\\s+indonesia|lirik\\s+terjemahan|terjemahan\\s+indonesia|arti\\s+lirik|sub\\s+indo|lirik\\s+lagu|lirik\\s+video|lirik|terjemahan)\\b\\]?",
            "\\(?\\b(?:letra\\s+en\\s+español|sub\\s+español|tradução|lyrics|with\\s+lyrics)\\b\\)?",
            "\\[?\\b(?:letra\\s+en\\s+español|sub\\s+español|tradução|lyrics|with\\s+lyrics)\\b\\]?",
            "\\s*\\(.*(?:orchestral|orchestra|acoustic|instrumental|piano|guitar|string|cover|version|slowed|reverb|sped up|remix|edit|mix|mono|stereo|soundtrack|ost|ost\\.|score|session|unplugged|radio|tribute|tribute to).*\\)",
            "\\s*\\[.*(?:orchestral|orchestra|acoustic|instrumental|piano|guitar|string|cover|version|slowed|reverb|sped up|remix|edit|mix|mono|stereo|soundtrack|ost|ost\\.|score|session|unplugged|radio|tribute|tribute to).*\\]",
            "\\s*-\\s*(?:orchestral|orchestra|acoustic|instrumental|piano|guitar|string|cover|version|slowed|reverb|sped up|remix|edit|mix|mono|stereo|soundtrack|ost|ost\\.|score|session|unplugged|radio|tribute).*$",
            "\\s*\\(.*remaster.*\\)",
            "\\s*\\[.*remaster.*\\]",
            "\\s*\\(.*deluxe.*\\)",
            "\\s*\\[.*deluxe.*\\]",
            "\\s*\\(.*edition.*\\)",
            "\\s*\\(.*live.*\\)",
            "\\s*-\\s*live.*",
            "\\s*-\\s*\\d{4}\\s*remaster.*",
            "\\s*-\\s*remastered.*",
            "\\s*\\(feat\\..*\\)",
            "\\s*\\[feat\\..*\\]",
            "\\s*ft\\..*",
            "\\(\\s*\\)", "\\[\\s*\\]"
        ]

        for pattern in noisePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Multi-tier lyrics fetching pipeline
    func fetchLyrics(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBResult {
        let cleanTitle = Self.cleanTrackTitle(title)
        let cleanArtist = Self.cleanTrackTitle(artist)

        // Tier 1: Exact /api/get lookup with original or cleaned metadata
        if !cleanTitle.isEmpty {
            let res = try await queryGetAPI(title: cleanTitle, artist: cleanArtist, album: album, duration: duration)
            if case .synced = res { return res }
            if case .plainOnly = res { return res }
        }

        // Tier 2: Swapped /api/get lookup (for flipped "Song Title - Artist" formats)
        if !cleanArtist.isEmpty && !cleanTitle.isEmpty && cleanArtist != cleanTitle {
            let swappedRes = try await queryGetAPI(title: cleanArtist, artist: cleanTitle, album: nil, duration: duration)
            if case .synced = swappedRes { return swappedRes }
            if case .plainOnly = swappedRes { return swappedRes }
        }

        // Tier 3: Fuzzy /api/search lookup with candidate evaluation
        let searchQueries: [String] = [
            "\(cleanArtist) \(cleanTitle)".trimmingCharacters(in: .whitespaces),
            "\(cleanTitle) \(cleanArtist)".trimmingCharacters(in: .whitespaces),
            cleanTitle
        ].filter { !$0.isEmpty }

        for q in searchQueries {
            if let searchResult = try? await querySearchAPI(query: q, preferredArtist: cleanArtist, duration: duration), searchResult != .notFound {
                return searchResult
            }
        }

        return .notFound
    }

    // MARK: - Exact /api/get

    private func queryGetAPI(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBResult {
        guard var components = URLComponents(string: getBaseURL) else {
            throw LRCLIBError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: title)
        ]

        if !artist.isEmpty {
            queryItems.append(URLQueryItem(name: "artist_name", value: artist))
        }

        if let album = album, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }

        if let duration = duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LRCLIBError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LRCLIBError.networkError("Invalid HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            let dto = try JSONDecoder().decode(LRCLIBResponseDTO.self, from: data)
            if let synced = dto.syncedLyrics, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .synced(id: dto.id, lrcText: synced, plainLyrics: dto.plainLyrics)
            } else if let plain = dto.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .plainOnly(id: dto.id, plainText: plain)
            } else {
                return .notFound
            }

        case 404:
            return .notFound

        case 429:
            throw LRCLIBError.rateLimited

        default:
            return .notFound
        }
    }

    // MARK: - Fuzzy /api/search

    private func querySearchAPI(
        query: String,
        preferredArtist: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> LRCLIBResult {
        guard var components = URLComponents(string: searchBaseURL) else {
            throw LRCLIBError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components.url else {
            throw LRCLIBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .notFound
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return .notFound
        }

        let results = (try? JSONDecoder().decode([LRCLIBResponseDTO].self, from: data)) ?? []
        guard !results.isEmpty else { return .notFound }

        // Find candidate with highest score:
        // Priority 1: Has synced lyrics (+100) vs plain (+50)
        // Priority 2: Matches preferred artist (+80)
        // Priority 3: Closest duration
        var bestCandidate: LRCLIBResponseDTO? = nil
        var bestScore: Double = -1.0

        let lowerArtist = preferredArtist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        for item in results {
            let hasSynced = (item.syncedLyrics != nil && !item.syncedLyrics!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let hasPlain = (item.plainLyrics != nil && !item.plainLyrics!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            guard hasSynced || hasPlain else { continue }

            var score: Double = hasSynced ? 100.0 : 50.0

            if !lowerArtist.isEmpty, let candidateArtist = item.artistName?.lowercased() {
                if candidateArtist.contains(lowerArtist) || lowerArtist.contains(candidateArtist) {
                    score += 80.0
                }
            }

            if let targetDur = duration, targetDur > 0, let itemDur = item.duration, itemDur > 0 {
                let diff = abs(targetDur - itemDur)
                if diff <= 3.0 {
                    score += 40.0
                } else if diff <= 10.0 {
                    score += 20.0
                } else {
                    score -= min(30.0, diff)
                }
            }

            if score > bestScore {
                bestScore = score
                bestCandidate = item
            }
        }

        if let best = bestCandidate {
            if let synced = best.syncedLyrics, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .synced(id: best.id, lrcText: synced, plainLyrics: best.plainLyrics)
            } else if let plain = best.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .plainOnly(id: best.id, plainText: plain)
            }
        }

        return .notFound
    }
}
