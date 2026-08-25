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

    // MARK: - UserDefault Keys

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
    static let keyEnableRomanization = "io.github.ridhaaf.lirik.enableRomanization"
    static let keyShowHeartButton = "io.github.ridhaaf.lirik.showHeartButton"
    static let keyEnableGestures = "io.github.ridhaaf.lirik.enableGestures"
    static let keyAdAudioBehavior = "io.github.ridhaaf.lirik.adAudioBehavior"
    static let keyEnableUpNextCountdown = "io.github.ridhaaf.lirik.enableUpNextCountdown"
    static let keyEnableMenuBarLyrics = "io.github.ridhaaf.lirik.enableMenuBarLyrics"

    // MARK: - UI Controls

    private let dualLineControl = NSSegmentedControl(labels: ["2-Line Karaoke", "1-Line Compact"], trackingMode: .selectOne, target: nil, action: nil)
    private let fontSizeControl = NSSegmentedControl(labels: ["Small", "Medium", "Large"], trackingMode: .selectOne, target: nil, action: nil)
    private let stylePopUp = NSPopUpButton()
    private let colorPopUp = NSPopUpButton()
    private let animationPopUp = NSPopUpButton()
    private let alignmentControl = NSSegmentedControl(labels: ["Left Aligned", "Center Aligned"], trackingMode: .selectOne, target: nil, action: nil)
    private let playerPopUp = NSPopUpButton()
    private let adAudioPopUp = NSPopUpButton()

    private let karaokeGlowCheckbox = NSButton(checkboxWithTitle: "Enable progressive karaoke character sweep (default: Apple Music Line Focus)", target: nil, action: nil)
    private let pitchVisualizerCheckbox = NSButton(checkboxWithTitle: "Show live vocal pitch & melody meter (Feature 7)", target: nil, action: nil)
    private let menuBarCheckbox = NSButton(checkboxWithTitle: "Show live lyrics in macOS Menu Bar ticker (Feature 4)", target: nil, action: nil)
    private let upNextCheckbox = NSButton(checkboxWithTitle: "Show 'Up Next' outro countdown & transition preview", target: nil, action: nil)
    private let romanizeCheckbox = NSButton(checkboxWithTitle: "Auto-romanize Japanese, Korean & Chinese lyrics", target: nil, action: nil)
    private let heartButtonCheckbox = NSButton(checkboxWithTitle: "Show Like button on Touch Bar", target: nil, action: nil)
    private let equalizerCheckbox = NSButton(checkboxWithTitle: "Show animated audio equalizer spectrum", target: nil, action: nil)
    private let canvasCheckbox = NSButton(checkboxWithTitle: "Enable Spotify Canvas video looping", target: nil, action: nil)
    private let gesturesCheckbox = NSButton(checkboxWithTitle: "Enable two-finger gestures (Track Skip & Volume)", target: nil, action: nil)
    private let pauseIconCheckbox = NSButton(checkboxWithTitle: "Show pause indicator when track is paused", target: nil, action: nil)
    private let marqueeCheckbox = NSButton(checkboxWithTitle: "Enable marquee scrolling for long lines", target: nil, action: nil)
    private let albumArtCheckbox = NSButton(checkboxWithTitle: "Show album artwork / Canvas thumbnail", target: nil, action: nil)
    private let albumArtSizeControl = NSSegmentedControl(labels: ["Small", "Medium", "Large"], trackingMode: .selectOne, target: nil, action: nil)
    private let trackInfoCheckbox = NSButton(checkboxWithTitle: "Show track info badge on song change", target: nil, action: nil)

    private let clearCacheButton = NSButton(title: "Clear Offline Vault & Cache", target: nil, action: nil)
    private let cacheStatusLabel = NSTextField(labelWithString: "")

    private let lyricsCache = LyricsCache()

    override func loadView() {
        let mainStackView = NSStackView()
        mainStackView.orientation = .vertical
        mainStackView.alignment = .leading
        mainStackView.spacing = 10
        mainStackView.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)

        // Title Header
        let titleLabel = NSTextField(labelWithString: "Lirik Preferences")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        mainStackView.addArrangedSubview(titleLabel)

        // 1. Display Mode (2-Line vs 1-Line)
        let modeStackView = createSection(title: "Display Mode:", control: dualLineControl)
        mainStackView.addArrangedSubview(modeStackView)

        // 2. Alignment
        let alignStackView = createSection(title: "Text Alignment:", control: alignmentControl)
        mainStackView.addArrangedSubview(alignStackView)

        // 3. Font Size
        let fontStackView = createSection(title: "Lyric Text Size:", control: fontSizeControl)
        mainStackView.addArrangedSubview(fontStackView)

        // 4. Highlight Style
        stylePopUp.addItems(withTitles: [
            "Apple Music Line Focus (Active Line Glow)",
            "Word Snap (Seblok Kata Utuh)",
            "Word Pill (Kapsul Kata Bercahaya)",
            "Smooth Karaoke Sweep (Wipe Progresif)"
        ])
        let styleStackView = createSection(title: "Lyric Highlight Style:", control: stylePopUp)
        mainStackView.addArrangedSubview(styleStackView)

        // 5. Highlight Color
        colorPopUp.addItems(withTitles: [
            "Auto (Album Adaptive)",
            "White",
            "Gold",
            "Cyan",
            "Green",
            "Purple",
            "Pink",
            "Orange",
            "Red"
        ])
        let colorStackView = createSection(title: "Lyric Highlight Color:", control: colorPopUp)
        mainStackView.addArrangedSubview(colorStackView)

        // 5. Lyric Transition Animation
        animationPopUp.addItems(withTitles: [
            "Slide Up (Spotify Smooth)",
            "Smooth Crossfade",
            "Spring Pulse",
            "Instant (No Animation)"
        ])
        let animStackView = createSection(title: "Lyric Transition Animation:", control: animationPopUp)
        mainStackView.addArrangedSubview(animStackView)

        // 6. Preferred Player
        playerPopUp.addItems(withTitles: [
            "Auto-detect (Spotify, Music, QuickTime, IINA, VLC)",
            "Spotify Only",
            "Apple Music Only",
            "QuickTime Player Only",
            "IINA Only",
            "VLC Media Player Only"
        ])
        let playerStackView = createSection(title: "Music / Media Player:", control: playerPopUp)
        mainStackView.addArrangedSubview(playerStackView)

        // 7. Spotify Ads Audio Behavior (Auto Mute / Dim)
        adAudioPopUp.addItems(withTitles: [
            "Auto Dim (Whisper Volume 10%)",
            "Auto Mute (100% Silent)",
            "Normal (Do Nothing)"
        ])
        let adAudioStackView = createSection(title: "Spotify Ads Audio Behavior:", control: adAudioPopUp)
        mainStackView.addArrangedSubview(adAudioStackView)

        // 8. Checkboxes
        mainStackView.addArrangedSubview(karaokeGlowCheckbox)
        mainStackView.addArrangedSubview(pitchVisualizerCheckbox)
        mainStackView.addArrangedSubview(menuBarCheckbox)
        mainStackView.addArrangedSubview(upNextCheckbox)
        mainStackView.addArrangedSubview(romanizeCheckbox)
        mainStackView.addArrangedSubview(heartButtonCheckbox)
        mainStackView.addArrangedSubview(equalizerCheckbox)
        mainStackView.addArrangedSubview(canvasCheckbox)
        mainStackView.addArrangedSubview(gesturesCheckbox)
        mainStackView.addArrangedSubview(pauseIconCheckbox)
        mainStackView.addArrangedSubview(marqueeCheckbox)
        mainStackView.addArrangedSubview(albumArtCheckbox)

        // Album Art Size
        let artSizeStackView = createSection(title: "Album Artwork Size:", control: albumArtSizeControl)
        mainStackView.addArrangedSubview(artSizeStackView)

        mainStackView.addArrangedSubview(trackInfoCheckbox)

        // 9. Clear Cache Button
        let cacheStackView = NSStackView()
        cacheStackView.orientation = .horizontal
        cacheStackView.alignment = .centerY
        cacheStackView.spacing = 8
        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.target = self
        clearCacheButton.action = #selector(onClearCacheTapped)
        cacheStatusLabel.font = NSFont.systemFont(ofSize: 11)
        cacheStatusLabel.textColor = .secondaryLabelColor
        cacheStackView.addArrangedSubview(clearCacheButton)
        cacheStackView.addArrangedSubview(cacheStatusLabel)
        mainStackView.addArrangedSubview(cacheStackView)

        // 10. Edition & Credits Badge
        let separator = NSBox()
        separator.boxType = .separator
        mainStackView.addArrangedSubview(separator)

        let creditsLabel = NSTextField(labelWithString: "Lirik Enhanced Edition v2.0 • Recoded by Miftah\nOriginal Project by RidhaAF (Licensed under MIT)")
        creditsLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        creditsLabel.textColor = .tertiaryLabelColor
        creditsLabel.alignment = .center
        mainStackView.addArrangedSubview(creditsLabel)

        // Target actions
        dualLineControl.target = self
        dualLineControl.action = #selector(onDualLineChanged)

        alignmentControl.target = self
        alignmentControl.action = #selector(onAlignmentChanged)

        fontSizeControl.target = self
        fontSizeControl.action = #selector(onFontSizeChanged)

        stylePopUp.target = self
        stylePopUp.action = #selector(onStyleChanged)

        colorPopUp.target = self
        colorPopUp.action = #selector(onColorChanged)

        animationPopUp.target = self
        animationPopUp.action = #selector(onAnimationChanged)

        playerPopUp.target = self
        playerPopUp.action = #selector(onPlayerChanged)

        adAudioPopUp.target = self
        adAudioPopUp.action = #selector(onAdAudioChanged)

        karaokeGlowCheckbox.target = self
        karaokeGlowCheckbox.action = #selector(onKaraokeGlowChanged)

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

        marqueeCheckbox.target = self
        marqueeCheckbox.action = #selector(onMarqueeCheckboxChanged)

        albumArtCheckbox.target = self
        albumArtCheckbox.action = #selector(onAlbumArtCheckboxChanged)

        albumArtSizeControl.target = self
        albumArtSizeControl.action = #selector(onAlbumArtSizeChanged)

        trackInfoCheckbox.target = self
        trackInfoCheckbox.action = #selector(onTrackInfoCheckboxChanged)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 800))
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

        let style = defaults.string(forKey: Self.keyLyricHighlightStyle) ?? "lineFocus"
        switch style {
        case "wordBlock": stylePopUp.selectItem(at: 1)
        case "wordPill": stylePopUp.selectItem(at: 2)
        case "smoothSweep": stylePopUp.selectItem(at: 3)
        default: stylePopUp.selectItem(at: 0)
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
            adAudioPopUp.selectItem(at: 1)
        } else if adAudio == "none" {
            adAudioPopUp.selectItem(at: 2)
        } else {
            adAudioPopUp.selectItem(at: 0)
        }

        let karaokeGlow = defaults.object(forKey: Self.keyEnableKaraokeGlow) as? Bool ?? false
        karaokeGlowCheckbox.state = karaokeGlow ? .on : .off

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

        let marquee = defaults.object(forKey: Self.keyEnableMarquee) as? Bool ?? false
        marqueeCheckbox.state = marquee ? .on : .off

        let showArt = defaults.object(forKey: Self.keyShowAlbumArt) as? Bool ?? true
        albumArtCheckbox.state = showArt ? .on : .off

        let artSize = defaults.object(forKey: Self.keyAlbumArtSize) as? Int ?? 1
        albumArtSizeControl.selectedSegment = max(0, min(artSize, 2))

        let showTrackInfo = defaults.object(forKey: Self.keyShowTrackInfo) as? Bool ?? false
        trackInfoCheckbox.state = showTrackInfo ? .on : .off
    }

    // MARK: - Action Handlers

    @objc private func onAdAudioChanged() {
        let behavior: String
        switch adAudioPopUp.indexOfSelectedItem {
        case 1: behavior = "mute"
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
        case 1: style = "wordBlock"
        case 2: style = "wordPill"
        case 3: style = "smoothSweep"
        default: style = "lineFocus"
        }
        UserDefaults.standard.set(style, forKey: Self.keyLyricHighlightStyle)
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.highlightStyleChanged"), object: nil)
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

    @objc private func onKaraokeGlowChanged() {
        let glow = karaokeGlowCheckbox.state == .on
        UserDefaults.standard.set(glow, forKey: Self.keyEnableKaraokeGlow)
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

    @objc private func onMarqueeCheckboxChanged() {
        let enable = marqueeCheckbox.state == .on
        UserDefaults.standard.set(enable, forKey: Self.keyEnableMarquee)
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
        cacheStatusLabel.stringValue = "Vault & Cache cleared!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateCacheStatus()
        }
    }

    private func updateCacheStatus() {
        let memoryCount = lyricsCache.count
        let vaultCount = OfflineLyricsVault.shared.totalSongsInVault
        let total = max(memoryCount, vaultCount)
        cacheStatusLabel.stringValue = "Vault: \(total) song\(total == 1 ? "" : "s") cached"
    }
}
