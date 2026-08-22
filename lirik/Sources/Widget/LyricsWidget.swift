//
//  LyricsWidget.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import QuartzCore
import PockKit

/// UI Display State for the Lyrics Touch Bar widget.
enum LyricsWidgetUIState: Equatable {
    case noTrackPlaying
    case permissionDenied(appName: String)
    case advertisement(title: String, adIndex: Int)
    case loading(title: String, artist: String)
    case noLyricsFound(title: String, artist: String)
    case staticOnly(title: String, artist: String, text: String)
    case synced(title: String, artist: String, lines: [LRCLine])
}

class LyricsWidget: NSObject, PKWidget {

    // MARK: - PKWidget Protocol Properties

    static var identifier: String = "io.github.ridhaaf.lirik"
    var customizationLabel: String = "Lirik - Synced Lyrics"
    var view: NSView!

    var imageForCustomization: NSImage {
        let size = NSSize(width: 60, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        if let rawIcon = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let tintedIcon = NSImage(size: NSSize(width: 16, height: 16))
            tintedIcon.lockFocus()
            NSColor.labelColor.set()
            NSRect(x: 0, y: 0, width: 16, height: 16).fill()
            rawIcon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16), from: .zero, operation: .destinationIn, fraction: 1.0)
            tintedIcon.unlockFocus()

            tintedIcon.draw(in: NSRect(x: 0, y: 2, width: 16, height: 16))
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        NSString("Lirik").draw(at: NSPoint(x: 20, y: 2), withAttributes: attrs)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - PKWidgetPreference link for Pock Widgets Manager

    @objc var hasPreferencesView: Bool { return true }
    @objc var preferenceClass: PKWidgetPreference.Type? { return LirikPreferenceViewController.self }
    @objc var preferenceView: PKWidgetPreference? { return LirikPreferenceViewController() }
    @objc var preferences: PKWidgetPreference? { return LirikPreferenceViewController() }

    // MARK: - UI Components

    private let containerView = NSStackView()
    private let contentStackView = NSStackView()
    private let textStackView = NSStackView()
    private let touchView = LirikTouchView()

    /// Progressive Apple Music Sing Karaoke View
    private let karaokeView = KaraokeLyricView()
    private let nextLineLabel = NSTextField(labelWithString: "")

    /// 1-Tap Like Heart Button (Native SF Symbol)
    private let heartButton = PKButton(title: "", target: nil, action: nil)
    private var isHeartLiked: Bool = false

    /// Album cover art thumbnail & Canvas Looping Video wrapper
    private let albumArtButton = PKButton(title: "", target: nil, action: nil)
    private let albumArtImageView = NSImageView()
    private let videoView = LoopingVideoView()
    private var albumArtWidthConstraint: NSLayoutConstraint?
    private var albumArtHeightConstraint: NSLayoutConstraint?

    /// Animated Equalizer visualizer bars
    private let equalizerView = EqualizerVisualizerView()

    /// Feature 7: Live Vocal Pitch & Melody Meter
    private let pitchMelodyVisualizer = PitchMelodyVisualizerView()

    /// Dynamic color extracted from album artwork
    private var dynamicArtworkColor: NSColor? = nil

    /// High-frequency 30 FPS progressive karaoke timer
    private var karaokeSmoothTimer: Timer?
    private var lastPlaybackTimestamp: Date = Date()
    private var lastKnownElapsed: TimeInterval = 0
    private var currentLineStartTimestamp: TimeInterval = 0
    private var currentLineEndTimestamp: TimeInterval = 0
    private var currentLineWords: [LRCWord] = []
    private var currentPreviousLineText: String = ""
    private var loadedArtworkImage: NSImage? = nil

    /// Track info display
    private var trackInfoVisibleUntil: Date?

    /// Swipe-to-Seek scrubbing state
    private var isScrubbing: Bool = false
    private var scrubStartElapsed: TimeInterval = 0
    private var scrubTargetTime: TimeInterval = 0
    private var lastScrubIndex: Int = -1

    /// Spotify Advertisement Tracker
    private var consecutiveAdIndex: Int = 0
    private var isCurrentlyInAdBreak: Bool = false
    private var lastAdTrackID: String = ""
    private var preAdAppVolume: Int? = nil
    private var isAdVolumeSilenced: Bool = false

    // MARK: - Logic Dependencies

    private let nowPlayingWatcher = NowPlayingWatcher()
    private let lrclibClient = LRCLIBClient()
    private let lyricsCache = LyricsCache()
    private let offlineVault = OfflineLyricsVault.shared
    private let albumArtService = AlbumArtService()
    private let canvasVideoService = CanvasVideoService()

    // MARK: - Widget State

    private var activeTrackKey: String = ""
    private var currentTrackOffset: Double = 0.0
    private var inFlightFetchTask: Task<Void, Never>?
    private var inFlightCanvasTask: Task<Void, Never>?
    private var lastCurrentVideoURL: URL? = nil

