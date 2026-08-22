//
//  AppleScriptBackend.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import ApplicationServices

/// AppleScript and IPC bridge detecting playback state across supported macOS media players.
final class AppleScriptBackend {

    // MARK: - Configuration

    /// How often to poll, in seconds. 1s gives near-real-time detection
    /// without excessive CPU overhead.
    var pollingInterval: TimeInterval = 1.0

    // MARK: - State

    private var pollTimer: Timer?
    private var onUpdate: ((NowPlayingTrack?) -> Void)?
    /// Callback fired when macOS blocks AppleScript with error -1743 (Automation Permission Denied)
    var onPermissionDenied: ((String) -> Void)?

    // MARK: - Permission retry tracking

    private var consecutiveDenials: [String: Int] = [:]
    private let maxConsecutiveDenialsBeforeAlert = 8
    private var subprocessTriggered: Set<String> = []

    // MARK: - Public API

    func fetchNowPlaying(completion: @escaping (NowPlayingTrack?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            let track = self?.queryNowPlaying()
            completion(track)
        }
    }

    func startPolling(onUpdate: @escaping (NowPlayingTrack?) -> Void) {
        self.onUpdate = onUpdate
        consecutiveDenials.removeAll()
        subprocessTriggered.removeAll()

        DispatchQueue.main.async { [weak self] in
            let track = self?.queryNowPlaying()
            self?.onUpdate?(track)
        }

        pollTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            DispatchQueue.main.async {
                let track = self?.queryNowPlaying()
                self?.onUpdate?(track)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        onUpdate = nil
    }

    // MARK: - AppleScript queries

    private func queryNowPlaying() -> NowPlayingTrack? {
        let pref = UserDefaults.standard.string(forKey: "io.github.ridhaaf.lirik.preferredPlayer") ?? "auto"

        switch pref {
        case "spotify":
            if isAppRunning(bundleIdentifier: "com.spotify.client") {
                return querySpotify()
            }
            return nil

        case "music":
            if isAppRunning(bundleIdentifier: "com.apple.Music") {
                return queryAppleMusic()
            }
            return nil

        case "quicktime":
            if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") {
                return queryQuickTime()
            }
            return nil

        case "iina":
            if isAppRunning(bundleIdentifier: "com.colliderli.iina") {
                return queryIINA()
            }
            return nil

        case "vlc":
            if isAppRunning(bundleIdentifier: "org.videolan.vlc") {
                return queryVLC()
            }
            return nil

        default:
            // "auto" mode: Spotify -> Apple Music -> QuickTime Player -> IINA -> VLC
            if isAppRunning(bundleIdentifier: "com.spotify.client"), let track = querySpotify() {
                return track
            }
            if isAppRunning(bundleIdentifier: "com.apple.Music"), let track = queryAppleMusic() {
                return track
            }
            if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX"), let track = queryQuickTime() {
                return track
            }
            if isAppRunning(bundleIdentifier: "com.colliderli.iina"), let track = queryIINA() {
                return track
            }
            if isAppRunning(bundleIdentifier: "org.videolan.vlc"), let track = queryVLC() {
                return track
            }
            return nil
        }
    }

    private func isAppRunning(bundleIdentifier: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    // MARK: - Spotify

    private func querySpotify() -> NowPlayingTrack? {
        let script = """
        tell application "Spotify"
            if player state is stopped then return "|||STOPPED|||"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to (duration of current track) / 1000
            set trackPosition to player position
            set pState to player state as string
            set trackId to id of current track
            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & pState & "|||" & trackId
        end tell
        """

        guard let result = runAppleScript(script, appName: "Spotify") else { return nil }
        if result == "|||STOPPED|||" { return nil }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespaces)
        let artist = parts[1].trimmingCharacters(in: .whitespaces)
        let album = parts[2].trimmingCharacters(in: .whitespaces)
        let durationStr = parts[3].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let elapsedStr = parts[4].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let duration = TimeInterval(durationStr)
        let elapsed = TimeInterval(elapsedStr)
        let stateStr = parts[5].trimmingCharacters(in: .whitespaces).lowercased()
        let trackID = parts.count > 6 ? parts[6].trimmingCharacters(in: .whitespaces) : nil

        let lowerTitle = title.lowercased()
        let lowerArtist = artist.lowercased()
        let isAd = trackID?.contains(":ad:") == true ||
                   artist.isEmpty ||
                   (lowerArtist == "spotify" && (duration ?? 0) < 45) ||
                   lowerTitle.contains("advertisement") ||
                   lowerTitle.contains("spotify - audio ad")

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: stateStr == "playing",
            source: .spotify,
            trackID: trackID,
            isAdvertisement: isAd
        )
    }

    // MARK: - Apple Music

    private func queryAppleMusic() -> NowPlayingTrack? {
        let script = """
        tell application "Music"
            if player state is stopped then return "|||STOPPED|||"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set pState to player state as string
            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & pState
        end tell
        """

        guard let result = runAppleScript(script, appName: "Apple Music") else { return nil }
        if result == "|||STOPPED|||" { return nil }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespaces)
        let artist = parts[1].trimmingCharacters(in: .whitespaces)
        let album = parts[2].trimmingCharacters(in: .whitespaces)
        let durationStr = parts[3].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let elapsedStr = parts[4].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let duration = TimeInterval(durationStr)
        let elapsed = TimeInterval(elapsedStr)
        let stateStr = parts[5].trimmingCharacters(in: .whitespaces).lowercased()

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: stateStr == "playing",
            source: .appleMusic,
            isAdvertisement: false
        )
    }

    // MARK: - QuickTime Player

    private func queryQuickTime() -> NowPlayingTrack? {
        let script = """
        tell application "QuickTime Player"
            try
                if (count of documents) > 0 then
                    set doc to front document
                    set docName to name of doc
                    set docTime to current time of doc
                    set docDuration to duration of doc
                    set isPlaying to playing of doc
                    return docName & "|||" & docTime & "|||" & docDuration & "|||" & isPlaying
                else
                    return "|||STOPPED|||"
                end if
            on error
                return "|||STOPPED|||"
            end try
        end tell
        """

        guard let result = runAppleScript(script, appName: "QuickTime Player") else { return nil }
        if result == "|||STOPPED|||" { return nil }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }

        let rawName = parts[0].trimmingCharacters(in: .whitespaces)
        guard !rawName.isEmpty else { return nil }

        let elapsedStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let durationStr = parts[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let isPlayingStr = parts[3].trimmingCharacters(in: .whitespaces).lowercased()

        let elapsed = TimeInterval(elapsedStr)
        let duration = TimeInterval(durationStr)
        let (title, artist) = parseMediaTitleAndArtist(from: rawName)

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: "QuickTime Media",
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlayingStr == "true",
            source: .quickTime,
            isAdvertisement: false
        )
    }

    // MARK: - VLC Media Player

    private func queryVLC() -> NowPlayingTrack? {
        let script = """
        tell application "VLC"
            try
                if playing then
                    set tName to name of current item
                    set tTime to current time
                    set tDur to duration of current item
                    return tName & "|||" & tTime & "|||" & tDur & "|||true"
                else
                    return "|||STOPPED|||"
                end if
            on error
                return "|||STOPPED|||"
            end try
        end tell
        """

        guard let result = runAppleScript(script, appName: "VLC") else { return nil }
        if result == "|||STOPPED|||" { return nil }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }

        let rawName = parts[0].trimmingCharacters(in: .whitespaces)
        guard !rawName.isEmpty else { return nil }

        let elapsedStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let durationStr = parts[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let isPlayingStr = parts[3].trimmingCharacters(in: .whitespaces).lowercased()

        let elapsed = TimeInterval(elapsedStr)
        let duration = TimeInterval(durationStr)
        let (title, artist) = parseMediaTitleAndArtist(from: rawName)

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: "VLC Media",
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlayingStr == "true",
            source: .vlc,
            isAdvertisement: false
        )
    }

    // MARK: - IINA State Tracking

    private var iinaActiveTitle: String = ""
    private var iinaPlaybackElapsed: TimeInterval = 0.0
    private var iinaLastTick: Date = Date()

    // MARK: - IINA Media Player

    private func queryIINA() -> NowPlayingTrack? {
        guard let iinaApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.colliderli.iina" }) else {
            iinaActiveTitle = ""
            iinaPlaybackElapsed = 0.0
            return nil
        }

        // 1. High-precision IPC state from IINA Bridge (/tmp/iina_lirik.json)
        let bridgePath = "/tmp/iina_lirik.json"
        if FileManager.default.fileExists(atPath: bridgePath),
           let attr = try? FileManager.default.attributesOfItem(atPath: bridgePath),
           let modDate = attr[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < 3.0,
           let data = try? Data(contentsOf: URL(fileURLWithPath: bridgePath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            let rawTitle = (json["title"] as? String) ?? ""
            let rawPath = (json["path"] as? String) ?? ""
            let rawName = !rawTitle.isEmpty ? rawTitle : (URL(fileURLWithPath: rawPath).deletingPathExtension().lastPathComponent)
            
            if !rawName.isEmpty {
                let parsed = parseMediaTitleAndArtist(from: rawName)
                let elapsed = json["position"] as? TimeInterval ?? 0.0
                let dur = json["duration"] as? TimeInterval ?? 0.0
                let isPaused = json["paused"] as? Bool ?? false
                
                return NowPlayingTrack(
                    title: parsed.title,
                    artist: parsed.artist,
                    album: "IINA Media",
                    duration: dur > 0 ? dur : nil,
                    elapsedTime: elapsed,
                    isPlaying: !isPaused,
                    source: .iina,
                    isAdvertisement: false
                )
            }
        }

        // 2. Fallback: Accessibility AXUIElement query
        let pid = iinaApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var rawMediaName: String? = nil
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement] {
            for window in windows {
                var docRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &docRef) == .success,
                   let docURLStr = docRef as? String, !docURLStr.isEmpty,
                   let decoded = docURLStr.removingPercentEncoding,
                   let url = URL(string: decoded) ?? URL(string: docURLStr) {
                    rawMediaName = url.deletingPathExtension().lastPathComponent
                    break
                }

                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String, !title.isEmpty,
                   title != "IINA", title != "Preferences", title != "Open URL", title != "Quick Settings", title != "Inspector" {
                    let parts = title.components(separatedBy: "  —  ")
                    rawMediaName = parts.first ?? title
                    break
                }
            }
        }

        guard let rawName = rawMediaName, !rawName.isEmpty else {
            iinaActiveTitle = ""
            iinaPlaybackElapsed = 0.0
            return nil
        }

        // Determine play/pause state via Playback Menu
        var isPlaying = true
        var menuBarRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
           let menuBar = menuBarRef {
            var menusRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menusRef) == .success,
               let menus = menusRef as? [AXUIElement] {
                for menu in menus {
                    var titleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(menu, kAXTitleAttribute as CFString, &titleRef)
                    if (titleRef as? String) == "Playback" {
                        var childrenRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                           let sub = (childrenRef as? [AXUIElement])?.first {
                            var itemsRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(sub, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                               let items = itemsRef as? [AXUIElement], let firstItem = items.first {
                                var itemTitleRef: CFTypeRef?
                                AXUIElementCopyAttributeValue(firstItem, kAXTitleAttribute as CFString, &itemTitleRef)
                                let itemTitle = itemTitleRef as? String ?? ""
                                if itemTitle.lowercased().contains("play") && !itemTitle.lowercased().contains("pause") {
                                    isPlaying = false
                                } else {
                                    isPlaying = true
                                }
                            }
                        }
                        break
                    }
                }
            }
        }

        let parsed = parseMediaTitleAndArtist(from: rawName)
        let now = Date()

        if parsed.title != iinaActiveTitle {
            iinaActiveTitle = parsed.title
            iinaPlaybackElapsed = 0.0
            iinaLastTick = now
        } else {
            if isPlaying {
                let dt = now.timeIntervalSince(iinaLastTick)
                iinaPlaybackElapsed += max(0.0, dt)
            }
            iinaLastTick = now
        }

        return NowPlayingTrack(
            title: parsed.title,
            artist: parsed.artist,
            album: "IINA Media",
            duration: nil,
            elapsedTime: iinaPlaybackElapsed,
            isPlaying: isPlaying,
            source: .iina,
            isAdvertisement: false
        )
    }

    // MARK: - Media Filename & Title Sanitization

    private func parseMediaTitleAndArtist(from rawFilename: String) -> (title: String, artist: String) {
        var clean = rawFilename

        // 1. Strip file extensions
        let extensions = [
            "\\.mp4", "\\.mkv", "\\.mov", "\\.avi", "\\.mp3", "\\.m4a", "\\.flac",
            "\\.wav", "\\.webm", "\\.aac", "\\.ogg", "\\.opus", "\\.wmv", "\\.m4v", "\\.3gp", "\\.ts"
        ]
        for ext in extensions {
            clean = clean.replacingOccurrences(of: ext + "$", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // 2. Remove resolution, codec, and video tags in parentheses/brackets
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
            "\\s*\\(.*remaster.*\\)",
            "\\s*\\[.*remaster.*\\]",
            "\\s*\\(.*deluxe.*\\)",
            "\\s*\\[.*deluxe.*\\]",
            "\\s*\\(.*edition.*\\)",
            "\\s*\\(.*live.*\\)",
            "\\s*-\\s*live.*",
            "\\s*-\\s*remastered.*",
            "\\s*\\(feat\\..*\\)",
            "\\s*\\[feat\\..*\\]",
            "\\s*ft\\..*",
            "\\(\\s*\\)", "\\[\\s*\\]"
        ]

        for pattern in noisePatterns {
            clean = clean.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize separators
        clean = clean.replacingOccurrences(of: " – ", with: " - ")
                     .replacingOccurrences(of: " — ", with: " - ")
                     .replacingOccurrences(of: " | ", with: " - ")

        var parts = clean.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        // If there are extra parts like uploader name at the end (e.g. "Merry Christmas - Bleachers - hanhan"), take the first 2 parts
        if parts.count > 2 {
            parts = Array(parts.prefix(2))
        }

        if parts.count == 2 {
            let part0 = parts[0]
            let part1 = parts[1]
            return (title: part1, artist: part0)
        } else if parts.count == 1 {
            return (title: parts[0], artist: "")
        }

        return (title: clean, artist: "")
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            _ = runAppleScript("tell application \"Spotify\" to playpause", appName: "Spotify")
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            _ = runAppleScript("tell application \"Music\" to playpause", appName: "Apple Music")
        } else if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") {
            let script = """
            tell application "QuickTime Player"
                if (count of documents) > 0 then
                    set doc to front document
                    if playing of doc then
                        pause doc
                    else
                        play doc
                    end if
                end if
            end tell
            """
            _ = runAppleScript(script, appName: "QuickTime Player")
        } else if isAppRunning(bundleIdentifier: "org.videolan.vlc") {
            _ = runAppleScript("tell application \"VLC\" to play", appName: "VLC")
        } else if isAppRunning(bundleIdentifier: "com.colliderli.iina") {
            let script = """
            tell application "System Events"
                tell process "IINA"
                    keystroke space
                end tell
            end tell
            """
            _ = runAppleScript(script, appName: "IINA")
        }
    }

    func seek(to position: TimeInterval) {
        let posStr = String(format: "%.2f", position)
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(posStr)", appName: "Spotify")
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            _ = runAppleScript("tell application \"Music\" to set player position to \(posStr)", appName: "Apple Music")
        } else if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") {
            _ = runAppleScript("tell application \"QuickTime Player\" to if (count of documents) > 0 then set current time of front document to \(posStr)", appName: "QuickTime Player")
        } else if isAppRunning(bundleIdentifier: "org.videolan.vlc") {
            let intPos = Int(position)
            _ = runAppleScript("tell application \"VLC\" to set current time to \(intPos)", appName: "VLC")
        } else if isAppRunning(bundleIdentifier: "com.colliderli.iina") {
            iinaPlaybackElapsed = position
            iinaLastTick = Date()
        }
    }

    func nextTrack() {
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            _ = runAppleScript("tell application \"Spotify\" to next track", appName: "Spotify")
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            _ = runAppleScript("tell application \"Music\" to next track", appName: "Apple Music")
        } else if isAppRunning(bundleIdentifier: "org.videolan.vlc") {
            _ = runAppleScript("tell application \"VLC\" to next", appName: "VLC")
        } else if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") {
            _ = runAppleScript("tell application \"QuickTime Player\" to if (count of documents) > 0 then step forward front document", appName: "QuickTime Player")
        }
    }

    func previousTrack() {
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            _ = runAppleScript("tell application \"Spotify\" to previous track", appName: "Spotify")
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            _ = runAppleScript("tell application \"Music\" to previous track", appName: "Apple Music")
        } else if isAppRunning(bundleIdentifier: "org.videolan.vlc") {
            _ = runAppleScript("tell application \"VLC\" to previous", appName: "VLC")
        } else if isAppRunning(bundleIdentifier: "com.apple.QuickTimePlayerX") {
            _ = runAppleScript("tell application \"QuickTime Player\" to if (count of documents) > 0 then step backward front document", appName: "QuickTime Player")
        }
    }

    @discardableResult
    func toggleLikeTrack() -> Bool {
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            let script = """
            tell application "System Events"
                tell process "Spotify"
                    keystroke "b" using {option down, shift down}
                end tell
            end tell
            """
            _ = runAppleScript(script, appName: "Spotify")
            return true
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            let script = """
            tell application "Music"
                try
                    set favorited of current track to not (favorited of current track)
                    return favorited of current track as string
                end try
            end tell
            """
            let res = runAppleScript(script, appName: "Apple Music")
            return res?.lowercased() == "true"
        }
        return false
    }

    func adjustSystemVolume(by delta: Float) -> Int {
        let deltaInt = Int(delta * 100)
        let script = """
        set currentVol to output volume of (get volume settings)
        set newVol to currentVol + (\(deltaInt))
        if newVol > 100 then set newVol to 100
        if newVol < 0 then set newVol to 0
        set volume output volume newVol
        return newVol as string
        """
        if let res = runAppleScript(script, appName: "System") {
            return Int(res) ?? 50
        }
        return 50
    }

    // MARK: - App-Specific Sound Volume Controls (for Auto Mute / Dim during Ads)

    func getAppVolume() -> Int? {
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            let script = "tell application \"Spotify\" to get sound volume"
            if let res = runAppleScript(script, appName: "Spotify"), let vol = Int(res) {
                return vol
            }
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            let script = "tell application \"Music\" to get sound volume"
            if let res = runAppleScript(script, appName: "Music"), let vol = Int(res) {
                return vol
            }
        }
        return nil
    }

    func setAppVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        if isAppRunning(bundleIdentifier: "com.spotify.client") {
            _ = runAppleScript("tell application \"Spotify\" to set sound volume to \(clamped)", appName: "Spotify")
        } else if isAppRunning(bundleIdentifier: "com.apple.Music") {
            _ = runAppleScript("tell application \"Music\" to set sound volume to \(clamped)", appName: "Music")
        }
    }

    func smoothFadeAppVolume(from start: Int, to end: Int, steps: Int = 6, duration: TimeInterval = 0.35) {
        guard start != end else { return }
        let stepInterval = duration / Double(steps)
        let stepDelta = Double(end - start) / Double(steps)

        for i in 1...steps {
            let targetVol = Int(Double(start) + (stepDelta * Double(i)))
            DispatchQueue.main.asyncAfter(deadline: .now() + (stepInterval * Double(i))) { [weak self] in
                self?.setAppVolume(targetVol)
            }
        }
    }

    // MARK: - Script execution

    private func runAppleScript(_ source: String, appName: String) -> String? {
        let appleScript = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNumber == -1743 {
                let current = consecutiveDenials[appName] ?? 0
                let next = current + 1
                consecutiveDenials[appName] = next

                if next == 1 && !subprocessTriggered.contains(appName) {
                    subprocessTriggered.insert(appName)
                    triggerDialogViaSubprocess(for: appName)
                }

                if next < maxConsecutiveDenialsBeforeAlert {
                    NSLog("[AppleScriptBackend] Permission denied (-1743) for \(appName) — retry \(next)/\(maxConsecutiveDenialsBeforeAlert)")
                } else if next == maxConsecutiveDenialsBeforeAlert {
                    NSLog("[AppleScriptBackend] ⚠️ PERSISTENT DENIAL for \(appName) after \(next) attempts.")
                    DispatchQueue.main.async { [weak self] in
                        self?.onPermissionDenied?(appName)
                    }
                }
            } else if errorNumber != -128 && errorNumber != -1728 {
                NSLog("[AppleScriptBackend] Script error \(errorNumber): \(error[NSAppleScript.errorMessage] as? String ?? "unknown")")
            }
            return nil
        }

        if consecutiveDenials[appName] != nil {
            consecutiveDenials.removeValue(forKey: appName)
            subprocessTriggered.remove(appName)
        }

        return result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Subprocess dialog trigger

    private func triggerDialogViaSubprocess(for appName: String) {
        let script: String
        switch appName {
        case "Spotify":
            script = "tell application \"Spotify\" to get player state"
        case "Apple Music":
            script = "tell application \"Music\" to get player state"
        case "QuickTime Player":
            script = "tell application \"QuickTime Player\" to get name of front document"
        case "VLC":
            script = "tell application \"VLC\" to get name of current item"
        default:
            script = "tell application \"Music\" to get player state"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                NSLog("[AppleScriptBackend] Failed to spawn subprocess for \(appName): \(error.localizedDescription)")
            }
        }
    }
}
