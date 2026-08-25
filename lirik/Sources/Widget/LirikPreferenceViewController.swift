//
//  LirikPreferenceViewController.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import PockKit

@objc(LirikPreferenceViewController)
final class LirikPreferenceViewController: NSViewController, PKWidgetPreference {

    static var nibName: NSNib.Name = NSNib.Name("LirikPreferenceViewController")

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - UserDefaults Keys

    static let keyDualLine = "io.github.ridhaaf.lirik.dualLine"
    static let keyFontSize = "io.github.ridhaaf.lirik.fontSize"
    static let keyPreferredPlayer = "io.github.ridhaaf.lirik.preferredPlayer"
    static let keyShowPauseIcon = "io.github.ridhaaf.lirik.showPauseIcon"
    static let keyHighlightColor = "io.github.ridhaaf.lirik.highlightColor"
    static let keyAlignment = "io.github.ridhaaf.lirik.alignment"
    static let keyEnableMarquee = "io.github.ridhaaf.lirik.enableMarquee"
    static let keyShowAlbumArt = "io.github.ridhaaf.lirik.showAlbumArt"
    static let keyAlbumArtSize = "io.github.ridhaaf.lirik.albumArtSize"
    static let keyShowTrackInfo = "io.github.ridhaaf.lirik.showTrackInfo"
    static let keyShowEqualizer = "io.github.ridhaaf.lirik.showEqualizer"
    static let keyShowPitchVisualizer = "io.github.ridhaaf.lirik.showPitchVisualizer"
    static let keyEnableCanvas = "io.github.ridhaaf.lirik.enableCanvas"
    static let keyLyricAnimation = "io.github.ridhaaf.lirik.lyricAnimation"
    static let keyEnableKaraokeGlow = "io.github.ridhaaf.lirik.enableKaraokeGlow"
    static let keyLyricHighlightStyle = "io.github.ridhaaf.lirik.lyricHighlightStyle"
    static let keyLongLyricMode = "io.github.ridhaaf.lirik.longLyricMode"
    static let keyEnableRomanization = "io.github.ridhaaf.lirik.enableRomanization"
    static let keyShowHeartButton = "io.github.ridhaaf.lirik.showHeartButton"
    static let keyEnableGestures = "io.github.ridhaaf.lirik.enableGestures"
    static let keyAdAudioBehavior = "io.github.ridhaaf.lirik.adAudioBehavior"
    static let keyEnableUpNextCountdown = "io.github.ridhaaf.lirik.enableUpNextCountdown"
    static let keyEnableMenuBarLyrics = "io.github.ridhaaf.lirik.enableMenuBarLyrics"

    // MARK: - Category Switcher