    private var uiState: LyricsWidgetUIState = .noTrackPlaying {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateUI()
            }
        }
    }

    private var activeLines: [LRCLine] = []
    private var isCurrentlyPaused: Bool = false

    // MARK: - Init

    required override init() {
        super.init()
        setupUI()
        setupWatcherCallbacks()
        observePreferenceChanges()
        nowPlayingWatcher.startWatching()
        startSmoothKaraokeTimer()
    }

    // MARK: - PKWidget Lifecycle Hooks

    func viewAppeared() {
        NSLog("[LyricsWidget] viewAppeared — starting NowPlayingWatcher")
        nowPlayingWatcher.startWatching()
        startSmoothKaraokeTimer()
    }

    func viewDisappeared() {
        NSLog("[LyricsWidget] viewDisappeared — stopping NowPlayingWatcher")
        inFlightFetchTask?.cancel()
        inFlightCanvasTask?.cancel()
        stopSmoothKaraokeTimer()
        nowPlayingWatcher.stopWatching()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Album art image view
        albumArtImageView.imageScaling = .scaleProportionallyUpOrDown
        albumArtImageView.wantsLayer = true
        albumArtImageView.layer?.cornerRadius = 4
        albumArtImageView.layer?.masksToBounds = true
        albumArtImageView.setContentHuggingPriority(.required, for: .horizontal)
        albumArtImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Video View (Spotify Canvas)
        videoView.wantsLayer = true
        videoView.layer?.cornerRadius = 4
        videoView.layer?.masksToBounds = true
        videoView.isHidden = true

        // Album art button wrapper
        albumArtButton.target = self
        albumArtButton.action = #selector(handleAlbumArtTap)
        albumArtButton.isBordered = false
        albumArtButton.addSubview(albumArtImageView)
        albumArtButton.addSubview(videoView)

        albumArtImageView.translatesAutoresizingMaskIntoConstraints = false
        videoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumArtImageView.leadingAnchor.constraint(equalTo: albumArtButton.leadingAnchor),
            albumArtImageView.trailingAnchor.constraint(equalTo: albumArtButton.trailingAnchor),
            albumArtImageView.topAnchor.constraint(equalTo: albumArtButton.topAnchor),
            albumArtImageView.bottomAnchor.constraint(equalTo: albumArtButton.bottomAnchor),

            videoView.leadingAnchor.constraint(equalTo: albumArtButton.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: albumArtButton.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: albumArtButton.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: albumArtButton.bottomAnchor)
        ])

        albumArtWidthConstraint = albumArtButton.widthAnchor.constraint(equalToConstant: 24)
        albumArtHeightConstraint = albumArtButton.heightAnchor.constraint(equalToConstant: 24)
        albumArtWidthConstraint?.isActive = true
        albumArtHeightConstraint?.isActive = true
        albumArtButton.isHidden = true

        // 1-Tap Like Heart Button (Native SF Symbol)
        heartButton.target = self
        heartButton.action = #selector(handleHeartTap)
        heartButton.isBordered = false
        updateHeartButtonIcon(isLiked: false)
        heartButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        heartButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
        heartButton.isHidden = false

        // Equalizer View
        equalizerView.setContentHuggingPriority(.required, for: .horizontal)
        equalizerView.setContentCompressionResistancePriority(.required, for: .horizontal)
        equalizerView.isHidden = false

        // Feature 7: Pitch & Melody Visualizer
        pitchMelodyVisualizer.setContentHuggingPriority(.required, for: .horizontal)
        pitchMelodyVisualizer.setContentCompressionResistancePriority(.required, for: .horizontal)
        let showPitch = UserDefaults.standard.object(forKey: LirikPreferenceViewController.keyShowPitchVisualizer) as? Bool ?? true
        pitchMelodyVisualizer.isHidden = !showPitch

        // Container stack view
        containerView.orientation = .horizontal
        containerView.alignment = .centerY
        containerView.distribution = .fill
        containerView.spacing = 5
        containerView.edgeInsets = NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 4)

        // Content stack view
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.distribution = .fill
        contentStackView.spacing = 1

        // Text stack view
        textStackView.orientation = .vertical
        textStackView.alignment = .leading
        textStackView.distribution = .fillProportionally
        textStackView.spacing = 0

        // Apple Music Sing Karaoke View
        karaokeView.font = NSFont.boldSystemFont(ofSize: 11)
        karaokeView.activeColor = .white
        karaokeView.text = "Lirik"
        karaokeView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        karaokeView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Next line label
        nextLineLabel.font = NSFont.systemFont(ofSize: 9)
        nextLineLabel.wantsLayer = true
        nextLineLabel.textColor = .secondaryLabelColor
        nextLineLabel.lineBreakMode = .byTruncatingTail
        nextLineLabel.stringValue = ""
        nextLineLabel.isEditable = false
        nextLineLabel.isSelectable = false
        nextLineLabel.isBezeled = false
        nextLineLabel.drawsBackground = false

        textStackView.addArrangedSubview(karaokeView)
        textStackView.addArrangedSubview(nextLineLabel)

        contentStackView.addArrangedSubview(textStackView)

        // Configure touchView
        touchView.addSubview(contentStackView)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: touchView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: touchView.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: touchView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: touchView.bottomAnchor)
        ])

        setupTouchViewCallbacks()

        containerView.addArrangedSubview(albumArtButton)
        containerView.addArrangedSubview(heartButton)
        containerView.addArrangedSubview(equalizerView)
        containerView.addArrangedSubview(pitchMelodyVisualizer)
        containerView.addArrangedSubview(touchView)

        // Minimum width constraint
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true

        self.view = containerView
    }

    private func updateHeartButtonIcon(isLiked: Bool) {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let symbolName = isLiked ? "heart.fill" : "heart"
        if let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Like")?.withSymbolConfiguration(config) {
            heartButton.image = icon
            heartButton.title = ""
            heartButton.contentTintColor = isLiked ? NSColor(red: 1.0, green: 0.32, blue: 0.45, alpha: 1.0) : .secondaryLabelColor
        }
    }

    // MARK: - High-Frequency Smooth Karaoke Progress Timer (30 FPS)

    private func startSmoothKaraokeTimer() {
        stopSmoothKaraokeTimer()
        karaokeSmoothTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tickKaraokeProgress()
            }
        }
    }

    private func stopSmoothKaraokeTimer() {
        karaokeSmoothTimer?.invalidate()
        karaokeSmoothTimer = nil
    }

    private func calculateNaturalProgress(
        elapsed: TimeInterval,
        lineStart: TimeInterval,
        lineEnd: TimeInterval,
        lineText: String,
        explicitWords: [LRCWord]
    ) -> Double {
        guard lineEnd > lineStart else { return 1.0 }
        if elapsed <= lineStart { return 0.0 }

        let totalLineDuration = lineEnd - lineStart

        // 1. Enhanced LRC with explicit word/syllable timestamps
        if !explicitWords.isEmpty {
            let activeWordIndex = explicitWords.lastIndex(where: { elapsed >= $0.timestamp }) ?? 0
            let totalWords = Double(explicitWords.count)
            let baseFraction = Double(activeWordIndex) / totalWords

            let currentWordStart = explicitWords[activeWordIndex].timestamp
            let nextWordStart = (activeWordIndex + 1 < explicitWords.count)
                ? explicitWords[activeWordIndex + 1].timestamp
                : lineEnd
            let wordDuration = max(0.15, nextWordStart - currentWordStart)
            let rawWordFraction = min(1.0, max(0.0, (elapsed - currentWordStart) / wordDuration))

            // Smooth cosine S-curve easing on individual word fill
            let easedWordFraction = (1.0 - cos(rawWordFraction * .pi)) / 2.0
            return max(0.0, min(1.0, baseFraction + (easedWordFraction / totalWords)))
        }

        // 2. Standard LRC: Apple Music Natural Vocal Cadence Model
        // The singing portion occupies the first 82-88% of line interval, leaving natural breath pause before next line
        let breathDuration = min(0.65, max(0.2, totalLineDuration * 0.15))
        let vocalDuration = max(0.3, totalLineDuration - breathDuration)

        let timeIntoLine = elapsed - lineStart
        if timeIntoLine >= vocalDuration {
            return 1.0 // Fully highlighted during musical breath before next line
        }

        let rawLinearFraction = timeIntoLine / vocalDuration

        // Syllable/word-weighted progressive fill
        let words = lineText.components(separatedBy: " ").filter { !$0.isEmpty }
        if words.count > 1 {
            let totalChars = max(1, words.reduce(0) { $0 + $1.count })
            var cumulativeWeights: [Double] = []
            var runningCharCount = 0
            for word in words {
                runningCharCount += word.count
                cumulativeWeights.append(Double(runningCharCount) / Double(totalChars))
            }

            var activeIdx = 0
            while activeIdx < cumulativeWeights.count - 1 && rawLinearFraction > cumulativeWeights[activeIdx] {
                activeIdx += 1
            }

            let prevWeight = activeIdx > 0 ? cumulativeWeights[activeIdx - 1] : 0.0
            let currentWeight = cumulativeWeights[activeIdx]
            let wordSpan = max(0.01, currentWeight - prevWeight)
            let subFraction = max(0.0, min(1.0, (rawLinearFraction - prevWeight) / wordSpan))

            let easedSub = (1.0 - cos(subFraction * .pi)) / 2.0
            let interpolated = prevWeight + (easedSub * wordSpan)
            return max(0.0, min(1.0, interpolated))
        } else {
            let eased = (1.0 - cos(rawLinearFraction * .pi)) / 2.0
            return max(0.0, min(1.0, eased))
        }
    }

    private func tickKaraokeProgress() {
        guard !isCurrentlyPaused, !isScrubbing, !activeLines.isEmpty else { return }

        let now = Date()
        let elapsedDelta = now.timeIntervalSince(lastPlaybackTimestamp)
        let effectiveElapsed = max(0.0, lastKnownElapsed + elapsedDelta + currentTrackOffset)

        // 1. Guard against Intro Phase (before the first line starts singing)
        if let firstLine = activeLines.first, effectiveElapsed < firstLine.timestamp {
            karaokeView.progress = 0.0
            pitchMelodyVisualizer.setPlaying(false)
            return
        }

        // 2. Guard against gap between line start
        if effectiveElapsed < currentLineStartTimestamp {
            karaokeView.progress = 0.0
            pitchMelodyVisualizer.setPlaying(false)
            return
        }

        let progress = calculateNaturalProgress(
            elapsed: effectiveElapsed,
            lineStart: currentLineStartTimestamp,
            lineEnd: currentLineEndTimestamp,
            lineText: karaokeView.text,
            explicitWords: currentLineWords
        )

        karaokeView.progress = CGFloat(progress)
        pitchMelodyVisualizer.setPlaying(true)

        // Update HUD & Ambient with live smooth progress
        if let track = nowPlayingWatcher.currentTrack {
            let totalDuration = track.duration ?? 180.0
            let totalFraction = totalDuration > 0 ? (effectiveElapsed / totalDuration) : 0.0
            FloatingLyricsHUD.shared.update(
                current: karaokeView.text,
                next: nextLineLabel.stringValue,
                title: track.title,
                artist: track.artist,
                progress: totalFraction,
                lineProgress: progress,
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: karaokeView.activeColor,
                isPlaying: true
            )

            AmbientLyricsWindow.shared.update(
                current: karaokeView.text,
                next: nextLineLabel.stringValue,
                previous: currentPreviousLineText,
                title: track.title,
                artist: track.artist,
                progress: totalFraction,
                lineProgress: progress,
                timeFormatted: "\(formatTime(effectiveElapsed)) / \(formatTime(totalDuration))",
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: karaokeView.activeColor,
                videoURL: lastCurrentVideoURL,
                isPlaying: true
            )
        }
    }

    // MARK: - Touch Callbacks (Single Tap, Double Tap, Long Press, Pan Seek, 2-Finger Gestures)

    private func setupTouchViewCallbacks() {
        touchView.onSingleTap = { [weak self] in
            self?.handleSingleTap()
        }

        touchView.onDoubleTap = { [weak self] in
            self?.handleDoubleTap()
        }

        touchView.onLongPress = { [weak self] in
            self?.handleLongPressQuote()
        }

        // 2-Finger Horizontal Swipe -> Next / Prev Track
        touchView.onTwoFingerSwipeHorizontal = { [weak self] dx in
            guard let self, UserDefaults.standard.object(forKey: LirikPreferenceViewController.keyEnableGestures) as? Bool ?? true else { return }
            if dx < -25 {
                self.triggerHapticFeedback()
                self.nowPlayingWatcher.nextTrack()
                self.flashFeedbackText("Next Track")
            } else if dx > 25 {
                self.triggerHapticFeedback()
                self.nowPlayingWatcher.previousTrack()
                self.flashFeedbackText("Previous Track")
            }
        }

        // 2-Finger Vertical Swipe -> Volume Adjust
        touchView.onTwoFingerSwipeVertical = { [weak self] dy in
            guard let self, UserDefaults.standard.object(forKey: LirikPreferenceViewController.keyEnableGestures) as? Bool ?? true else { return }
            let delta = Float(dy) * 0.003
            let newVol = self.nowPlayingWatcher.adjustSystemVolume(by: delta)
            self.flashFeedbackText("Volume: \(newVol)%")
        }

        touchView.onPanBegan = { [weak self] _ in
            guard let self = self,
                  let track = self.nowPlayingWatcher.currentTrack,
                  !track.isAdvertisement,
                  let duration = track.duration, duration > 0 else { return }
            self.isScrubbing = true
            self.scrubStartElapsed = track.elapsedTime ?? 0
            self.scrubTargetTime = self.scrubStartElapsed
            self.lastScrubIndex = -1
            self.triggerHapticFeedback()
        }

        touchView.onPanChanged = { [weak self] dx in
            guard let self = self,
                  let track = self.nowPlayingWatcher.currentTrack,
                  !track.isAdvertisement,
                  let duration = track.duration, duration > 0 else { return }

            let deltaSeconds = Double(dx) * 0.4
            self.scrubTargetTime = max(0, min(self.scrubStartElapsed + deltaSeconds, duration))

            let formattedTime = self.formatTime(self.scrubTargetTime)
            let formattedTotal = self.formatTime(duration)

            if !self.activeLines.isEmpty {
                let snapshot = LRCSyncEngine.resolve(elapsedTime: self.scrubTargetTime, lines: self.activeLines)
                let previewText = snapshot.currentLine?.text ?? snapshot.upcomingLine?.text ?? "..."
                self.karaokeView.text = "[\(formattedTime) / \(formattedTotal)] \(previewText)"
                self.karaokeView.progress = 1.0
                self.nextLineLabel.stringValue = "Release to jump to timestamp"

                if let idx = snapshot.currentIndex, idx != self.lastScrubIndex {
                    self.lastScrubIndex = idx
                    self.triggerHapticFeedback()
                }
            } else {
                self.karaokeView.text = "Seeking to \(formattedTime) / \(formattedTotal)"
                self.nextLineLabel.stringValue = "Release to jump"
            }
        }

        touchView.onPanEnded = { [weak self] _ in
            guard let self = self else { return }
            self.isScrubbing = false
            self.triggerHapticFeedback()
            self.nowPlayingWatcher.seek(to: self.scrubTargetTime)

            // Resume display
            if case .synced(_, _, let lines) = self.uiState {
                let snapshot = LRCSyncEngine.resolve(elapsedTime: self.scrubTargetTime, lines: lines)
                self.renderSyncSnapshot(snapshot, elapsed: self.scrubTargetTime, isPaused: self.isCurrentlyPaused)
            }
        }

        touchView.onPanCancelled = { [weak self] in
            guard let self = self else { return }
            self.isScrubbing = false
            if case .synced(_, _, let lines) = self.uiState {
                let elapsed = self.nowPlayingWatcher.currentTrack?.elapsedTime ?? 0
                let snapshot = LRCSyncEngine.resolve(elapsedTime: elapsed, lines: lines)
                self.renderSyncSnapshot(snapshot, elapsed: elapsed, isPaused: self.isCurrentlyPaused)
            }
        }
    }

    @objc private func handleAlbumArtTap() {
        triggerHapticFeedback()
        FloatingLyricsHUD.shared.toggleHUD()
    }

    @objc private func handleHeartTap() {
        triggerHapticFeedback()
        isHeartLiked.toggle()
        updateHeartButtonIcon(isLiked: isHeartLiked)
        nowPlayingWatcher.toggleLikeTrack()
        flashFeedbackText(isHeartLiked ? "Added to Liked Songs" : "Removed from Liked Songs")
    }

    private func handleDoubleTap() {
        triggerHapticFeedback()
        nowPlayingWatcher.togglePlayPause()
    }

    private func handleLongPressQuote() {
        guard let track = nowPlayingWatcher.currentTrack, !track.isAdvertisement else { return }
        triggerHapticFeedback()

        let quoteText = karaokeView.text
        if QuoteCardGenerator.generateAndCopy(
            title: track.title,
            artist: track.artist,
            lyricQuote: quoteText,
            artwork: loadedArtworkImage ?? albumArtImageView.image,
            highlightColor: resolveHighlightColor(isPaused: false)
        ) != nil {
            flashFeedbackText("Quote Card Saved")
        }
    }

    private func handleSingleTap() {
        guard !isScrubbing else { return }

        let textToCopy = karaokeView.text.replacingOccurrences(of: "❙❙ ", with: "").replacingOccurrences(of: "⏸ ", with: "").trimmingCharacters(in: .whitespaces)
        guard !textToCopy.isEmpty,
              textToCopy != "Lirik",
              textToCopy != "Fetching lyrics...",
              textToCopy != "No track playing",
              textToCopy != "No lyrics available",
              !textToCopy.starts(with: "Spotify Ad"),
              !textToCopy.starts(with: "Volume:"),
              !textToCopy.starts(with: "Added to"),
              !textToCopy.starts(with: "Removed from"),
              !textToCopy.starts(with: "Quote Card"),
              textToCopy != "Copied to Clipboard" else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)

        triggerHapticFeedback()
        flashFeedbackText("Copied to Clipboard")
    }

    private func flashFeedbackText(_ message: String) {
        let previousText = karaokeView.text
        karaokeView.text = message
        karaokeView.progress = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            if self.karaokeView.text == message {
                self.karaokeView.text = previousText
            }
        }
    }

    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Watcher Callbacks

    private func setupWatcherCallbacks() {
        MenuBarLyricsController.shared.onPlayPause = { [weak self] in
            self?.nowPlayingWatcher.togglePlayPause()
        }
        MenuBarLyricsController.shared.onNextTrack = { [weak self] in
            self?.nowPlayingWatcher.nextTrack()
        }
        MenuBarLyricsController.shared.onPreviousTrack = { [weak self] in
            self?.nowPlayingWatcher.previousTrack()
        }
        MenuBarLyricsController.shared.onOffsetAdjusted = { [weak self] delta in
            guard let self = self else { return }
            if delta == 0.0 {
                self.currentTrackOffset = 0.0
                if !self.activeTrackKey.isEmpty {
                    self.offlineVault.setOffset(0.0, for: self.activeTrackKey)
                }
                self.flashFeedbackText("Timing Offset: Reset (0.0s)")
            } else {
                self.currentTrackOffset = ((self.currentTrackOffset + delta) * 100).rounded() / 100
                if !self.activeTrackKey.isEmpty {
                    self.offlineVault.setOffset(self.currentTrackOffset, for: self.activeTrackKey)
                }
                let formatted = String(format: "%+.1fs", self.currentTrackOffset)
                self.flashFeedbackText("Timing Offset: \(formatted)")
            }
        }

        nowPlayingWatcher.onPermissionDenied = { [weak self] appName in
            self?.uiState = .permissionDenied(appName: appName)
        }

        nowPlayingWatcher.onTrackChange = { [weak self] track in
            guard let self else { return }

            self.inFlightFetchTask?.cancel()
            self.inFlightCanvasTask?.cancel()

            if let track = track {
                self.isCurrentlyPaused = !track.isPlaying

                if track.isAdvertisement {
                    if !self.isCurrentlyInAdBreak {
                        self.isCurrentlyInAdBreak = true
                        self.consecutiveAdIndex = 1
                    } else if self.lastAdTrackID != (track.trackID ?? track.title) {
                        self.consecutiveAdIndex += 1
                    }
                    self.lastAdTrackID = track.trackID ?? track.title

                    // Auto Mute / Auto Dim on Ad Break Start
                    let adAudioPref = UserDefaults.standard.string(forKey: LirikPreferenceViewController.keyAdAudioBehavior) ?? "dim"
                    if adAudioPref != "none" && !self.isAdVolumeSilenced {
                        let currentVol = self.nowPlayingWatcher.getAppVolume() ?? 80
                        self.preAdAppVolume = currentVol
                        self.isAdVolumeSilenced = true
                        let targetVol = (adAudioPref == "mute") ? 0 : 10
                        self.nowPlayingWatcher.smoothFadeAppVolume(from: currentVol, to: targetVol, duration: 0.35)
                    }

                    self.activeTrackKey = ""
                    self.activeLines = []
                    self.currentLineWords = []
                    self.dynamicArtworkColor = nil
                    self.lastCurrentVideoURL = nil
                    self.loadedArtworkImage = nil
                    self.videoView.clear()
                    self.videoView.isHidden = true
                    self.albumArtImageView.isHidden = false
                    FloatingLyricsHUD.shared.setVideoURL(nil)
                    self.uiState = .advertisement(title: track.title, adIndex: self.consecutiveAdIndex)
                    return
                }

                // Restore sound volume if it was muted/dimmed during ad break
                if self.isAdVolumeSilenced {
                    let adAudioPref = UserDefaults.standard.string(forKey: LirikPreferenceViewController.keyAdAudioBehavior) ?? "dim"
                    let targetVol = self.preAdAppVolume ?? 80
                    let currentVol = (adAudioPref == "mute") ? 0 : 10
                    self.nowPlayingWatcher.smoothFadeAppVolume(from: currentVol, to: targetVol, duration: 0.45)
                    self.isAdVolumeSilenced = false
                    self.preAdAppVolume = nil
                    self.flashFeedbackText("Volume Restored: \(targetVol)%")
                }

                // Regular music track
                self.isCurrentlyInAdBreak = false
                self.consecutiveAdIndex = 0
                self.lastAdTrackID = ""
                self.lastCurrentVideoURL = nil
                self.loadedArtworkImage = nil
                self.videoView.clear()
                self.videoView.isHidden = true
                self.albumArtImageView.isHidden = false
                FloatingLyricsHUD.shared.setVideoURL(nil)

                let newKey = LyricsCache.makeTrackKey(title: track.title, artist: track.artist, duration: track.duration)
                self.activeTrackKey = newKey

                // Smooth push transition animation for new track
                let transition = CATransition()
                transition.type = .push
                transition.subtype = .fromRight
                transition.duration = 0.35
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.textStackView.layer?.add(transition, forKey: "trackTransition")

                let defaults = UserDefaults.standard
                let showTrackInfo = defaults.object(forKey: LirikPreferenceViewController.keyShowTrackInfo) as? Bool ?? false
                let enableUpNext = defaults.object(forKey: LirikPreferenceViewController.keyEnableUpNextCountdown) as? Bool ?? true
                if showTrackInfo || enableUpNext {
                    self.trackInfoVisibleUntil = Date().addingTimeInterval(3.0)
                }

                self.loadLyrics(for: track, expectedKey: newKey, forceRefresh: false)
                self.fetchAlbumArt(for: track)
                self.fetchCanvasVideo(for: track)

                // Schedule follow-up check for Spotify Canvas
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self, let current = self.nowPlayingWatcher.currentTrack, current.isSameTrack(as: track) else { return }
                    if !self.videoView.hasVideo {
                        self.fetchCanvasVideo(for: current)
                    }
                }
            } else {
                self.activeTrackKey = ""
                self.activeLines = []
                self.currentLineWords = []
                self.dynamicArtworkColor = nil
                self.lastCurrentVideoURL = nil
                self.loadedArtworkImage = nil
                self.isCurrentlyPaused = false
                self.isCurrentlyInAdBreak = false
                self.consecutiveAdIndex = 0
                self.lastAdTrackID = ""
                self.uiState = .noTrackPlaying
                self.videoView.clear()
                self.equalizerView.setPlaying(false)
                self.pitchMelodyVisualizer.setPlaying(false)
                FloatingLyricsHUD.shared.setVideoURL(nil)
                FloatingLyricsHUD.shared.update(current: "No track playing", next: "", title: "Lirik", artist: "", progress: 0, lineProgress: 0, artwork: nil, highlightColor: nil, isPlaying: false)
            }
        }

        nowPlayingWatcher.onElapsedTimeUpdate = { [weak self] elapsed in
            guard let self else { return }
            guard !self.isScrubbing else { return }
            guard let track = self.nowPlayingWatcher.currentTrack else { return }

            let now = Date()
            if !track.isPlaying || self.isCurrentlyPaused {
                self.lastKnownElapsed = elapsed
                self.lastPlaybackTimestamp = now
            } else {
                let currentExtrapolated = self.lastKnownElapsed + now.timeIntervalSince(self.lastPlaybackTimestamp)
                let diff = elapsed - currentExtrapolated

                // If gap is large (user seeked or track changed), snap immediately
                if abs(diff) > 1.25 || diff < -1.0 {
                    self.lastKnownElapsed = elapsed
                    self.lastPlaybackTimestamp = now
                } else {
                    // Smooth Phase-Locked Loop: gently nudge the anchor without jumping backwards or jerking
                    let adjusted = currentExtrapolated + (diff * 0.12)
                    self.lastKnownElapsed = adjusted
                    self.lastPlaybackTimestamp = now
                }
            }

            DispatchQueue.main.async {
                self.isCurrentlyPaused = !track.isPlaying

                if case .advertisement(_, let adIndex) = self.uiState {
                    self.renderAdvertisement(track: track, adIndex: adIndex)
                    return
                }

                self.equalizerView.setPlaying(track.isPlaying)
                self.pitchMelodyVisualizer.setPlaying(track.isPlaying)

                if track.isPlaying {
                    self.videoView.playVideo()
                } else {
                    self.videoView.pauseVideo()
                }

                let effectiveElapsed = max(0.0, self.lastKnownElapsed + self.currentTrackOffset)
                if case .synced(_, _, let lines) = self.uiState {
                    let snapshot = LRCSyncEngine.resolve(elapsedTime: effectiveElapsed, lines: lines)
                    self.renderSyncSnapshot(snapshot, elapsed: effectiveElapsed, isPaused: !track.isPlaying)
                } else if case .staticOnly(_, _, let text) = self.uiState {
                    self.renderStaticLyrics(text, elapsed: effectiveElapsed, trackDuration: track.duration, isPaused: !track.isPlaying)
                }
            }
        }
    }

    // MARK: - Preference Change Observers

    private func observePreferenceChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAlbumArtPreferenceChanged),
            name: Notification.Name("io.github.ridhaaf.lirik.albumArtChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onEqualizerPreferenceChanged),
            name: Notification.Name("io.github.ridhaaf.lirik.equalizerChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPitchVisualizerPreferenceChanged),
            name: Notification.Name("io.github.ridhaaf.lirik.pitchVisualizerChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCanvasPreferenceChanged),
            name: Notification.Name("io.github.ridhaaf.lirik.canvasChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onHeartButtonPreferenceChanged),
            name: Notification.Name("io.github.ridhaaf.lirik.heartButtonChanged"),
            object: nil
        )
    }

    @objc private func onPitchVisualizerPreferenceChanged() {
        let defaults = UserDefaults.standard
        let showPitch = defaults.object(forKey: LirikPreferenceViewController.keyShowPitchVisualizer) as? Bool ?? true
        DispatchQueue.main.async { [weak self] in
            self?.pitchMelodyVisualizer.isHidden = !showPitch
        }
    }

    @objc private func onHeartButtonPreferenceChanged() {
        let defaults = UserDefaults.standard
        let showHeart = defaults.object(forKey: LirikPreferenceViewController.keyShowHeartButton) as? Bool ?? true
        DispatchQueue.main.async { [weak self] in
            self?.heartButton.isHidden = !showHeart
        }
    }

    @objc private func onEqualizerPreferenceChanged() {
        let defaults = UserDefaults.standard
        let showEq = defaults.object(forKey: LirikPreferenceViewController.keyShowEqualizer) as? Bool ?? true
        DispatchQueue.main.async { [weak self] in
            self?.equalizerView.isHidden = !showEq
        }
    }

    @objc private func onCanvasPreferenceChanged() {
        if let track = nowPlayingWatcher.currentTrack, !track.isAdvertisement {
            fetchCanvasVideo(for: track)
        }
    }

    @objc private func onAlbumArtPreferenceChanged() {
        let defaults = UserDefaults.standard
        let showArt = defaults.object(forKey: LirikPreferenceViewController.keyShowAlbumArt) as? Bool ?? true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if showArt {
                if let track = self.nowPlayingWatcher.currentTrack, !track.isAdvertisement {
                    self.fetchAlbumArt(for: track)
                }
            } else {
                self.albumArtButton.isHidden = true
            }
        }
    }

    // MARK: - Advertisement Rendering (Native SF Symbol)

    private func renderAdvertisement(track: NowPlayingTrack, adIndex: Int) {
        let duration = track.duration ?? 30.0
        let elapsed = track.elapsedTime ?? 0.0
        let remainingSeconds = max(0, Int(ceil(duration - elapsed)))

        let adAudioPref = UserDefaults.standard.string(forKey: LirikPreferenceViewController.keyAdAudioBehavior) ?? "dim"
        let volBadge: String
        switch adAudioPref {
        case "mute": volBadge = " • Muted"
        case "dim": volBadge = " • Dimmed"
        default: volBadge = ""
        }

        applyTextAlignment()
        karaokeView.font = NSFont.boldSystemFont(ofSize: 11)
        karaokeView.activeColor = NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
        let adText = "Spotify Ad (\(adIndex)) • \(remainingSeconds)s left\(volBadge)"
        karaokeView.text = adText
        karaokeView.progress = 1.0

        nextLineLabel.font = NSFont.systemFont(ofSize: 9)
        nextLineLabel.textColor = .secondaryLabelColor
        nextLineLabel.isHidden = false
        nextLineLabel.stringValue = "Next song will play shortly..."

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let adIcon = NSImage(systemSymbolName: "megaphone.fill", accessibilityDescription: "Ad")?.withSymbolConfiguration(config)
        albumArtImageView.image = adIcon
        albumArtButton.isHidden = false
        videoView.clear()
        equalizerView.setPlaying(false)
        pitchMelodyVisualizer.setPlaying(false)
        heartButton.isHidden = true

        let fraction = duration > 0 ? (elapsed / duration) : 0.0
        FloatingLyricsHUD.shared.setVideoURL(nil)
        FloatingLyricsHUD.shared.update(
            current: adText,
            next: "Next song will play shortly...",
            title: "Spotify Advertisement",
            artist: "Ad Break #\(adIndex)",
            progress: fraction,
            lineProgress: 1.0,
            artwork: adIcon,
            highlightColor: NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0),
            isPlaying: track.isPlaying
        )
    }

    // MARK: - Lyrics Loading & Offline Vault Flow (Feature 6)

    private func loadLyrics(for track: NowPlayingTrack, expectedKey: String, forceRefresh: Bool) {
        uiState = .loading(title: track.title, artist: track.artist)
        self.currentTrackOffset = self.offlineVault.getOffset(for: expectedKey)

        // 1. Check Local .lrc Files in ~/Music / ~/Downloads (Feature 6)
        if !forceRefresh, let localLRCText = offlineVault.findLocalLRC(title: track.title, artist: track.artist) {
            let parsedLines = LRCParser.parse(localLRCText)
            if !parsedLines.isEmpty {
                let entry = CachedLyrics(
                    lrclibID: nil,
                    trackKey: expectedKey,
                    lyricsState: .synced(lines: parsedLines, rawLRC: localLRCText),
                    cachedAt: Date()
                )
                lyricsCache.save(entry)
                offlineVault.save(entry)
                self.activeLines = parsedLines
                self.uiState = .synced(title: track.title, artist: track.artist, lines: parsedLines)
                return
            }
        }

        // 2. Check Memory Cache & Offline Vault
        if !forceRefresh {
            if let cached = lyricsCache.get(byKey: expectedKey) ?? offlineVault.get(byKey: expectedKey),
               cached.lyricsState != .notFound {
                guard activeTrackKey == expectedKey else { return }
                applyCachedLyrics(cached, for: track)
                return
            }
        }

        // 3. Online Fetch via LRCLIB
        inFlightFetchTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await self.lrclibClient.fetchLyrics(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: track.duration
                )

                guard !Task.isCancelled, self.activeTrackKey == expectedKey else { return }

                let cachedEntry: CachedLyrics
                let newState: LyricsWidgetUIState

                switch result {
                case .synced(let id, let lrcText, _):
                    let parsedLines = LRCParser.parse(lrcText)
                    cachedEntry = CachedLyrics(
                        lrclibID: id,
                        trackKey: expectedKey,
                        lyricsState: .synced(lines: parsedLines, rawLRC: lrcText),
                        cachedAt: Date()
                    )
                    newState = .synced(title: track.title, artist: track.artist, lines: parsedLines)
                    self.activeLines = parsedLines

                case .plainOnly(let id, let plainText):
                    cachedEntry = CachedLyrics(
                        lrclibID: id,
                        trackKey: expectedKey,
                        lyricsState: .plainOnly(text: plainText),
                        cachedAt: Date()
                    )
                    newState = .staticOnly(title: track.title, artist: track.artist, text: plainText)
                    self.activeLines = []

                case .notFound:
                    cachedEntry = CachedLyrics(
                        lrclibID: nil,
                        trackKey: expectedKey,
                        lyricsState: .notFound,
                        cachedAt: Date()
                    )
                    newState = .noLyricsFound(title: track.title, artist: track.artist)
                    self.activeLines = []
                }

                guard !Task.isCancelled, self.activeTrackKey == expectedKey else { return }
                self.lyricsCache.save(cachedEntry)
                self.offlineVault.save(cachedEntry)
                self.uiState = newState

            } catch {
                guard !Task.isCancelled, self.activeTrackKey == expectedKey else { return }
                NSLog("[LyricsWidget] Network error loading lyrics: \(error.localizedDescription)")
                self.uiState = .noLyricsFound(title: track.title, artist: track.artist)
            }
        }
    }

    private func applyCachedLyrics(_ cached: CachedLyrics, for track: NowPlayingTrack) {
        switch cached.lyricsState {
        case .synced(let lines, _):
            activeLines = lines
            uiState = .synced(title: track.title, artist: track.artist, lines: lines)
        case .plainOnly(let text):
            activeLines = []
            uiState = .staticOnly(title: track.title, artist: track.artist, text: text)
        case .notFound:
            activeLines = []
            uiState = .noLyricsFound(title: track.title, artist: track.artist)
        }
    }

    // MARK: - UI Rendering

    private func updateUI() {
        switch uiState {
        case .noTrackPlaying:
            karaokeView.text = "Lirik"
            karaokeView.activeColor = .secondaryLabelColor
            karaokeView.progress = 0.0
            nextLineLabel.stringValue = "No track playing"
            albumArtButton.isHidden = true
            heartButton.isHidden = true
            equalizerView.setPlaying(false)
            pitchMelodyVisualizer.setPlaying(false)

        case .permissionDenied(let appName):
            karaokeView.text = "Permission Required"
            karaokeView.activeColor = .systemRed
            karaokeView.progress = 1.0
            nextLineLabel.stringValue = "Allow Pock -> \(appName) in System Settings"
            albumArtButton.isHidden = true
            heartButton.isHidden = true
            equalizerView.setPlaying(false)
            pitchMelodyVisualizer.setPlaying(false)

        case .advertisement(_, let adIndex):
            if let track = nowPlayingWatcher.currentTrack {
                renderAdvertisement(track: track, adIndex: adIndex)
            }

        case .loading:
            karaokeView.text = "Fetching lyrics..."
            karaokeView.activeColor = .labelColor
            karaokeView.progress = 0.0
            nextLineLabel.stringValue = ""

        case .noLyricsFound:
            karaokeView.text = "No lyrics available"
            karaokeView.activeColor = .secondaryLabelColor
            karaokeView.progress = 0.0
            nextLineLabel.stringValue = ""

        case .staticOnly(_, _, let text):
            let elapsed = nowPlayingWatcher.currentTrack?.elapsedTime ?? 0
            let duration = nowPlayingWatcher.currentTrack?.duration
            renderStaticLyrics(text, elapsed: elapsed, trackDuration: duration, isPaused: isCurrentlyPaused)

        case .synced(_, _, let lines):
            if lines.isEmpty {
                karaokeView.text = "No lyrics text"
                karaokeView.activeColor = .secondaryLabelColor
                karaokeView.progress = 0.0
                nextLineLabel.stringValue = ""
            } else {
                let elapsed = nowPlayingWatcher.currentTrack?.elapsedTime ?? 0
                let snapshot = LRCSyncEngine.resolve(elapsedTime: elapsed, lines: lines)
                renderSyncSnapshot(snapshot, elapsed: elapsed, isPaused: isCurrentlyPaused)
            }
        }
    }

    private func resolveHighlightColor(isPaused: Bool) -> NSColor {
        guard !isPaused else { return .secondaryLabelColor }
        let defaults = UserDefaults.standard
        let colorKey = defaults.string(forKey: LirikPreferenceViewController.keyHighlightColor) ?? "album"

        if (colorKey == "album" || colorKey == "dynamic"), let dynamic = dynamicArtworkColor {
            return dynamic
        }

        switch colorKey {
        case "white": return .labelColor
        case "gold": return NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        case "cyan": return NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        case "green": return NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        case "purple": return NSColor(red: 0.75, green: 0.45, blue: 1.0, alpha: 1.0)
        case "pink": return NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        case "orange": return NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
        case "red": return NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        default:
            return dynamicArtworkColor ?? .labelColor
        }
    }

    private func applyTextAlignment() {
        let defaults = UserDefaults.standard
        let alignKey = defaults.string(forKey: LirikPreferenceViewController.keyAlignment) ?? "left"
        let isCenter = alignKey == "center"

        textStackView.alignment = isCenter ? .centerX : .leading
        karaokeView.textAlignment = isCenter ? .center : .left
        nextLineLabel.alignment = isCenter ? .center : .left
    }

    private func formatLineText(_ text: String) -> String {
        let defaults = UserDefaults.standard
        let enableMarquee = defaults.object(forKey: LirikPreferenceViewController.keyEnableMarquee) as? Bool ?? false

        guard enableMarquee, text.count > 42 else { return text }

        let timeOffset = Int(Date().timeIntervalSince1970 * 2) % (text.count + 6)
        let extended = text + "  •  " + text
        let start = extended.index(extended.startIndex, offsetBy: min(timeOffset, extended.count - 1))
        let end = extended.index(start, offsetBy: min(38, extended.distance(from: start, to: extended.endIndex)))
        return String(extended[start..<end])
    }

    private func animateNextLineChange(label: NSTextField, newText: String) {
        guard label.stringValue != newText else { return }
        let transition = CATransition()
        transition.duration = 0.20
        transition.type = .fade
        label.layer?.add(transition, forKey: "nextFade")
        label.stringValue = newText
    }

    private func renderStaticLyrics(_ text: String, elapsed: TimeInterval, trackDuration: TimeInterval?, isPaused: Bool) {
        if let (title, artist) = trackInfoComponents() {
            karaokeView.text = title
            karaokeView.activeColor = resolveHighlightColor(isPaused: false)
            karaokeView.font = NSFont.boldSystemFont(ofSize: 11)
            karaokeView.progress = 1.0
            nextLineLabel.stringValue = artist
            nextLineLabel.font = NSFont.systemFont(ofSize: 9)
            nextLineLabel.textColor = .secondaryLabelColor
            nextLineLabel.isHidden = false
            return
        }

        let defaults = UserDefaults.standard
        let dualLine = defaults.object(forKey: LirikPreferenceViewController.keyDualLine) as? Bool ?? true
        let fontSize = defaults.object(forKey: LirikPreferenceViewController.keyFontSize) as? Int ?? 11
        let showPauseIcon = defaults.object(forKey: LirikPreferenceViewController.keyShowPauseIcon) as? Bool ?? true
        let showEq = defaults.object(forKey: LirikPreferenceViewController.keyShowEqualizer) as? Bool ?? true
        let showHeart = defaults.object(forKey: LirikPreferenceViewController.keyShowHeartButton) as? Bool ?? true
        let showPitch = defaults.object(forKey: LirikPreferenceViewController.keyShowPitchVisualizer) as? Bool ?? true

        equalizerView.isHidden = !showEq
        pitchMelodyVisualizer.isHidden = !showPitch
        heartButton.isHidden = !showHeart

        applyTextAlignment()
        karaokeView.font = NSFont.boldSystemFont(ofSize: CGFloat(fontSize))
        nextLineLabel.font = NSFont.systemFont(ofSize: CGFloat(max(8, fontSize - 2)))
        nextLineLabel.isHidden = !dualLine

        applyAlbumArtSize()

        let prefix = (isPaused && showPauseIcon) ? "❙❙ " : ""
        let activeColor = resolveHighlightColor(isPaused: isPaused)
        karaokeView.activeColor = activeColor
        equalizerView.barColor = activeColor
        pitchMelodyVisualizer.barColor = activeColor

        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            karaokeView.text = "\(prefix)\(text)"
            karaokeView.progress = 1.0
            nextLineLabel.stringValue = ""

            let duration = trackDuration ?? 180.0
            let remaining = max(0.0, duration - elapsed)
            let enableUpNext = defaults.object(forKey: LirikPreferenceViewController.keyEnableUpNextCountdown) as? Bool ?? true

            // Outro & Up Next Countdown for Static Lyrics
            if enableUpNext, let track = nowPlayingWatcher.currentTrack, !track.isAdvertisement, duration > 15.0, remaining <= 10.0, remaining > 0.0 {
                let secs = max(1, Int(ceil(remaining)))
                let newText = "\(prefix)Up Next in \(secs)s • Outro"
                karaokeView.text = newText
                karaokeView.progress = CGFloat(max(0.0, min(1.0, (10.0 - remaining) / 10.0)))
                animateNextLineChange(label: nextLineLabel, newText: "Preparing next track in queue...")
                return
            }
            return
        }

        let duration = trackDuration ?? 180.0
        let fraction = duration > 0 ? min(1.0, max(0.0, elapsed / duration)) : 0.0
        let targetIndex = min(lines.count - 1, Int(fraction * Double(lines.count)))
        let nextIndex = targetIndex + 1 < lines.count ? targetIndex + 1 : nil

        let newText = "\(prefix)\(formatLineText(lines[targetIndex]))"
        karaokeView.text = newText
        karaokeView.progress = 1.0
        let upcoming = nextIndex != nil ? lines[nextIndex!] : ""
        animateNextLineChange(label: nextLineLabel, newText: upcoming)

        // Update Floating Desktop HUD & Ambient Window
        if let track = nowPlayingWatcher.currentTrack {
            FloatingLyricsHUD.shared.update(
                current: newText,
                next: upcoming,
                title: track.title,
                artist: track.artist,
                progress: fraction,
                lineProgress: 1.0,
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: activeColor,
                isPlaying: track.isPlaying
            )

            AmbientLyricsWindow.shared.update(
                current: newText,
                next: upcoming,
                previous: targetIndex > 0 ? lines[targetIndex - 1] : "",
                title: track.title,
                artist: track.artist,
                progress: fraction,
                lineProgress: 1.0,
                timeFormatted: "\(formatTime(elapsed)) / \(formatTime(duration))",
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: activeColor,
                videoURL: lastCurrentVideoURL,
                isPlaying: track.isPlaying
            )

            MenuBarLyricsController.shared.update(
                lyric: newText,
                title: track.title,
                artist: track.artist,
                isPlaying: track.isPlaying,
                offset: currentTrackOffset
            )
        }
    }

    private func renderSyncSnapshot(_ snapshot: LRCSyncSnapshot, elapsed: TimeInterval, isPaused: Bool) {
        if let (title, artist) = trackInfoComponents() {
            karaokeView.activeColor = resolveHighlightColor(isPaused: false)
            karaokeView.font = NSFont.boldSystemFont(ofSize: 11)
            karaokeView.text = title
            karaokeView.progress = 1.0
            nextLineLabel.stringValue = artist
            nextLineLabel.font = NSFont.systemFont(ofSize: 9)
            nextLineLabel.textColor = .secondaryLabelColor
            nextLineLabel.isHidden = false
            return
        }

        let defaults = UserDefaults.standard
        let dualLine = defaults.object(forKey: LirikPreferenceViewController.keyDualLine) as? Bool ?? true
        let fontSize = defaults.object(forKey: LirikPreferenceViewController.keyFontSize) as? Int ?? 11
        let showPauseIcon = defaults.object(forKey: LirikPreferenceViewController.keyShowPauseIcon) as? Bool ?? true
        let showEq = defaults.object(forKey: LirikPreferenceViewController.keyShowEqualizer) as? Bool ?? true
        let showHeart = defaults.object(forKey: LirikPreferenceViewController.keyShowHeartButton) as? Bool ?? true
        let showPitch = defaults.object(forKey: LirikPreferenceViewController.keyShowPitchVisualizer) as? Bool ?? true
        let enableRomanize = defaults.object(forKey: LirikPreferenceViewController.keyEnableRomanization) as? Bool ?? true
        let enableUpNext = defaults.object(forKey: LirikPreferenceViewController.keyEnableUpNextCountdown) as? Bool ?? true

        equalizerView.isHidden = !showEq
        pitchMelodyVisualizer.isHidden = !showPitch
        heartButton.isHidden = !showHeart

        applyTextAlignment()
        karaokeView.font = NSFont.boldSystemFont(ofSize: CGFloat(fontSize))
        nextLineLabel.font = NSFont.systemFont(ofSize: CGFloat(max(8, fontSize - 2)))
        nextLineLabel.isHidden = !dualLine

        applyAlbumArtSize()

        let prefix = (isPaused && showPauseIcon) ? "❙❙ " : ""
        let activeColor = resolveHighlightColor(isPaused: isPaused)
        karaokeView.activeColor = activeColor
        equalizerView.barColor = activeColor
        pitchMelodyVisualizer.barColor = activeColor

        var newText: String
        var upcoming: String = ""
        var previousLineText: String = ""

        switch snapshot.positionState {
        case .empty:
            newText = ""
            upcoming = ""
            previousLineText = ""
            currentLineStartTimestamp = 0
            currentLineEndTimestamp = 0
            currentLineWords = []
            karaokeView.progress = 0.0

        case .beforeFirstLine:
            newText = "\(prefix)\(formatLineText(snapshot.upcomingLine?.text ?? ""))"
            upcoming = activeLines.count > 1 ? formatLineText(activeLines[1].text) : ""
            previousLineText = ""
            currentLineWords = []
            currentLineStartTimestamp = snapshot.upcomingLine?.timestamp ?? 0
            currentLineEndTimestamp = snapshot.upcomingLine?.timestamp ?? 0
            karaokeView.progress = 0.0

        case .inLyrics:
            let text = snapshot.currentLine?.text.isEmpty == true
                ? "♪ (instrumental)"
                : snapshot.currentLine?.text ?? ""
            newText = "\(prefix)\(formatLineText(text))"
            upcoming = snapshot.upcomingLine?.text ?? ""

            // Calculate precise line timestamps
            let startTs = snapshot.currentLine?.timestamp ?? elapsed
            let endTs = snapshot.upcomingLine?.timestamp ?? (startTs + 4.0)
            currentLineStartTimestamp = startTs
            currentLineEndTimestamp = endTs
            currentLineWords = snapshot.currentLine?.words ?? []

            let progress = calculateNaturalProgress(
                elapsed: elapsed,
                lineStart: startTs,
                lineEnd: endTs,
                lineText: text,
                explicitWords: currentLineWords
            )
            karaokeView.progress = CGFloat(progress)

            // Romanization on Line 2 if Asian/non-Latin script detected
            if enableRomanize && Romanizer.containsNonLatin(text) {
                let romaji = Romanizer.romanize(text)
                if romaji != text {
                    upcoming = "Romaji • " + romaji
                }
            }

            if let idx = snapshot.currentIndex, idx > 0 {
                previousLineText = activeLines[idx - 1].text
            } else {
                previousLineText = ""
            }

        case .afterLastLine:
            newText = "\(prefix)\(formatLineText(snapshot.currentLine?.text ?? ""))"
            upcoming = ""
            previousLineText = activeLines.count > 1 ? activeLines[activeLines.count - 2].text : ""
            currentLineWords = []
            karaokeView.progress = 1.0
        }

        // Outro & Up Next Countdown for Synced Lyrics
        if enableUpNext, let track = nowPlayingWatcher.currentTrack, !track.isAdvertisement, let duration = track.duration, duration > 15.0 {
            let remaining = max(0.0, duration - elapsed)
            let isPostLyrics = (snapshot.positionState == .afterLastLine)

            if (remaining <= 10.0 && remaining > 0.0) || (isPostLyrics && remaining <= 15.0 && remaining > 0.0) {
                let secs = max(1, Int(ceil(remaining)))
                newText = "\(prefix)Up Next in \(secs)s • Outro"
                upcoming = "Preparing next track in queue..."
                let countdownProgress = CGFloat(max(0.0, min(1.0, (12.0 - remaining) / 12.0)))
                karaokeView.progress = countdownProgress
                currentLineWords = []
            }
        }

        self.currentPreviousLineText = previousLineText
        karaokeView.text = newText
        animateNextLineChange(label: nextLineLabel, newText: upcoming)

        // Update Floating Desktop HUD & Ambient Window
        if let track = nowPlayingWatcher.currentTrack {
            let duration = track.duration ?? 180.0
            let fraction = duration > 0 ? (elapsed / duration) : 0.0
            let lineFraction = Double(karaokeView.progress)

            FloatingLyricsHUD.shared.update(
                current: newText,
                next: upcoming,
                title: track.title,
                artist: track.artist,
                progress: fraction,
                lineProgress: lineFraction,
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: activeColor,
                isPlaying: track.isPlaying
            )

            AmbientLyricsWindow.shared.update(
                current: newText,
                next: upcoming,
                previous: previousLineText,
                title: track.title,
                artist: track.artist,
                progress: fraction,
                lineProgress: lineFraction,
                timeFormatted: "\(formatTime(elapsed)) / \(formatTime(duration))",
                artwork: loadedArtworkImage ?? albumArtImageView.image,
                highlightColor: activeColor,
                videoURL: lastCurrentVideoURL,
                isPlaying: track.isPlaying
            )

            MenuBarLyricsController.shared.update(
                lyric: newText,
                title: track.title,
                artist: track.artist,
                isPlaying: track.isPlaying,
                offset: currentTrackOffset
            )
        }
    }

    // MARK: - Album Art Fetching & Dynamic Color Extraction

    private func fetchAlbumArt(for track: NowPlayingTrack) {
        let defaults = UserDefaults.standard
        let showArt = defaults.object(forKey: LirikPreferenceViewController.keyShowAlbumArt) as? Bool ?? true
        guard showArt else {
            DispatchQueue.main.async { [weak self] in
                self?.albumArtButton.isHidden = true
            }
            return
        }

        applyAlbumArtSize()

        Task { [weak self] in
            guard let self else { return }

            let image = await self.albumArtService.fetchArtwork(
                artist: track.artist,
                album: track.album
            )

            guard self.nowPlayingWatcher.currentTrack?.isSameTrack(as: track) == true else {
                return
            }

            DispatchQueue.main.async {
                if let image = image {
                    self.loadedArtworkImage = image
                    self.albumArtImageView.image = image
                    self.albumArtButton.isHidden = false

                    // Extract vibrant dynamic color from album art
                    self.dynamicArtworkColor = ColorExtractor.extractDominantColor(from: image)

                    // Re-render highlight color with new dynamic color
                    let activeColor = self.resolveHighlightColor(isPaused: self.isCurrentlyPaused)
                    self.karaokeView.activeColor = activeColor
                    self.equalizerView.barColor = activeColor
                    self.pitchMelodyVisualizer.barColor = activeColor
                } else {
                    self.loadedArtworkImage = nil
                    let placeholder = NSImage(
                        systemSymbolName: "music.note",
                        accessibilityDescription: "Album Art"
                    )
                    self.albumArtImageView.image = placeholder
                    self.albumArtButton.isHidden = false
                    self.dynamicArtworkColor = nil
                }
            }
        }
    }

    // MARK: - Spotify Canvas Video Fetching

    private func fetchCanvasVideo(for track: NowPlayingTrack) {
        let defaults = UserDefaults.standard
        let enableCanvas = defaults.object(forKey: LirikPreferenceViewController.keyEnableCanvas) as? Bool ?? true
        guard enableCanvas else {
            DispatchQueue.main.async { [weak self] in
                self?.lastCurrentVideoURL = nil
                self?.videoView.clear()
                self?.videoView.isHidden = true
                self?.albumArtImageView.isHidden = false
                FloatingLyricsHUD.shared.setVideoURL(nil)
            }
            return
        }

        inFlightCanvasTask = Task { [weak self] in
            guard let self else { return }

            let videoURL = await self.canvasVideoService.fetchCanvasURL(
                trackID: track.trackID,
                title: track.title,
                artist: track.artist
            )

            guard self.nowPlayingWatcher.currentTrack?.isSameTrack(as: track) == true else {
                return
            }

            DispatchQueue.main.async {
                if let videoURL = videoURL {
                    self.lastCurrentVideoURL = videoURL
                    self.videoView.loadVideo(url: videoURL)
                    self.videoView.isHidden = false
                    self.albumArtImageView.isHidden = true
                    self.albumArtButton.isHidden = false
                    FloatingLyricsHUD.shared.setVideoURL(videoURL)
                } else {
                    self.lastCurrentVideoURL = nil
                    self.videoView.clear()
                    self.videoView.isHidden = true
                    self.albumArtImageView.isHidden = false
                    FloatingLyricsHUD.shared.setVideoURL(nil)
                }
            }
        }
    }

    private func applyAlbumArtSize() {
        let sizeIndex = UserDefaults.standard.object(forKey: LirikPreferenceViewController.keyAlbumArtSize) as? Int ?? 1
        let sizes: [CGFloat] = [20, 24, 28]
        let size = sizes[max(0, min(sizeIndex, sizes.count - 1))]
        albumArtWidthConstraint?.constant = size
        albumArtHeightConstraint?.constant = size
    }

    private func trackInfoComponents() -> (title: String, artist: String)? {
        guard let until = trackInfoVisibleUntil, Date() < until,
              let track = nowPlayingWatcher.currentTrack, !track.isAdvertisement else { return nil }

        let displayArtist = artistWithFeaturing(artist: track.artist, title: track.title)
        return (title: track.title, artist: displayArtist)
    }

    private func artistWithFeaturing(artist: String, title: String) -> String {
        let patterns = [
            "\\(feat\\.\\s*([^)]+)\\)",
            "\\[feat\\.\\s*([^\\]]+)\\]",
            "\\(ft\\.\\s*([^)]+)\\)",
            "\\[ft\\.\\s*([^\\]]+)\\]",
            "\\(with\\s+([^)]+)\\)",
            "\\[with\\s+([^\\]]+)\\]",
            "\\sfeat\\.\\s+(.+)$",
            "\\sft\\.\\s+(.+)$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
               let featRange = Range(match.range(at: 1), in: title) {
                let featArtist = String(title[featRange]).trimmingCharacters(in: .whitespaces)
                if !featArtist.isEmpty {
                    return "\(artist) ft. \(featArtist)"
                }
            }
        }

        return artist
    }
}
