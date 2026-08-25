//
//  MenuBarLyricsController.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit

final class MenuBarLyricsController: NSObject, NSMenuDelegate {

    static let shared = MenuBarLyricsController()

    private var statusItem: NSStatusItem?
    private var isEnabled: Bool = true
    private var currentLyric: String = ""
    private var currentTitle: String = ""
    private var currentArtist: String = ""
    private var isPlaying: Bool = false
    private var currentOffset: Double = 0.0

    var onOffsetAdjusted: ((Double) -> Void)?
    var onPlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    override init() {
        super.init()
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.object(forKey: LirikPreferenceViewController.keyEnableMenuBarLyrics) as? Bool ?? true
        if isEnabled {
            setupStatusItem()
        }
    }

    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: LirikPreferenceViewController.keyEnableMenuBarLyrics)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isEnabled {
                self.setupStatusItem()
                self.updateDisplay()
            } else {
                if let item = self.statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    self.statusItem = nil
                }
            }
        }
    }

    private func setupStatusItem() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "♪ Lirik"
        statusItem?.button?.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        buildMenu()
    }

    func update(lyric: String, title: String, artist: String, isPlaying: Bool, offset: Double = 0.0) {
        self.currentLyric = lyric
        self.currentTitle = title
        self.currentArtist = artist
        self.isPlaying = isPlaying
        self.currentOffset = offset

        guard isEnabled else { return }
        DispatchQueue.main.async { [weak self] in
            self?.updateDisplay()
        }
    }

    private func updateDisplay() {
        guard isEnabled, let button = statusItem?.button else { return }

        let displayLyric = currentLyric.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayLyric.isEmpty && displayLyric != "•••" && displayLyric != "♪ (instrumental)" {
            let truncated = displayLyric.count > 38 ? String(displayLyric.prefix(36)) + "…" : displayLyric
            button.title = "♪ \(truncated)"
        } else if !currentTitle.isEmpty {
            let combined = "\(currentTitle) - \(currentArtist)"
            let truncated = combined.count > 32 ? String(combined.prefix(30)) + "…" : combined
            button.title = "♪ \(truncated)"
        } else {
            button.title = "♪ Lirik"
        }

        buildMenu()
    }

    private func buildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.delegate = self

        // 1. Header (Now Playing)
        if !currentTitle.isEmpty {
            let titleItem = NSMenuItem(title: currentTitle, action: nil, keyEquivalent: "")
            titleItem.attributedTitle = NSAttributedString(
                string: currentTitle,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
            menu.addItem(titleItem)

            let artistItem = NSMenuItem(title: currentArtist, action: nil, keyEquivalent: "")
            artistItem.attributedTitle = NSAttributedString(
                string: currentArtist,
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(artistItem)

            if !currentLyric.isEmpty {
                let lyricItem = NSMenuItem(title: "♪ \(currentLyric)", action: nil, keyEquivalent: "")
                lyricItem.attributedTitle = NSAttributedString(
                    string: "♪ \"\(currentLyric)\"",
                    attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.systemTeal]
                )
                menu.addItem(lyricItem)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 2. Playback Controls
        let playPauseTitle = isPlaying ? "Pause" : "Play"
        let playPauseItem = NSMenuItem(title: playPauseTitle, action: #selector(onMenuPlayPause), keyEquivalent: " ")
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        let nextItem = NSMenuItem(title: "Next Track", action: #selector(onMenuNext), keyEquivalent: "")
        nextItem.target = self
        menu.addItem(nextItem)

        let prevItem = NSMenuItem(title: "Previous Track", action: #selector(onMenuPrevious), keyEquivalent: "")
        prevItem.target = self
        menu.addItem(prevItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Timing Sync Offset Submenu (Feature 2)
        let offsetMenu = NSMenu()
        let currentOffsetFormatted = String(format: "%+.1fs", currentOffset)
        let offsetHeader = NSMenuItem(title: "Current Sync Offset: \(currentOffsetFormatted)", action: nil, keyEquivalent: "")
        offsetHeader.isEnabled = false
        offsetMenu.addItem(offsetHeader)
        offsetMenu.addItem(NSMenuItem.separator())

        let speedUp = NSMenuItem(title: "Faster (+0.5s)", action: #selector(onSpeedUpOffset), keyEquivalent: "]")
        speedUp.target = self
        offsetMenu.addItem(speedUp)

        let slowDown = NSMenuItem(title: "Slower (-0.5s)", action: #selector(onSlowDownOffset), keyEquivalent: "[")
        slowDown.target = self
        offsetMenu.addItem(slowDown)

        let resetOffset = NSMenuItem(title: "Reset Offset (0.0s)", action: #selector(onResetOffset), keyEquivalent: "0")
        resetOffset.target = self
        offsetMenu.addItem(resetOffset)

        let offsetParentItem = NSMenuItem(title: "Lyric Sync Offset (\(currentOffsetFormatted))", action: nil, keyEquivalent: "")
        offsetParentItem.submenu = offsetMenu
        menu.addItem(offsetParentItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Floating HUD & Ambient Toggles
        let hudItem = NSMenuItem(title: "Toggle Floating Desktop HUD", action: #selector(onToggleHUD), keyEquivalent: "h")
        hudItem.target = self
        menu.addItem(hudItem)

        let ambientItem = NSMenuItem(title: "Toggle Fullscreen Ambient Lyrics", action: #selector(onToggleAmbient), keyEquivalent: "f")
        ambientItem.target = self
        menu.addItem(ambientItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Hide / Preferences
        let hideItem = NSMenuItem(title: "Hide Menu Bar Ticker", action: #selector(onHideMenuBar), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        statusItem.menu = menu
    }

    // MARK: - Action Handlers

    @objc private func onMenuPlayPause() {
        onPlayPause?()
    }

    @objc private func onMenuNext() {
        onNextTrack?()
    }

    @objc private func onMenuPrevious() {
        onPreviousTrack?()
    }

    @objc private func onSpeedUpOffset() {
        onOffsetAdjusted?(0.5)
    }

    @objc private func onSlowDownOffset() {
        onOffsetAdjusted?(-0.5)
    }

    @objc private func onResetOffset() {
        onOffsetAdjusted?(0.0)
    }

    @objc private func onToggleHUD() {
        FloatingLyricsHUD.shared.toggleHUD()
    }

    @objc private func onToggleAmbient() {
        AmbientLyricsWindow.shared.toggleAmbient()
    }

    @objc private func onHideMenuBar() {
        setEnabled(false)
    }
}