    private let categorySegmentControl = NSSegmentedControl(
        labels: ["🎨 Gaya & Tampilan", "🎵 Player & Cover", "⚡ Fitur Cerdas"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    // MARK: - Category 1: Appearance & Lyrics Controls

    private let appearanceStackView = NSStackView()
    private let dualLineControl = NSSegmentedControl(labels: ["2-Baris Karaoke", "1-Baris Ringkas"], trackingMode: .selectOne, target: nil, action: nil)
    private let stylePopUp = NSPopUpButton()
    private let longLyricPopUp = NSPopUpButton()
    private let colorPopUp = NSPopUpButton()
    private let alignmentControl = NSSegmentedControl(labels: ["Rata Kiri", "Rata Tengah"], trackingMode: .selectOne, target: nil, action: nil)
    private let fontSizeControl = NSSegmentedControl(labels: ["Kecil (10pt)", "Sedang (11pt)", "Besar (13pt)"], trackingMode: .selectOne, target: nil, action: nil)
    private let animationPopUp = NSPopUpButton()

    // MARK: - Category 2: Media & Artwork Controls

    private let mediaStackView = NSStackView()
    private let playerPopUp = NSPopUpButton()
    private let adAudioPopUp = NSPopUpButton()
    private let albumArtCheckbox = NSButton(checkboxWithTitle: "Tampilkan Foto / Sampul Album (Artwork)", target: nil, action: nil)
    private let albumArtSizeControl = NSSegmentedControl(labels: ["Kecil", "Sedang", "Besar"], trackingMode: .selectOne, target: nil, action: nil)
    private let canvasCheckbox = NSButton(checkboxWithTitle: "Aktifkan Spotify Canvas Video Looping", target: nil, action: nil)
    private let trackInfoCheckbox = NSButton(checkboxWithTitle: "Tampilkan Badge Info Lagu Saat Berganti", target: nil, action: nil)
    private let pauseIconCheckbox = NSButton(checkboxWithTitle: "Tampilkan Ikon Jeda (⏸ / ❙❙) Saat Pause", target: nil, action: nil)

    // MARK: - Category 3: Smart Features & Gestures

    private let smartStackView = NSStackView()
    private let romanizeCheckbox = NSButton(checkboxWithTitle: "Auto-Romanisasi Lirik Korea, Jepang & Mandarin", target: nil, action: nil)
    private let equalizerCheckbox = NSButton(checkboxWithTitle: "Tampilkan Spektrum Equalizer Animatif", target: nil, action: nil)
    private let pitchVisualizerCheckbox = NSButton(checkboxWithTitle: "Tampilkan Live Vocal Pitch & Melody Meter", target: nil, action: nil)
    private let menuBarCheckbox = NSButton(checkboxWithTitle: "Tampilkan Lirik Berjalan di macOS Menu Bar", target: nil, action: nil)
    private let upNextCheckbox = NSButton(checkboxWithTitle: "Tampilkan Hitung Mundur 'Up Next' di Outro Lagu", target: nil, action: nil)
    private let heartButtonCheckbox = NSButton(checkboxWithTitle: "Tampilkan Tombol Suka (❤️) di Touch Bar", target: nil, action: nil)
    private let gesturesCheckbox = NSButton(checkboxWithTitle: "Aktifkan Gestur 2-Jari (Geser Lagu & Volume)", target: nil, action: nil)

    // MARK: - Persistent Footer

    private let clearCacheButton = NSButton(title: "Hapus Cache & Offline Vault", target: nil, action: nil)
    private let cacheStatusLabel = NSTextField(labelWithString: "")
    private let lyricsCache = LyricsCache()

    // MARK: - View Lifecycle

    override func loadView() {
        let mainStackView = NSStackView()
        mainStackView.orientation = .vertical
        mainStackView.alignment = .leading
        mainStackView.spacing = 12
        mainStackView.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)

        // Header Title & Version
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8

        let titleLabel = NSTextField(labelWithString: "Lirik Preferences")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)

        let badgeLabel = NSTextField(labelWithString: "v2.0 Enhanced")
        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textColor = .secondaryLabelColor

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(badgeLabel)
        mainStackView.addArrangedSubview(headerStack)

        // Category Tab Switcher
        categorySegmentControl.selectedSegment = 0
        categorySegmentControl.segmentDistribution = .fillEqually
        categorySegmentControl.target = self
        categorySegmentControl.action = #selector(onCategoryChanged)
        mainStackView.addArrangedSubview(categorySegmentControl)

        let topSep = NSBox()
        topSep.boxType = .separator
        mainStackView.addArrangedSubview(topSep)

        // ==========================================
        // 1. APPEARANCE & LYRICS TAB
        // ==========================================
        appearanceStackView.orientation = .vertical
        appearanceStackView.alignment = .leading
        appearanceStackView.spacing = 10
        appearanceStackView.wantsLayer = true

        // Display Mode
        let modeStack = createSection(title: "Mode Tampilan:", control: dualLineControl)
        appearanceStackView.addArrangedSubview(modeStack)

        // Highlight Style
        stylePopUp.addItems(withTitles: [
            "Word Snap (Seblok Kata Utuh — Pas & Smooth)",
            "Apple Music Line Focus (Baris Aktif Bercahaya)",
            "Word Pill (Kapsul Kata Bercahaya)",
            "Smooth Karaoke Sweep (Wipe Progresif)"
        ])
        let styleStack = createSection(title: "Gaya Sorotan Lirik:", control: stylePopUp)
        appearanceStackView.addArrangedSubview(styleStack)

        // Long Lyrics Handling
        longLyricPopUp.addItems(withTitles: [
            "Smart Auto-Split (Bagi 2 Bagian Cerdas — Rapi di Touch Bar)",
            "Smooth Auto-Scroll (Marquee Halus)",
            "Auto-Fit Font (Kecilkan Ukuran Font Otomatis)",
            "Kalimat Utuh Penuh (Truncate Tail)"
        ])
        let longLyricStack = createSection(title: "Penanganan Lirik Panjang:", control: longLyricPopUp)
        appearanceStackView.addArrangedSubview(longLyricStack)

        // Color
        colorPopUp.addItems(withTitles: [
            "Auto (Adaptif Warna Album)",
            "Putih",
            "Emas",
            "Cyan",
            "Hijau",
            "Ungu",
            "Pink",
            "Oranye",
            "Merah"
        ])
        let colorStack = createSection(title: "Warna Sorotan Lirik:", control: colorPopUp)
        appearanceStackView.addArrangedSubview(colorStack)

        // Text Alignment & Font Size
        let alignStack = createSection(title: "Perataan Teks:", control: alignmentControl)
        appearanceStackView.addArrangedSubview(alignStack)

        let fontStack = createSection(title: "Ukuran Teks:", control: fontSizeControl)
        appearanceStackView.addArrangedSubview(fontStack)

        // Transition Animation
        animationPopUp.addItems(withTitles: [
            "Slide Up (Spotify Smooth)",
            "Smooth Crossfade",
            "Spring Pulse",
            "Instan (Tanpa Animasi)"
        ])
        let animStack = createSection(title: "Animasi Pergantian Baris:", control: animationPopUp)
        appearanceStackView.addArrangedSubview(animStack)

        mainStackView.addArrangedSubview(appearanceStackView)

        // ==========================================
        // 2. MEDIA & ARTWORK TAB
        // ==========================================
        mediaStackView.orientation = .vertical
        mediaStackView.alignment = .leading
        mediaStackView.spacing = 10
        mediaStackView.wantsLayer = true
        mediaStackView.isHidden = true

        playerPopUp.addItems(withTitles: [
            "Otomatis (Spotify, Apple Music, QuickTime, IINA, VLC)",
            "Spotify Saja",
            "Apple Music Saja",
            "QuickTime Player Saja",
            "IINA Saja",
            "VLC Media Player Saja"
        ])
        let playerStack = createSection(title: "Aplikasi Musik / Pemutar:", control: playerPopUp)
        mediaStackView.addArrangedSubview(playerStack)

        adAudioPopUp.addItems(withTitles: [
            "Auto Mute (100% Senyap)",
            "Auto Dim (Kecilkan Volume 10%)",
            "Normal (Biarkan Saja)"
        ])
        let adAudioStack = createSection(title: "Perlakuan Iklan Spotify:", control: adAudioPopUp)
        mediaStackView.addArrangedSubview(adAudioStack)

        mediaStackView.addArrangedSubview(albumArtCheckbox)

        let artSizeStack = createSection(title: "Ukuran Sampul Album:", control: albumArtSizeControl)
        mediaStackView.addArrangedSubview(artSizeStack)

        mediaStackView.addArrangedSubview(canvasCheckbox)
        mediaStackView.addArrangedSubview(trackInfoCheckbox)
        mediaStackView.addArrangedSubview(pauseIconCheckbox)

        mainStackView.addArrangedSubview(mediaStackView)

        // ==========================================
        // 3. SMART FEATURES & GESTURES TAB
        // ==========================================
        smartStackView.orientation = .vertical
        smartStackView.alignment = .leading
        smartStackView.spacing = 10
        smartStackView.wantsLayer = true
        smartStackView.isHidden = true

        smartStackView.addArrangedSubview(romanizeCheckbox)
        smartStackView.addArrangedSubview(equalizerCheckbox)
        smartStackView.addArrangedSubview(pitchVisualizerCheckbox)
        smartStackView.addArrangedSubview(menuBarCheckbox)
        smartStackView.addArrangedSubview(upNextCheckbox)
        smartStackView.addArrangedSubview(heartButtonCheckbox)
        smartStackView.addArrangedSubview(gesturesCheckbox)

        mainStackView.addArrangedSubview(smartStackView)

        // ==========================================
        // PERSISTENT FOOTER: CACHE & CREDITS
        // ==========================================
        let bottomSep = NSBox()
        bottomSep.boxType = .separator
        mainStackView.addArrangedSubview(bottomSep)

        let cacheStackView = NSStackView()
        cacheStackView.orientation = .horizontal
        cacheStackView.alignment = .centerY
        cacheStackView.spacing = 10

        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.target = self
        clearCacheButton.action = #selector(onClearCacheTapped)

        cacheStatusLabel.font = NSFont.systemFont(ofSize: 11)
        cacheStatusLabel.textColor = .secondaryLabelColor

        cacheStackView.addArrangedSubview(clearCacheButton)
        cacheStackView.addArrangedSubview(cacheStatusLabel)
        mainStackView.addArrangedSubview(cacheStackView)

        let creditsLabel = NSTextField(labelWithString: "Lirik Enhanced Edition v2.0 • Recoded by Miftah (MIT License)")
        creditsLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        creditsLabel.textColor = .tertiaryLabelColor
        mainStackView.addArrangedSubview(creditsLabel)

        // Wire Target Actions
        dualLineControl.target = self
        dualLineControl.action = #selector(onDualLineChanged)

        alignmentControl.target = self
        alignmentControl.action = #selector(onAlignmentChanged)

        fontSizeControl.target = self
        fontSizeControl.action = #selector(onFontSizeChanged)

        stylePopUp.target = self
        stylePopUp.action = #selector(onStyleChanged)

        longLyricPopUp.target = self
        longLyricPopUp.action = #selector(onLongLyricModeChanged)

        colorPopUp.target = self
        colorPopUp.action = #selector(onColorChanged)

        animationPopUp.target = self
        animationPopUp.action = #selector(onAnimationChanged)

        playerPopUp.target = self
        playerPopUp.action = #selector(onPlayerChanged)

        adAudioPopUp.target = self
        adAudioPopUp.action = #selector(onAdAudioChanged)

        pitchVisualizerCheckbox.target = self
        pitchVisualizerCheckbox.action = #selector(onPitchVisualizerChanged)

        menuBarCheckbox.target = self
        menuBarCheckbox.action = #selector(onMenuBarChanged)

        upNextCheckbox.target = self
        upNextCheckbox.action = #selector(onUpNextChanged)

        romanizeCheckbox.target = self
        romanizeCheckbox.action = #selector(onRomanizeChanged)

        heartButtonCheckbox.target = self
        heartButtonCheckbox.action = #selector(onHeartButtonChanged)

        equalizerCheckbox.target = self
        equalizerCheckbox.action = #selector(onEqualizerCheckboxChanged)

        canvasCheckbox.target = self
        canvasCheckbox.action = #selector(onCanvasCheckboxChanged)

        gesturesCheckbox.target = self
        gesturesCheckbox.action = #selector(onGesturesChanged)

        pauseIconCheckbox.target = self
        pauseIconCheckbox.action = #selector(onPauseCheckboxChanged)

        albumArtCheckbox.target = self
        albumArtCheckbox.action = #selector(onAlbumArtCheckboxChanged)

        albumArtSizeControl.target = self
        albumArtSizeControl.action = #selector(onAlbumArtSizeChanged)

        trackInfoCheckbox.target = self
        trackInfoCheckbox.action = #selector(onTrackInfoCheckboxChanged)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 520))
        mainStackView.frame = container.bounds
        mainStackView.autoresizingMask = [.width, .height]
        container.addSubview(mainStackView)

        self.view = container
    }

