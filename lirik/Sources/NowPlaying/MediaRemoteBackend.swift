//
//  MediaRemoteBackend.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation

/// Low-level MediaRemote private framework wrapper for system playback notifications.
final class MediaRemoteBackend {

    // MARK: - Types

    /// Callback signature for MRMediaRemoteGetNowPlayingInfo.
    /// The dictionary uses CFString keys like "kMRMediaRemoteNowPlayingInfoTitle".
    private typealias GetNowPlayingInfoFn =
        @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void

    /// Callback signature for MRMediaRemoteRegisterForNowPlayingNotifications.
    private typealias RegisterForNotificationsFn =
        @convention(c) (DispatchQueue) -> Void

    // MARK: - Known MediaRemote info-dictionary keys
    // These are CFString constants exported by MediaRemote.framework.
    // Discovered via nm / open-source projects; undocumented by Apple.

    static let titleKey      = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artistKey     = "kMRMediaRemoteNowPlayingInfoArtist"
    static let albumKey      = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let durationKey   = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedKey    = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRateKey = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    // Notification names posted by MediaRemote via NotificationCenter.
    static let infoDidChangeNotification =
        NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    static let appDidChangeNotification =
        NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")
    static let playbackStateDidChangeNotification =
        NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")

    // MARK: - State

    private var getNowPlayingInfo: GetNowPlayingInfoFn?
    private var registerForNotifications: RegisterForNotificationsFn?
    private var notificationObservers: [NSObjectProtocol] = []
    private var onUpdate: (([String: Any]) -> Void)?

    /// Whether the framework loaded and symbols resolved successfully.
    private(set) var isAvailable: Bool = false

    // MARK: - Init

    init() {
        loadFramework()
    }

    // MARK: - Framework loading

    /// Loads MediaRemote.framework and resolves function pointers dynamically.
    private func loadFramework() {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"

        guard let bundleURL = NSURL(fileURLWithPath: frameworkPath) as CFURL?,
              let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL) else {
            NSLog("[MediaRemoteBackend] Could not load MediaRemote.framework at \(frameworkPath)")
            return
        }

        guard let getInfoPtr = CFBundleGetFunctionPointerForName(
            bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString
        ) else {
            NSLog("[MediaRemoteBackend] MRMediaRemoteGetNowPlayingInfo symbol not found")
            return
        }

        guard let registerPtr = CFBundleGetFunctionPointerForName(
            bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString
        ) else {
            NSLog("[MediaRemoteBackend] MRMediaRemoteRegisterForNowPlayingNotifications symbol not found")
            return
        }

        getNowPlayingInfo = unsafeBitCast(getInfoPtr, to: GetNowPlayingInfoFn.self)
        registerForNotifications = unsafeBitCast(registerPtr, to: RegisterForNotificationsFn.self)
        isAvailable = true

        NSLog("[MediaRemoteBackend] Framework loaded, symbols resolved")
    }

    // MARK: - Public API

    /// Attempts a one-shot fetch of now-playing info. Calls `completion`
    /// with the parsed track, or nil if the API is blocked/unavailable.
    /// The `timeout` parameter controls how long to wait for the callback
    /// before assuming the API is blocked (macOS 15.4+ entitlement issue).
    func fetchNowPlaying(
        timeout: TimeInterval = 2.0,
        completion: @escaping (NowPlayingTrack?) -> Void
    ) {
        guard let getNowPlayingInfo else {
            completion(nil)
            return
        }

        var didComplete = false
        let lock = NSLock()

        getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            lock.lock()
            guard !didComplete else {
                lock.unlock()
                return
            }
            didComplete = true
            lock.unlock()

            if info.isEmpty {
                completion(nil)
            } else {
                completion(self?.parseInfo(info))
            }
        }

        // Timeout guard — if the callback never fires (macOS 15.4+),
        // we report nil so the caller can fall back to another backend.
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            lock.lock()
            guard !didComplete else {
                lock.unlock()
                return
            }
            didComplete = true
            lock.unlock()

            NSLog("[MediaRemoteBackend] fetchNowPlaying timed out after \(timeout)s — API likely blocked by entitlements")
            completion(nil)
        }
    }

    /// Starts listening for now-playing change notifications.
    /// Calls `onUpdate` with the raw info dictionary on each change.
    func startObserving(onUpdate: @escaping ([String: Any]) -> Void) {
        guard let registerForNotifications else { return }

        self.onUpdate = onUpdate

        let notificationNames: [NSNotification.Name] = [
            Self.infoDidChangeNotification,
            Self.appDidChangeNotification,
            Self.playbackStateDidChangeNotification,
        ]

        for name in notificationNames {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refetchAndNotify()
            }
            notificationObservers.append(observer)
        }

        registerForNotifications(DispatchQueue.main)
        NSLog("[MediaRemoteBackend] Registered for now-playing notifications")
    }

    /// Stops listening and cleans up observers.
    func stopObserving() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        onUpdate = nil
    }

    // MARK: - Internal

    private func refetchAndNotify() {
        guard let getNowPlayingInfo else { return }

        getNowPlayingInfo(DispatchQueue.main) { [weak self] info in
            self?.onUpdate?(info)
        }
    }

    /// Converts the raw MediaRemote info dictionary into a NowPlayingTrack.
    func parseInfo(_ info: [String: Any]) -> NowPlayingTrack? {
        guard let title = info[Self.titleKey] as? String, !title.isEmpty else {
            return nil
        }

        let artist = info[Self.artistKey] as? String ?? "Unknown Artist"
        let album = info[Self.albumKey] as? String
        let duration = info[Self.durationKey] as? TimeInterval
        let elapsed = info[Self.elapsedKey] as? TimeInterval
        let playbackRate = info[Self.playbackRateKey] as? Double ?? 0.0

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: playbackRate > 0,
            source: .unknown // MediaRemote doesn't reliably expose which app is playing
        )
    }
}
