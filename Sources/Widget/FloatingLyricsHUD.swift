//
//  FloatingLyricsHUD.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit

final class FloatingLyricsHUD: NSWindowController {

    static let shared = FloatingLyricsHUD()

    private var hudPanel: NSPanel!
    private let titleLabel = NSTextField(labelWithString: "Lirik")
    private let artistLabel = NSTextField(labelWithString: "")
    private let currentLineView = KaraokeLyricView()
    private let nextLineLabel = NSTextField(labelWithString: "")
    private let albumArtImageView = NSImageView()
    private let videoView = LoopingVideoView()
    private let progressIndicator = NSProgressIndicator()
    private let visualEffectView = NSVisualEffectView()
    private let closeButton = NSButton()
    private let ambientButton = NSButton()
    private let quoteButton = NSButton()

    private(set) var isHUDVisible: Bool = false
    private var currentVideoURL: URL? = nil

    init() {
        let width: CGFloat = 460
        let height: CGFloat = 135
        let initialRect = NSRect(x: 100, y: 100, width: width, height: height)

        let panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        self.hudPanel = panel
        setupHUD()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHUD() {
        guard let panel = hudPanel else { return }

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true

        // Position bottom center on primary screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - 460) / 2
            let y = screenRect.origin.y + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        visualEffectView.frame = panel.contentView?.bounds ?? .zero
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        // Layout UI
        let artRect = NSRect(x: 14, y: 38, width: 62, height: 62)
        albumArtImageView.frame = artRect
        albumArtImageView.imageScaling = .scaleProportionallyUpOrDown
        albumArtImageView.wantsLayer = true
        albumArtImageView.layer?.cornerRadius = 10
        albumArtImageView.layer?.masksToBounds = true

        videoView.frame = artRect
        videoView.wantsLayer = true
        videoView.layer?.cornerRadius = 10
        videoView.layer?.masksToBounds = true
        videoView.isHidden = true

        titleLabel.frame = NSRect(x: 88, y: 96, width: 270, height: 18)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        artistLabel.frame = NSRect(x: 88, y: 78, width: 270, height: 16)
        artistLabel.font = NSFont.systemFont(ofSize: 11)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.lineBreakMode = .byTruncatingTail

        // Progressive Karaoke Lyric View
        currentLineView.frame = NSRect(x: 88, y: 44, width: 350, height: 32)
        currentLineView.font = NSFont.boldSystemFont(ofSize: 16)
        currentLineView.activeColor = .white
        currentLineView.text = "No track playing"

        nextLineLabel.frame = NSRect(x: 88, y: 24, width: 350, height: 18)
        nextLineLabel.font = NSFont.systemFont(ofSize: 11)
        nextLineLabel.textColor = .secondaryLabelColor
        nextLineLabel.lineBreakMode = .byTruncatingTail

        progressIndicator.frame = NSRect(x: 14, y: 8, width: 432, height: 6)
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        progressIndicator.style = .bar

        let btnConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)

        // 1. Quote Card button (SF Symbol: quote.bubble)
        quoteButton.frame = NSRect(x: 366, y: 104, width: 24, height: 24)
        quoteButton.bezelStyle = .circular
        quoteButton.isBordered = false
        quoteButton.image = NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: "Share Quote")?.withSymbolConfiguration(btnConfig)
        quoteButton.contentTintColor = .secondaryLabelColor
        quoteButton.toolTip = "Generate Lyric Quote Card"
        quoteButton.target = self
        quoteButton.action = #selector(onQuoteTapped)

        // 2. Fullscreen Ambient button (SF Symbol: arrow.up.left.and.arrow.down.right)
        ambientButton.frame = NSRect(x: 396, y: 104, width: 24, height: 24)
        ambientButton.bezelStyle = .circular
        ambientButton.isBordered = false
        ambientButton.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fullscreen")?.withSymbolConfiguration(btnConfig)
        ambientButton.contentTintColor = .secondaryLabelColor
        ambientButton.toolTip = "Fullscreen Ambient Lyrics Mode"
        ambientButton.target = self
        ambientButton.action = #selector(onAmbientTapped)

        // 3. Close button (SF Symbol: xmark)
        closeButton.frame = NSRect(x: 426, y: 104, width: 24, height: 24)
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?.withSymbolConfiguration(btnConfig)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(hideHUD)

        visualEffectView.addSubview(albumArtImageView)
        visualEffectView.addSubview(videoView)
        visualEffectView.addSubview(titleLabel)
        visualEffectView.addSubview(artistLabel)
        visualEffectView.addSubview(currentLineView)
        visualEffectView.addSubview(nextLineLabel)
        visualEffectView.addSubview(progressIndicator)
        visualEffectView.addSubview(quoteButton)
        visualEffectView.addSubview(ambientButton)
        visualEffectView.addSubview(closeButton)

        panel.contentView = visualEffectView
    }

    @objc private func onQuoteTapped() {
        _ = QuoteCardGenerator.generateAndCopy(
            title: titleLabel.stringValue,
            artist: artistLabel.stringValue,
            lyricQuote: currentLineView.text,
            artwork: albumArtImageView.image,
            highlightColor: currentLineView.activeColor
        )
    }

    @objc private func onAmbientTapped() {
        AmbientLyricsWindow.shared.toggleAmbient()
    }

    func toggleHUD() {
        if isHUDVisible {
            hideHUD()
        } else {
            showHUD()
        }
    }

    func showHUD() {
        guard let panel = hudPanel else { return }
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }
        isHUDVisible = true
    }

    @objc func hideHUD() {
        guard let panel = hudPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            self.isHUDVisible = false
        })
    }

    func setVideoURL(_ url: URL?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let url = url {
                if self.currentVideoURL != url {
                    self.currentVideoURL = url
                    self.videoView.loadVideo(url: url)
                    self.videoView.isHidden = false
                    self.albumArtImageView.isHidden = true
                }
            } else {
                self.currentVideoURL = nil
                self.videoView.clear()
                self.videoView.isHidden = true
                self.albumArtImageView.isHidden = false
            }
        }
    }

    func update(current: String, next: String, title: String, artist: String, progress: Double, lineProgress: Double = 1.0, artwork: NSImage?, highlightColor: NSColor?, isPlaying: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.titleLabel.stringValue = title
            self.artistLabel.stringValue = artist
            self.currentLineView.text = current
            self.currentLineView.progress = CGFloat(lineProgress)
            self.nextLineLabel.stringValue = next
            self.progressIndicator.doubleValue = min(max(progress * 100.0, 0.0), 100.0)

            if isPlaying {
                self.videoView.playVideo()
            } else {
                self.videoView.pauseVideo()
            }

            if self.currentVideoURL == nil {
                if let artwork = artwork {
                    self.albumArtImageView.image = artwork
                    self.albumArtImageView.isHidden = false
                } else {
                    self.albumArtImageView.isHidden = true
                }
            }

            if let highlight = highlightColor {
                self.currentLineView.activeColor = highlight
            } else {
                self.currentLineView.activeColor = .white
            }
        }
    }
}