    private func createSection(title: String, control: NSView) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(control)
        return stack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadPreferences()
        updateCacheStatus()
    }

    // MARK: - Category Tab Switching

    @objc private func onCategoryChanged() {
        let selected = categorySegmentControl.selectedSegment
        appearanceStackView.isHidden = (selected != 0)
        mediaStackView.isHidden = (selected != 1)
        smartStackView.isHidden = (selected != 2)
    }

    // MARK: - Load Preferences

    private func loadPreferences() {
        let defaults = UserDefaults.standard

        let dualLine = defaults.object(forKey: Self.keyDualLine) as? Bool ?? true
        dualLineControl.selectedSegment = dualLine ? 0 : 1

        let align = defaults.string(forKey: Self.keyAlignment) ?? "left"
        alignmentControl.selectedSegment = (align == "center") ? 1 : 0

        let fontSize = defaults.object(forKey: Self.keyFontSize) as? Int ?? 11
        if fontSize <= 10 {
            fontSizeControl.selectedSegment = 0
        } else if fontSize >= 12 {
            fontSizeControl.selectedSegment = 2
        } else {
            fontSizeControl.selectedSegment = 1
        }

        let style = defaults.string(forKey: Self.keyLyricHighlightStyle) ?? "wordBlock"
        switch style {
        case "lineFocus": stylePopUp.selectItem(at: 1)
        case "wordPill": stylePopUp.selectItem(at: 2)
        case "smoothSweep": stylePopUp.selectItem(at: 3)
        default: stylePopUp.selectItem(at: 0) // wordBlock
        }

        let longMode = defaults.string(forKey: Self.keyLongLyricMode) ?? "smartSplit"
        switch longMode {
        case "marquee": longLyricPopUp.selectItem(at: 1)
        case "autoFit": longLyricPopUp.selectItem(at: 2)
        case "truncate": longLyricPopUp.selectItem(at: 3)
        default: longLyricPopUp.selectItem(at: 0) // smartSplit
        }

        let color = defaults.string(forKey: Self.keyHighlightColor) ?? "album"
        switch color {
        case "white": colorPopUp.selectItem(at: 1)
        case "gold": colorPopUp.selectItem(at: 2)
        case "cyan": colorPopUp.selectItem(at: 3)
        case "green": colorPopUp.selectItem(at: 4)
        case "purple": colorPopUp.selectItem(at: 5)
        case "pink": colorPopUp.selectItem(at: 6)
        case "orange": colorPopUp.selectItem(at: 7)
        case "red": colorPopUp.selectItem(at: 8)
        default: colorPopUp.selectItem(at: 0)
        }

        let anim = defaults.string(forKey: Self.keyLyricAnimation) ?? "slide"
        switch anim {
        case "fade": animationPopUp.selectItem(at: 1)
        case "pop": animationPopUp.selectItem(at: 2)
        case "instant": animationPopUp.selectItem(at: 3)
        default: animationPopUp.selectItem(at: 0)
        }

        let player = defaults.string(forKey: Self.keyPreferredPlayer) ?? "auto"
        if player == "spotify" {
            playerPopUp.selectItem(at: 1)
        } else if player == "music" {
            playerPopUp.selectItem(at: 2)
        } else if player == "quicktime" {
            playerPopUp.selectItem(at: 3)
        } else if player == "iina" {
            playerPopUp.selectItem(at: 4)
        } else if player == "vlc" {
            playerPopUp.selectItem(at: 5)
        } else {
            playerPopUp.selectItem(at: 0)
        }

        let adAudio = defaults.string(forKey: Self.keyAdAudioBehavior) ?? "dim"
        if adAudio == "mute" {
            adAudioPopUp.selectItem(at: 0)
        } else if adAudio == "none" {
            adAudioPopUp.selectItem(at: 2)
        } else {
            adAudioPopUp.selectItem(at: 1) // dim
        }

        let pitchVisualizer = defaults.object(forKey: Self.keyShowPitchVisualizer) as? Bool ?? true
        pitchVisualizerCheckbox.state = pitchVisualizer ? .on : .off

        let menuBar = defaults.object(forKey: Self.keyEnableMenuBarLyrics) as? Bool ?? true
        menuBarCheckbox.state = menuBar ? .on : .off

        let upNext = defaults.object(forKey: Self.keyEnableUpNextCountdown) as? Bool ?? true
        upNextCheckbox.state = upNext ? .on : .off

        let romanize = defaults.object(forKey: Self.keyEnableRomanization) as? Bool ?? true
        romanizeCheckbox.state = romanize ? .on : .off

        let heart = defaults.object(forKey: Self.keyShowHeartButton) as? Bool ?? true
        heartButtonCheckbox.state = heart ? .on : .off

        let showEq = defaults.object(forKey: Self.keyShowEqualizer) as? Bool ?? true
        equalizerCheckbox.state = showEq ? .on : .off

        let showCanvas = defaults.object(forKey: Self.keyEnableCanvas) as? Bool ?? true
        canvasCheckbox.state = showCanvas ? .on : .off

        let gestures = defaults.object(forKey: Self.keyEnableGestures) as? Bool ?? true
        gesturesCheckbox.state = gestures ? .on : .off

        let showPause = defaults.object(forKey: Self.keyShowPauseIcon) as? Bool ?? true
        pauseIconCheckbox.state = showPause ? .on : .off

        let showArt = defaults.object(forKey: Self.keyShowAlbumArt) as? Bool ?? true
        albumArtCheckbox.state = showArt ? .on : .off

        let artSize = defaults.object(forKey: Self.keyAlbumArtSize) as? Int ?? 1
        albumArtSizeControl.selectedSegment = max(0, min(artSize, 2))

        let showTrackInfo = defaults.object(forKey: Self.keyShowTrackInfo) as? Bool ?? false
        trackInfoCheckbox.state = showTrackInfo ? .on : .off
    }

    // MARK: - Action Handlers

    @objc private func onDualLineChanged() {
        let isDual = dualLineControl.selectedSegment == 0
        UserDefaults.standard.set(isDual, forKey: Self.keyDualLine)
    }

    @objc private func onAlignmentChanged() {
        let align = (alignmentControl.selectedSegment == 1) ? "center" : "left"
        UserDefaults.standard.set(align, forKey: Self.keyAlignment)
    }

    @objc private func onFontSizeChanged() {
        let size: Int
        switch fontSizeControl.selectedSegment {
        case 0: size = 10
        case 2: size = 13
        default: size = 11
        }
        UserDefaults.standard.set(size, forKey: Self.keyFontSize)
    }

    @objc private func onStyleChanged() {
        let style: String
        switch stylePopUp.indexOfSelectedItem {
        case 1: style = "lineFocus"
        case 2: style = "wordPill"
        case 3: style = "smoothSweep"
        default: style = "wordBlock"
        }
        UserDefaults.standard.set(style, forKey: Self.keyLyricHighlightStyle)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.highlightStyleChanged"), object: nil)
    }

    @objc private func onLongLyricModeChanged() {
        let mode: String
        switch longLyricPopUp.indexOfSelectedItem {
        case 1: mode = "marquee"
        case 2: mode = "autoFit"
        case 3: mode = "truncate"
        default: mode = "smartSplit"
        }
        UserDefaults.standard.set(mode, forKey: Self.keyLongLyricMode)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.longLyricModeChanged"), object: nil)
    }

    @objc private func onColorChanged() {
        let color: String
        switch colorPopUp.indexOfSelectedItem {
        case 1: color = "white"
        case 2: color = "gold"
        case 3: color = "cyan"
        case 4: color = "green"
        case 5: color = "purple"
        case 6: color = "pink"
        case 7: color = "orange"
        case 8: color = "red"
        default: color = "album"
        }
        UserDefaults.standard.set(color, forKey: Self.keyHighlightColor)
    }

    @objc private func onAnimationChanged() {
        let anim: String
        switch animationPopUp.indexOfSelectedItem {
        case 1: anim = "fade"
        case 2: anim = "pop"
        case 3: anim = "instant"
        default: anim = "slide"
        }
        UserDefaults.standard.set(anim, forKey: Self.keyLyricAnimation)
    }

    @objc private func onPlayerChanged() {
        let player: String
        switch playerPopUp.indexOfSelectedItem {
        case 1: player = "spotify"
        case 2: player = "music"
        case 3: player = "quicktime"
        case 4: player = "iina"
        case 5: player = "vlc"
        default: player = "auto"
        }
        UserDefaults.standard.set(player, forKey: Self.keyPreferredPlayer)
    }

    @objc private func onAdAudioChanged() {
        let behavior: String
        switch adAudioPopUp.indexOfSelectedItem {
        case 0: behavior = "mute"
        case 2: behavior = "none"
        default: behavior = "dim"
        }
        UserDefaults.standard.set(behavior, forKey: Self.keyAdAudioBehavior)
    }

    @objc private func onPitchVisualizerChanged() {
        let show = pitchVisualizerCheckbox.state == .on
        UserDefaults.standard.set(show, forKey: Self.keyShowPitchVisualizer)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.pitchVisualizerChanged"), object: nil)
    }

    @objc private func onMenuBarChanged() {
        let enable = menuBarCheckbox.state == .on
        UserDefaults.standard.set(enable, forKey: Self.keyEnableMenuBarLyrics)
        MenuBarLyricsController.shared.setEnabled(enable)
    }

    @objc private func onUpNextChanged() {
        let enable = upNextCheckbox.state == .on
        UserDefaults.standard.set(enable, forKey: Self.keyEnableUpNextCountdown)
    }

    @objc private func onRomanizeChanged() {
        let romanize = romanizeCheckbox.state == .on
        UserDefaults.standard.set(romanize, forKey: Self.keyEnableRomanization)
    }

    @objc private func onHeartButtonChanged() {
        let heart = heartButtonCheckbox.state == .on
        UserDefaults.standard.set(heart, forKey: Self.keyShowHeartButton)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.heartButtonChanged"), object: nil)
    }

    @objc private func onEqualizerCheckboxChanged() {
        let show = equalizerCheckbox.state == .on
        UserDefaults.standard.set(show, forKey: Self.keyShowEqualizer)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.equalizerChanged"), object: nil)
    }

    @objc private func onCanvasCheckboxChanged() {
        let enable = canvasCheckbox.state == .on
        UserDefaults.standard.set(enable, forKey: Self.keyEnableCanvas)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.canvasChanged"), object: nil)
    }

    @objc private func onGesturesChanged() {
        let enable = gesturesCheckbox.state == .on
        UserDefaults.standard.set(enable, forKey: Self.keyEnableGestures)
    }

    @objc private func onPauseCheckboxChanged() {
        let show = pauseIconCheckbox.state == .on
        UserDefaults.standard.set(show, forKey: Self.keyShowPauseIcon)
    }

    @objc private func onAlbumArtCheckboxChanged() {
        let show = albumArtCheckbox.state == .on
        UserDefaults.standard.set(show, forKey: Self.keyShowAlbumArt)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.albumArtChanged"), object: nil)
    }

    @objc private func onAlbumArtSizeChanged() {
        let size = albumArtSizeControl.selectedSegment
        UserDefaults.standard.set(size, forKey: Self.keyAlbumArtSize)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.albumArtChanged"), object: nil)
    }

    @objc private func onTrackInfoCheckboxChanged() {
        let show = trackInfoCheckbox.state == .on
        UserDefaults.standard.set(show, forKey: Self.keyShowTrackInfo)
    }

    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.keyDualLine)
        defaults.removeObject(forKey: Self.keyFontSize)
        defaults.removeObject(forKey: Self.keyPreferredPlayer)
        defaults.removeObject(forKey: Self.keyShowPauseIcon)
        defaults.removeObject(forKey: Self.keyHighlightColor)
        defaults.removeObject(forKey: Self.keyLyricAnimation)
        defaults.removeObject(forKey: Self.keyEnableKaraokeGlow)
        defaults.removeObject(forKey: Self.keyLyricHighlightStyle)
        defaults.removeObject(forKey: Self.keyLongLyricMode)
        defaults.removeObject(forKey: Self.keyShowPitchVisualizer)
        defaults.removeObject(forKey: Self.keyEnableMenuBarLyrics)
        defaults.removeObject(forKey: Self.keyEnableUpNextCountdown)
        defaults.removeObject(forKey: Self.keyAdAudioBehavior)
        defaults.removeObject(forKey: Self.keyEnableRomanization)
        defaults.removeObject(forKey: Self.keyShowHeartButton)
        defaults.removeObject(forKey: Self.keyAlignment)
        defaults.removeObject(forKey: Self.keyEnableMarquee)
        defaults.removeObject(forKey: Self.keyShowAlbumArt)
        defaults.removeObject(forKey: Self.keyEnableCanvas)
        defaults.removeObject(forKey: Self.keyEnableGestures)
        defaults.removeObject(forKey: Self.keyShowEqualizer)
        defaults.removeObject(forKey: Self.keyAlbumArtSize)
        defaults.removeObject(forKey: Self.keyShowTrackInfo)
        loadPreferences()
    }

    @objc private func onClearCacheTapped() {
        lyricsCache.clear()
        OfflineLyricsVault.shared.clearVault()
        updateCacheStatus()
        cacheStatusLabel.stringValue = "Vault & Cache dibersihkan!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateCacheStatus()
        }
    }

    private func updateCacheStatus() {
        let memoryCount = lyricsCache.count
        let vaultCount = OfflineLyricsVault.shared.totalSongsInVault
        let total = max(memoryCount, vaultCount)
        cacheStatusLabel.stringValue = "Vault: \(total) lagu tersimpan offline"
    }
}

