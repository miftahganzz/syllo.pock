//
//  NowPlayingTrack.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// The media source that reported the currently-playing track.
enum NowPlayingSource: String, Sendable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case quickTime = "QuickTime Player"
    case iina = "IINA"
    case vlc = "VLC"
    case browser = "Browser"
    case unknown = "Unknown"
}

/// Snapshot of the currently-playing track at a point in time.
/// Pure value type — no side effects, no framework dependencies.
struct NowPlayingTrack: Sendable, Equatable {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
    let elapsedTime: TimeInterval?
    let isPlaying: Bool
    let source: NowPlayingSource
    let trackID: String?
    let isAdvertisement: Bool

    init(
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval? = nil,
        isPlaying: Bool = false,
        source: NowPlayingSource = .unknown,
        trackID: String? = nil,
        isAdvertisement: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        self.source = source
        self.trackID = trackID
        self.isAdvertisement = isAdvertisement
    }

    /// Two tracks represent the "same song" if title and artist match,
    /// regardless of elapsed time or playback state. Used to detect
    /// track *changes* vs. mere position/state updates.
    func isSameTrack(as other: NowPlayingTrack) -> Bool {
        return title == other.title && artist == other.artist
    }
}
