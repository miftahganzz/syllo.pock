//
//  AmbientLyricsWindow.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import QuartzCore

final class AmbientLyricsWindow: NSWindowController {

    static let shared = AmbientLyricsWindow()

    private var ambientPanel: NSPanel!
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = NSTextField(labelWithString: "Lirik")
    private let artistLabel = NSTextField(labelWithString: "")
    private let previousLineLabel = NSTextField(labelWithString: "")
    private let currentLineView = KaraokeLyricView()
    private let nextLineLabel = NSTextField(labelWithString: "")
    private let albumArtImageView = NSImageView()
    private let videoView = LoopingVideoView()
    private let progressIndicator = NSProgressIndicator()
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private let closeButton = NSButton()

    private(set) var isAmbientVisible: Bool = false

    // State caching to prevent 30 FPS layer thrashing & video reloading
    private var currentVideoURL: URL? = nil
    private var lastLoadedArtwork: NSImage? = nil
    private var lastHighlightColor: NSColor? = nil

    init() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panel = NSPanel(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        self.ambientPanel = panel
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        guard let panel = ambientPanel else { return }

        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false

        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.wantsLayer = true

        // Animated Gradient Background
        gradientLayer.frame = contentView.bounds
        gradientLayer.colors = [
            NSColor(red: 0.12, green: 0.05, blue: 0.15, alpha: 1.0).cgColor,
            NSColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 1.0).cgColor,
            NSColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        contentView.layer?.addSublayer(gradientLayer)

        // Close Button (Top Right with SF Symbol: xmark)
        let closeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        closeButton.frame = NSRect(x: contentView.bounds.width - 64, y: contentView.bounds.height - 64, width: 40, height: 40)
        closeButton.autoresizingMask = [.minXMargin, .minYMargin]
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?.withSymbolConfiguration(closeConfig)
        closeButton.contentTintColor = .white
        closeButton.target = self
        closeButton.action = #selector(hideAmbient)
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        closeButton.layer?.cornerRadius = 20

        // Layout Center Columns: Left Column Artwork, Right Column Large Lyrics
        let midY = contentView.bounds.height / 2
        let artSize: CGFloat = 360
        let artRect = NSRect(x: 120, y: midY - artSize / 2 + 30, width: artSize, height: artSize)

        albumArtImageView.frame = artRect
        albumArtImageView.imageScaling = .scaleProportionallyUpOrDown
        albumArtImageView.wantsLayer = true
        albumArtImageView.layer?.cornerRadius = 28
        albumArtImageView.layer?.masksToBounds = true
        albumArtImageView.layer?.shadowColor = NSColor.black.cgColor
        albumArtImageView.layer?.shadowOpacity = 0.6
        albumArtImageView.layer?.shadowRadius = 30
        albumArtImageView.layer?.shadowOffset = CGSize(width: 0, height: -14)

        videoView.frame = artRect
        videoView.wantsLayer = true
        videoView.layer?.cornerRadius = 28
        videoView.layer?.masksToBounds = true
        videoView.isHidden = true

        // Track Info under Artwork
        titleLabel.frame = NSRect(x: 120, y: artRect.minY - 50, width: artSize, height: 32)
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        artistLabel.frame = NSRect(x: 120, y: artRect.minY - 82, width: artSize, height: 24)
        artistLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        artistLabel.textColor = NSColor.white.withAlphaComponent(0.70)
        artistLabel.alignment = .center
        artistLabel.lineBreakMode = .byTruncatingTail

        // Lyrics Column (Right)
        let lyricX: CGFloat = 530
        let lyricWidth = max(400, contentView.bounds.width - lyricX - 120)

        previousLineLabel.frame = NSRect(x: lyricX, y: midY + 95, width: lyricWidth, height: 44)
        previousLineLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        previousLineLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        previousLineLabel.lineBreakMode = .byTruncatingTail

        // Large Progressive Karaoke View
        currentLineView.frame = NSRect(x: lyricX, y: midY - 35, width: lyricWidth, height: 85)
        currentLineView.font = NSFont.systemFont(ofSize: 38, weight: .black)
        currentLineView.activeColor = .white
        currentLineView.text = "No track playing"

        nextLineLabel.frame = NSRect(x: lyricX, y: midY - 115, width: lyricWidth, height: 44)
        nextLineLabel.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        nextLineLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        nextLineLabel.lineBreakMode = .byTruncatingTail

        // Bottom Progress Bar
        progressIndicator.frame = NSRect(x: 120, y: 45, width: contentView.bounds.width - 240, height: 6)
        progressIndicator.autoresizingMask = [.width, .maxYMargin]
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.style = .bar

        timeLabel.frame = NSRect(x: 120, y: 18, width: contentView.bounds.width - 240, height: 20)
        timeLabel.autoresizingMask = [.width, .maxYMargin]
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        timeLabel.alignment = .right

        contentView.addSubview(albumArtImageView)
        contentView.addSubview(videoView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(previousLineLabel)
        contentView.addSubview(currentLineView)
        contentView.addSubview(nextLineLabel)
        contentView.addSubview(progressIndicator)
        contentView.addSubview(timeLabel)
        contentView.addSubview(closeButton)

        panel.contentView = contentView
    }

    func toggleAmbient() {
        if isAmbientVisible {
            hideAmbient()
        } else {
            showAmbient()
        }
    }

    func showAmbient() {
        guard let panel = ambientPanel, let screen = NSScreen.main else { return }
        panel.setFrame(screen.frame, display: true)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1.0
        }
        isAmbientVisible = true
    }

