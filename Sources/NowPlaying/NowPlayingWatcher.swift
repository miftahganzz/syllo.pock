//
//  NowPlayingWatcher.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// Unified watcher managing real-time playback state and elapsed time across media players.
final class NowPlayingWatcher {

    // MARK: - Callbacks

    var onTrackChange: ((NowPlayingTrack?) -> Void)?
    var onElapsedTimeUpdate: ((TimeInterval) -> Void)?
    var onPermissionDenied: ((String) -> Void)?

    /// The most recently observed track. nil if nothing is playing
    /// or no backend has reported yet.
    private(set) var currentTrack: NowPlayingTrack?

    // MARK: - Backends

    private let mediaRemoteBackend = MediaRemoteBackend()
    private let appleScriptBackend = AppleScriptBackend()

    private enum ActiveBackend {
        case mediaRemote
        case appleScript
    }
    private var activeBackend: ActiveBackend?

    // MARK: - Lifecycle

    /// Starts watching for now-playing changes.
    func startWatching() {
        NSLog("[NowPlayingWatcher] Starting — launching AppleScript backend for Spotify/Apple Music...")
        startAppleScriptBackend()
    }

    /// Stops all watching and cleans up.
    func stopWatching() {
        NSLog("[NowPlayingWatcher] Stopping")
        appleScriptBackend.stopPolling()
        mediaRemoteBackend.stopObserving()
        activeBackend = nil
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        appleScriptBackend.togglePlayPause()
    }

    func seek(to position: TimeInterval) {
        appleScriptBackend.seek(to: position)
    }

    func nextTrack() {
        appleScriptBackend.nextTrack()
    }

    func previousTrack() {
        appleScriptBackend.previousTrack()
    }

    @discardableResult
    func toggleLikeTrack() -> Bool {
        return appleScriptBackend.toggleLikeTrack()
    }

    func adjustSystemVolume(by delta: Float) -> Int {
        return appleScriptBackend.adjustSystemVolume(by: delta)
    }

    func getAppVolume() -> Int? {
        return appleScriptBackend.getAppVolume()
    }

    func setAppVolume(_ volume: Int) {
        appleScriptBackend.setAppVolume(volume)
    }

    func smoothFadeAppVolume(from start: Int, to end: Int, steps: Int = 6, duration: TimeInterval = 0.35) {
        appleScriptBackend.smoothFadeAppVolume(from: start, to: end, steps: steps, duration: duration)
    }

    // MARK: - AppleScript backend

    private func startAppleScriptBackend() {
        activeBackend = .appleScript

        appleScriptBackend.onPermissionDenied = { [weak self] appName in
            self?.onPermissionDenied?(appName)
        }

        appleScriptBackend.startPolling { [weak self] newTrack in
            guard let self else { return }
            self.handleUpdate(newTrack)
        }
    }

    // MARK: - Unified update handling

    /// Processes an update from either backend. Detects track changes
    /// vs. mere elapsed-time updates and fires the appropriate callbacks.
    private func handleUpdate(_ newTrack: NowPlayingTrack?) {
        // Track change detection
        let isNewTrack: Bool
        switch (currentTrack, newTrack) {
        case (nil, nil):
            return // No change: still nothing playing
        case (nil, .some):
            isNewTrack = true
        case (.some, nil):
            isNewTrack = true
        case let (.some(old), .some(new)):
            if new.isAdvertisement {
                // If in advertisement break, detect new ad via track ID change or elapsed time reset
                let trackIDChanged = (old.trackID != new.trackID && !(old.trackID ?? "").isEmpty && !(new.trackID ?? "").isEmpty)
                let timeReset = (old.elapsedTime ?? 0) > ((new.elapsedTime ?? 0) + 3.0)
                let titleChanged = (old.title != new.title)
                isNewTrack = trackIDChanged || timeReset || titleChanged || !old.isAdvertisement
            } else if old.isAdvertisement {
                // Transitioned from ad back to real song
                isNewTrack = true
            } else {
                isNewTrack = !old.isSameTrack(as: new)
            }
        }

        if isNewTrack {
            currentTrack = newTrack
            onTrackChange?(newTrack)
        } else {
            // Same track — update stored state for elapsed time / play state
            currentTrack = newTrack
        }

        // Always fire elapsed-time updates so the sync engine stays current
        if let elapsed = newTrack?.elapsedTime {
            onElapsedTimeUpdate?(elapsed)
        }
    }
}