    @objc func hideAmbient() {
        guard let panel = ambientPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            self.isAmbientVisible = false
        })
    }

    func update(
        current: String,
        next: String,
        previous: String,
        title: String,
        artist: String,
        progress: Double,
        lineProgress: Double = 1.0,
        timeFormatted: String,
        artwork: NSImage?,
        highlightColor: NSColor?,
        videoURL: URL?,
        isPlaying: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.titleLabel.stringValue != title {
                self.titleLabel.stringValue = title
            }
            if self.artistLabel.stringValue != artist {
                self.artistLabel.stringValue = artist
            }
            if self.previousLineLabel.stringValue != previous {
                self.previousLineLabel.stringValue = previous
            }
            if self.currentLineView.text != current {
                self.currentLineView.text = current
            }
            self.currentLineView.progress = CGFloat(lineProgress)

            if self.nextLineLabel.stringValue != next {
                self.nextLineLabel.stringValue = next
            }
            self.progressIndicator.doubleValue = min(max(progress * 100.0, 0.0), 100.0)
            self.timeLabel.stringValue = timeFormatted

            // 1. Update Highlight & Gradient only when changed
            if let highlight = highlightColor {
                if self.lastHighlightColor != highlight {
                    self.lastHighlightColor = highlight
                    self.currentLineView.activeColor = highlight

                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.gradientLayer.colors = [
                        highlight.withAlphaComponent(0.40).cgColor,
                        NSColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1.0).cgColor,
                        NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0).cgColor
                    ]
                    CATransaction.commit()
                }
            }

            // 2. Update Video / Artwork without reloading on every tick
            if let videoURL = videoURL {
                if self.currentVideoURL != videoURL {
                    self.currentVideoURL = videoURL
                    self.videoView.loadVideo(url: videoURL)
                    self.videoView.isHidden = false
                    self.albumArtImageView.isHidden = true
                }
                if isPlaying { self.videoView.playVideo() } else { self.videoView.pauseVideo() }
            } else {
                if self.currentVideoURL != nil {
                    self.currentVideoURL = nil
                    self.videoView.clear()
                    self.videoView.isHidden = true
                    self.albumArtImageView.isHidden = false
                }
                if self.lastLoadedArtwork !== artwork {
                    self.lastLoadedArtwork = artwork
                    self.albumArtImageView.image = artwork
                    self.albumArtImageView.isHidden = (artwork == nil)
                }
            }
        }
    }
}
