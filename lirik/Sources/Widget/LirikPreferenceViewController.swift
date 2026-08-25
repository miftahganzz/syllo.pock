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

@objc(SylloPreferenceViewController)
class SylloPreferenceViewController: NSViewController, PKWidgetPreference {

    static var nibName: NSNib.Name = NSNib.Name("SylloPreferenceViewController")

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

    static let keyLanguage = "io.github.ridhaaf.lirik.language"
    static let keyDualLine = "io.github.ridhaaf.lirik.dualLine"
    static let keyEnableHighlight = "io.github.ridhaaf.lirik.enableHighlight"
    static let keyLyricHighlightStyle = "io.github.ridhaaf.lirik.lyricHighlightStyle"
    static let keyLyricAnimation = "io.github.ridhaaf.lirik.lyricAnimation"
    static let keyLongLyricMode = "io.github.ridhaaf.lirik.longLyricMode"
    static let keyHighlightColor = "io.github.ridhaaf.lirik.highlightColor"
    static let keyAlignment = "io.github.ridhaaf.lirik.alignment"
    static let keyFontSize = "io.github.ridhaaf.lirik.fontSize"

    static let keyPreferredPlayer = "io.github.ridhaaf.lirik.preferredPlayer"
    static let keyAdAudioBehavior = "io.github.ridhaaf.lirik.adAudioBehavior"
    static let keyShowAlbumArt = "io.github.ridhaaf.lirik.showAlbumArt"
    static let keyAlbumArtSize = "io.github.ridhaaf.lirik.albumArtSize"
    static let keyEnableCanvas = "io.github.ridhaaf.lirik.enableCanvas"
    static let keyShowTrackInfo = "io.github.ridhaaf.lirik.showTrackInfo"
    static let keyShowPauseIcon = "io.github.ridhaaf.lirik.showPauseIcon"

    static let keyEnableRomanization = "io.github.ridhaaf.lirik.enableRomanization"
    static let keyShowEqualizer = "io.github.ridhaaf.lirik.showEqualizer"
    static let keyShowPitchVisualizer = "io.github.ridhaaf.lirik.showPitchVisualizer"
    static let keyEnableMenuBarLyrics = "io.github.ridhaaf.lirik.enableMenuBarLyrics"
    static let keyEnableUpNextCountdown = "io.github.ridhaaf.lirik.enableUpNextCountdown"
    static let keyShowHeartButton = "io.github.ridhaaf.lirik.showHeartButton"
    static let keyEnableGestures = "io.github.ridhaaf.lirik.enableGestures"
    static let keyEnableMarquee = "io.github.ridhaaf.lirik.enableMarquee"
    static let keyEnableKaraokeGlow = "io.github.ridhaaf.lirik.enableKaraokeGlow"

    // MARK: - Language State

    private var isIndonesian: Bool {
        let lang = UserDefaults.standard.string(forKey: Self.keyLanguage) ?? "id"
        return lang == "id"
    }

    // MARK: - Top Header & Navigation

    private let titleLabel = NSTextField(labelWithString: "Syllo Preferences")
    private let badgeLabel = NSTextField(labelWithString: "v2.0")
    private let languageControl = NSSegmentedControl(labels: ["ID", "EN"], trackingMode: .selectOne, target: nil, action: nil)

    private let tabSegment = NSSegmentedControl(
        labels: ["Tampilan & Lirik", "Media & Player", "Fitur Cerdas"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private let pageContainer = NSView()
    private var pageViews: [NSView] = []

    // MARK: - Page 1 Controls (Appearance & Style)

    private let dualLineControl = NSSegmentedControl(labels: ["2-Baris", "1-Baris"], trackingMode: .selectOne, target: nil, action: nil)
    private let highlightControl = NSSegmentedControl(labels: ["Aktif", "Nonaktif"], trackingMode: .selectOne, target: nil, action: nil)
    private let stylePopUp = NSPopUpButton()
    private let animationPopUp = NSPopUpButton()
    private let longLyricPopUp = NSPopUpButton()

    private let colorPopUp = NSPopUpButton()
    private let alignmentControl = NSSegmentedControl(labels: ["Kiri", "Tengah"], trackingMode: .selectOne, target: nil, action: nil)
    private let fontSizeControl = NSSegmentedControl(labels: ["Kecil", "Sedang", "Besar"], trackingMode: .selectOne, target: nil, action: nil)

    // Labels for Page 1
    private let modeLabel = NSTextField(labelWithString: "Mode:")
    private let highlightLabel = NSTextField(labelWithString: "Sorotan Lirik:")
    private let styleLabel = NSTextField(labelWithString: "Gaya Sorotan:")
    private let animLabel = NSTextField(labelWithString: "Animasi Baris:")
    private let longLyricLabel = NSTextField(labelWithString: "Lirik Panjang:")

    private let colorLabel = NSTextField(labelWithString: "Warna Sorotan:")
    private let alignLabel = NSTextField(labelWithString: "Perataan Teks:")
    private let fontLabel = NSTextField(labelWithString: "Ukuran Teks:")

    // MARK: - Page 2 Controls (Media & Player)

    private let playerPopUp = NSPopUpButton()
    private let adAudioPopUp = NSPopUpButton()
    private let albumArtCheckbox = NSButton(checkboxWithTitle: "Sampul Album", target: nil, action: nil)
    private let albumArtSizeControl = NSSegmentedControl(labels: ["Kecil", "Sedang", "Besar"], trackingMode: .selectOne, target: nil, action: nil)
    private let canvasCheckbox = NSButton(checkboxWithTitle: "Spotify Canvas Looping", target: nil, action: nil)
    private let trackInfoCheckbox = NSButton(checkboxWithTitle: "Badge Info Lagu", target: nil, action: nil)
    private let pauseIconCheckbox = NSButton(checkboxWithTitle: "Ikon Jeda (⏸ / ❙❙)", target: nil, action: nil)

    private let playerLabel = NSTextField(labelWithString: "Pemutar Musik:")
    private let adAudioLabel = NSTextField(labelWithString: "Iklan Spotify:")
    private let artSizeLabel = NSTextField(labelWithString: "Ukuran Sampul:")

    // MARK: - Page 3 Controls (Smart Features)

    private let romanizeCheckbox = NSButton(checkboxWithTitle: "Auto-Romanisasi (KR/JP/CN)", target: nil, action: nil)
    private let equalizerCheckbox = NSButton(checkboxWithTitle: "Spektrum Audio Equalizer", target: nil, action: nil)
    private let pitchVisualizerCheckbox = NSButton(checkboxWithTitle: "Vocal Pitch & Melody Meter", target: nil, action: nil)
    private let menuBarCheckbox = NSButton(checkboxWithTitle: "Lirik di macOS Menu Bar", target: nil, action: nil)
    private let upNextCheckbox = NSButton(checkboxWithTitle: "Hitung Mundur 'Up Next'", target: nil, action: nil)
    private let heartButtonCheckbox = NSButton(checkboxWithTitle: "Tombol Suka (❤️) Touch Bar", target: nil, action: nil)
    private let gesturesCheckbox = NSButton(checkboxWithTitle: "Gestur 2-Jari (Skip & Vol)", target: nil, action: nil)

    // MARK: - Card Headers (for dynamic translation)
    private var cardHeaders: [(label: NSTextField, idKey: String, enKey: String)] = []

    // MARK: - Persistent Footer

    private let clearCacheButton = NSButton(title: "Hapus Vault & Cache", target: nil, action: nil)
    private let cacheStatusLabel = NSTextField(labelWithString: "")
    private let creditsLabel = NSTextField(labelWithString: "Syllo v2.0 • Originally based on Lirik by RidhaAF • Recoded & Enhanced by Miftah (MIT License)")
    private let lyricsCache = LyricsCache()

    // MARK: - View Lifecycle

    override func loadView() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 10
        mainStack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

        // 1. Top Header Row: Title + Version Badge + Language Selector
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8

        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)

        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textColor = .secondaryLabelColor

        languageControl.segmentStyle = .texturedRounded
        languageControl.target = self
        languageControl.action = #selector(onLanguageChanged)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        topRow.addArrangedSubview(titleLabel)
        topRow.addArrangedSubview(badgeLabel)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(languageControl)
        mainStack.addArrangedSubview(topRow)

        // 2. Segmented Tab Switcher with SF Symbols
        tabSegment.target = self
        tabSegment.action = #selector(onTabChanged(_:))
        tabSegment.selectedSegment = 0
        tabSegment.segmentStyle = .texturedRounded

        let tabConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        if let icon1 = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil)?.withSymbolConfiguration(tabConfig) {
            tabSegment.setImage(icon1, forSegment: 0)
        }
        if let icon2 = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(tabConfig) {
            tabSegment.setImage(icon2, forSegment: 1)
        }
        if let icon3 = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?.withSymbolConfiguration(tabConfig) {
            tabSegment.setImage(icon3, forSegment: 2)
        }
        mainStack.addArrangedSubview(tabSegment)

        // 3. Build Page Views
        let page1 = buildAppearancePage()
        let page2 = buildMediaPage()
        let page3 = buildSmartFeaturesPage()
        pageViews = [page1, page2, page3]

        pageContainer.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(pageContainer)

        // 4. Persistent Footer: Cache Vault & Credits
        let bottomSep = NSBox()
        bottomSep.boxType = .separator
        mainStack.addArrangedSubview(bottomSep)

        let footerStack = NSStackView()
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 8

        clearCacheButton.bezelStyle = .rounded
        clearCacheButton.font = NSFont.systemFont(ofSize: 11)
        clearCacheButton.target = self
        clearCacheButton.action = #selector(onClearCacheTapped)

        cacheStatusLabel.font = NSFont.systemFont(ofSize: 11)
        cacheStatusLabel.textColor = .secondaryLabelColor

        footerStack.addArrangedSubview(clearCacheButton)
        footerStack.addArrangedSubview(cacheStatusLabel)
        mainStack.addArrangedSubview(footerStack)

        creditsLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        creditsLabel.textColor = .tertiaryLabelColor
        mainStack.addArrangedSubview(creditsLabel)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 440))
        mainStack.frame = container.bounds
        mainStack.autoresizingMask = [.width, .height]
        container.addSubview(mainStack)

        NSLayoutConstraint.activate([
            topRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -28),
            tabSegment.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -28),
            pageContainer.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -28),
            pageContainer.heightAnchor.constraint(equalToConstant: 285),
            bottomSep.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -28),
            footerStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -28)
        ])

        self.view = container
        wireActions()
        updateLocalization()
        showPage(0)
    }

    // MARK: - Tab Switching

    @objc private func onTabChanged(_ sender: NSSegmentedControl) {
        showPage(sender.selectedSegment)
    }

    private func showPage(_ index: Int) {
        pageContainer.subviews.forEach { $0.removeFromSuperview() }
        guard index >= 0, index < pageViews.count else { return }
        let page = pageViews[index]
        page.frame = pageContainer.bounds
        page.autoresizingMask = [.width, .height]
        pageContainer.addSubview(page)
    }

    // MARK: - Page 1: Appearance & Lyrics

    private func buildAppearancePage() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        // Card 1: Layout & Highlight Style
        let layoutStack = NSStackView()
        layoutStack.orientation = .vertical
        layoutStack.alignment = .leading
        layoutStack.spacing = 5

        let row1 = makeInlineRow(label: modeLabel, control: dualLineControl)
        let row2 = makeInlineRow(label: highlightLabel, control: highlightControl)
        let row3 = makeInlineRow(label: styleLabel, control: stylePopUp)
        let row4 = makeInlineRow(label: animLabel, control: animationPopUp)
        let row5 = makeInlineRow(label: longLyricLabel, control: longLyricPopUp)

        layoutStack.addArrangedSubview(row1)
        layoutStack.addArrangedSubview(row2)
        layoutStack.addArrangedSubview(row3)
        layoutStack.addArrangedSubview(row4)
        layoutStack.addArrangedSubview(row5)

        let card1 = makeCardBox(
            titleID: "TATA LETAK & GAYA LIRIK",
            titleEN: "LAYOUT & HIGHLIGHT STYLE",
            iconName: "text.bubble.fill",
            contentView: layoutStack
        )

        // Card 2: Color & Typography
        let styleStack = NSStackView()
        styleStack.orientation = .vertical
        styleStack.alignment = .leading
        styleStack.spacing = 5

        let row6 = makeInlineRow(label: colorLabel, control: colorPopUp)
        let row7 = makeInlineRow(label: alignLabel, control: alignmentControl)
        let row8 = makeInlineRow(label: fontLabel, control: fontSizeControl)

        styleStack.addArrangedSubview(row6)
        styleStack.addArrangedSubview(row7)
        styleStack.addArrangedSubview(row8)

        let card2 = makeCardBox(
            titleID: "WARNA & TIPOGRAFI",
            titleEN: "COLOR & TYPOGRAPHY",
            iconName: "paintpalette.fill",
            contentView: styleStack
        )

        stack.addArrangedSubview(card1)
        stack.addArrangedSubview(card2)
        return stack
    }

    // MARK: - Page 2: Media & Player

    private func buildMediaPage() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        // Card 1: Music Player & Spotify Ads
        let playerStack = NSStackView()
        playerStack.orientation = .vertical
        playerStack.alignment = .leading
        playerStack.spacing = 5

        let row1 = makeInlineRow(label: playerLabel, control: playerPopUp)
        let row2 = makeInlineRow(label: adAudioLabel, control: adAudioPopUp)

        playerStack.addArrangedSubview(row1)
        playerStack.addArrangedSubview(row2)

        let card1 = makeCardBox(
            titleID: "PEMUTAR MUSIK & IKLAN",
            titleEN: "MUSIC PLAYER & ADS BEHAVIOR",
            iconName: "music.note.house.fill",
            contentView: playerStack
        )

        // Card 2: Album Artwork & Media Visuals
        let visualsGrid = make2ColumnGrid(items: [
            (albumArtCheckbox, "photo.artframe"),
            (canvasCheckbox, "film.fill"),
            (trackInfoCheckbox, "info.circle.fill"),
            (pauseIconCheckbox, "pause.circle.fill")
        ])

        let artSizeRow = makeInlineRow(label: artSizeLabel, control: albumArtSizeControl)

        let visualsStack = NSStackView()
        visualsStack.orientation = .vertical
        visualsStack.alignment = .leading
        visualsStack.spacing = 6
        visualsStack.addArrangedSubview(visualsGrid)
        visualsStack.addArrangedSubview(artSizeRow)

        let card2 = makeCardBox(
            titleID: "SAMPUL ALBUM & VISUAL",
            titleEN: "ALBUM ARTWORK & VISUALS",
            iconName: "photo.fill",
            contentView: visualsStack
        )

        stack.addArrangedSubview(card1)
        stack.addArrangedSubview(card2)
        return stack
    }

    // MARK: - Page 3: Smart Features & Gestures

    private func buildSmartFeaturesPage() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        // Card 1: Live Visualizers & Ticker
        let visualizersGrid = make2ColumnGrid(items: [
            (romanizeCheckbox, "character.book.closed.fill"),
            (equalizerCheckbox, "waveform.path.ecg"),
            (pitchVisualizerCheckbox, "music.mic"),
            (menuBarCheckbox, "menubar.rectangle")
        ])

        let card1 = makeCardBox(
            titleID: "VISUALISASI & INTEGRASI",
            titleEN: "LIVE VISUALIZERS & TICKER",
            iconName: "waveform.badge.magnifyingglass",
            contentView: visualizersGrid
        )

        // Card 2: Touch Bar Interactions & Gestures
        let interactionsGrid = make2ColumnGrid(items: [
            (upNextCheckbox, "timer"),
            (heartButtonCheckbox, "heart.fill"),
            (gesturesCheckbox, "hand.draw.fill")
        ])

        let card2 = makeCardBox(
            titleID: "INTERAKSI & GESTUR TOUCH BAR",
            titleEN: "TOUCH BAR INTERACTIONS & GESTURES",
            iconName: "hand.tap.fill",
            contentView: interactionsGrid
        )

        stack.addArrangedSubview(card1)
        stack.addArrangedSubview(card2)
        return stack
    }

    // MARK: - Reusable UI Builders

    private func makeCardBox(titleID: String, titleEN: String, iconName: String, contentView: NSView) -> NSBox {
        let box = NSBox()
        box.title = ""
        box.boxType = .custom
        box.cornerRadius = 8
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.3)
        box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.35)
        box.contentViewMargins = NSSize(width: 10, height: 6)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 6

        let config = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .semibold)
        let imageView = NSImageView()
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            imageView.image = icon
            imageView.contentTintColor = .systemBlue
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 14),
            imageView.heightAnchor.constraint(equalToConstant: 14)
        ])

        let titleField = NSTextField(labelWithString: isIndonesian ? titleID : titleEN)
        titleField.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        titleField.textColor = .secondaryLabelColor

        cardHeaders.append((label: titleField, idKey: titleID, enKey: titleEN))

        headerStack.addArrangedSubview(imageView)
        headerStack.addArrangedSubview(titleField)

        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(contentView)

        box.contentView = stack
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 412).isActive = true
        return box
    }

    private func makeInlineRow(label: NSTextField, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 95).isActive = true

        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func make2ColumnGrid(items: [(checkbox: NSButton, icon: String)]) -> NSView {
        let grid = NSGridView(views: [])
        grid.rowSpacing = 5
        grid.columnSpacing = 16

        for i in stride(from: 0, to: items.count, by: 2) {
            let leftItem = items[i]
            let leftView = makeItemRow(checkbox: leftItem.checkbox, iconName: leftItem.icon)

            if i + 1 < items.count {
                let rightItem = items[i + 1]
                let rightView = makeItemRow(checkbox: rightItem.checkbox, iconName: rightItem.icon)
                grid.addRow(with: [leftView, rightView])
            } else {
                grid.addRow(with: [leftView, NSView()])
            }
        }
        return grid
    }

    private func makeItemRow(checkbox: NSButton, iconName: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6

        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let iv = NSImageView()
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            iv.image = img
            iv.contentTintColor = .systemBlue
        }
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 15),
            iv.heightAnchor.constraint(equalToConstant: 15)
        ])

        checkbox.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        row.addArrangedSubview(iv)
        row.addArrangedSubview(checkbox)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 185).isActive = true
        return row
    }

    // MARK: - Localization Engine

    @objc private func onLanguageChanged() {
        let selectedLang = (languageControl.selectedSegment == 0) ? "id" : "en"
        UserDefaults.standard.set(selectedLang, forKey: Self.keyLanguage)
        updateLocalization()
    }

    private func updateLocalization() {
        let isID = isIndonesian
        languageControl.selectedSegment = isID ? 0 : 1

        titleLabel.stringValue = isID ? "Pengaturan Syllo" : "Syllo Preferences"
        creditsLabel.stringValue = isID
            ? "Syllo v2.0 • Berdasarkan Lirik karya RidhaAF • Dikembangkan oleh Miftah (Lisensi MIT)"
            : "Syllo v2.0 • Originally based on Lirik by RidhaAF • Recoded & Enhanced by Miftah (MIT License)"

        // Tabs
        tabSegment.setLabel(isID ? "Tampilan & Lirik" : "Appearance & Lyrics", forSegment: 0)
        tabSegment.setLabel(isID ? "Media & Player" : "Media & Player", forSegment: 1)
        tabSegment.setLabel(isID ? "Fitur Cerdas" : "Smart Features", forSegment: 2)

        // Card Headers
        for item in cardHeaders {
            item.label.stringValue = isID ? item.idKey : item.enKey
        }

        // Page 1 Labels
        modeLabel.stringValue = isID ? "Mode:" : "Mode:"
        dualLineControl.setLabel(isID ? "2-Baris" : "2-Line", forSegment: 0)
        dualLineControl.setLabel(isID ? "1-Baris" : "1-Line", forSegment: 1)

        highlightLabel.stringValue = isID ? "Sorotan Lirik:" : "Highlighting:"
        highlightControl.setLabel(isID ? "Aktif" : "Enabled", forSegment: 0)
        highlightControl.setLabel(isID ? "Nonaktif" : "Disabled", forSegment: 1)

        styleLabel.stringValue = isID ? "Gaya Sorotan:" : "Highlight Style:"
        let selectedStyleIdx = stylePopUp.indexOfSelectedItem
        stylePopUp.removeAllItems()
        if isID {
            stylePopUp.addItems(withTitles: [
                "Word Snap (Seblok Kata Utuh)",
                "Apple Music Line Focus",
                "Word Pill (Kapsul Kata)",
                "Smooth Karaoke Sweep"
            ])
        } else {
            stylePopUp.addItems(withTitles: [
                "Word Snap (Whole-Word Block)",
                "Apple Music Line Focus",
                "Word Pill (Capsule Bubble)",
                "Smooth Karaoke Sweep"
            ])
        }
        stylePopUp.selectItem(at: max(0, selectedStyleIdx))

        animLabel.stringValue = isID ? "Animasi Baris:" : "Line Transition:"
        let selectedAnimIdx = animationPopUp.indexOfSelectedItem
        animationPopUp.removeAllItems()
        if isID {
            animationPopUp.addItems(withTitles: [
                "Slide Up (Spotify Smooth)",
                "Smooth Crossfade",
                "Spring Pulse",
                "Instan (Tanpa Animasi)"
            ])
        } else {
            animationPopUp.addItems(withTitles: [
                "Slide Up (Spotify Smooth)",
                "Smooth Crossfade",
                "Spring Pulse",
                "Instant (No Animation)"
            ])
        }
        animationPopUp.selectItem(at: max(0, selectedAnimIdx))

        longLyricLabel.stringValue = isID ? "Lirik Panjang:" : "Long Lyrics:"
        let selectedLongIdx = longLyricPopUp.indexOfSelectedItem
        longLyricPopUp.removeAllItems()
        if isID {
            longLyricPopUp.addItems(withTitles: [
                "Smart Auto-Split (Bagi 2 Bagian)",
                "Smooth Auto-Scroll (Marquee)",
                "Auto-Fit (Kecilkan Font)",
                "Kalimat Penuh (Truncate)"
            ])
        } else {
            longLyricPopUp.addItems(withTitles: [
                "Smart Auto-Split (Split in Half)",
                "Smooth Auto-Scroll (Marquee)",
                "Auto-Fit (Shrink Font)",
                "Full Line (Truncate Tail)"
            ])
        }
        longLyricPopUp.selectItem(at: max(0, selectedLongIdx))

        colorLabel.stringValue = isID ? "Warna Sorotan:" : "Highlight Color:"
        let selectedColorIdx = colorPopUp.indexOfSelectedItem
        colorPopUp.removeAllItems()
        if isID {
            colorPopUp.addItems(withTitles: [
                "Auto (Adaptif Sampul)",
                "Putih",
                "Emas",
                "Cyan",
                "Hijau",
                "Ungu",
                "Pink",
                "Oranye",
                "Merah"
            ])
        } else {
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
        }
        colorPopUp.selectItem(at: max(0, selectedColorIdx))

        alignLabel.stringValue = isID ? "Perataan Teks:" : "Text Alignment:"
        alignmentControl.setLabel(isID ? "Kiri" : "Left", forSegment: 0)
        alignmentControl.setLabel(isID ? "Tengah" : "Center", forSegment: 1)

        fontLabel.stringValue = isID ? "Ukuran Teks:" : "Text Size:"
        fontSizeControl.setLabel(isID ? "Kecil" : "Small", forSegment: 0)
        fontSizeControl.setLabel(isID ? "Sedang" : "Medium", forSegment: 1)
        fontSizeControl.setLabel(isID ? "Besar" : "Large", forSegment: 2)

        // Page 2 Labels
        playerLabel.stringValue = isID ? "Pemutar Musik:" : "Music Player:"
        let selectedPlayerIdx = playerPopUp.indexOfSelectedItem
        playerPopUp.removeAllItems()
        if isID {
            playerPopUp.addItems(withTitles: [
                "Otomatis (Spotify, Apple Music, VLC, dll)",
                "Spotify Saja",
                "Apple Music Saja",
                "QuickTime Saja",
                "IINA Saja",
                "VLC Saja"
            ])
        } else {
            playerPopUp.addItems(withTitles: [
                "Auto-detect (Spotify, Apple Music, VLC, etc)",
                "Spotify Only",
                "Apple Music Only",
                "QuickTime Only",
                "IINA Only",
                "VLC Only"
            ])
        }
        playerPopUp.selectItem(at: max(0, selectedPlayerIdx))

        adAudioLabel.stringValue = isID ? "Iklan Spotify:" : "Spotify Ads:"
        let selectedAdIdx = adAudioPopUp.indexOfSelectedItem
        adAudioPopUp.removeAllItems()
        if isID {
            adAudioPopUp.addItems(withTitles: [
                "Auto Mute (100% Senyap)",
                "Auto Dim (Kecilkan Volume 10%)",
                "Normal (Biarkan Saja)"
            ])
        } else {
            adAudioPopUp.addItems(withTitles: [
                "Auto Mute (100% Silent)",
                "Auto Dim (Whisper Volume 10%)",
                "Normal (Do Nothing)"
            ])
        }
        adAudioPopUp.selectItem(at: max(0, selectedAdIdx))

        albumArtCheckbox.title = isID ? "Sampul Album" : "Album Artwork"
        artSizeLabel.stringValue = isID ? "Ukuran Sampul:" : "Artwork Size:"
        albumArtSizeControl.setLabel(isID ? "Kecil" : "Small", forSegment: 0)
        albumArtSizeControl.setLabel(isID ? "Sedang" : "Medium", forSegment: 1)
        albumArtSizeControl.setLabel(isID ? "Besar" : "Large", forSegment: 2)

        canvasCheckbox.title = isID ? "Spotify Canvas Looping" : "Spotify Canvas Looping"
        trackInfoCheckbox.title = isID ? "Badge Info Lagu" : "Song Change Badge"
        pauseIconCheckbox.title = isID ? "Ikon Jeda (⏸ / ❙❙)" : "Pause Indicator (⏸)"

        // Page 3 Checkboxes
        romanizeCheckbox.title = isID ? "Auto-Romanisasi (KR/JP/CN)" : "Auto-Romanize (KR/JP/CN)"
        equalizerCheckbox.title = isID ? "Spektrum Equalizer" : "Equalizer Spectrum"
        pitchVisualizerCheckbox.title = isID ? "Vocal Pitch & Melody" : "Vocal Pitch & Melody"
        menuBarCheckbox.title = isID ? "Lirik di Menu Bar" : "Lyrics in Menu Bar"
        upNextCheckbox.title = isID ? "Hitung Mundur 'Up Next'" : "'Up Next' Countdown"
        heartButtonCheckbox.title = isID ? "Tombol Suka (❤️)" : "Like Button (❤️)"
        gesturesCheckbox.title = isID ? "Gestur 2-Jari (Skip & Vol)" : "2-Finger Gestures"

        // Footer
        clearCacheButton.title = isID ? "Hapus Vault & Cache" : "Clear Vault & Cache"
        updateCacheStatus()
    }

    // MARK: - Load & Save Logic

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPreferences()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loadPreferences()
        updateCacheStatus()
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard

        let lang = defaults.string(forKey: Self.keyLanguage) ?? "id"
        languageControl.selectedSegment = (lang == "en") ? 1 : 0

        let dualLine = defaults.object(forKey: Self.keyDualLine) as? Bool ?? true
        dualLineControl.selectedSegment = dualLine ? 0 : 1

        let enableHighlight = defaults.object(forKey: Self.keyEnableHighlight) as? Bool ?? true
        highlightControl.selectedSegment = enableHighlight ? 0 : 1
        stylePopUp.isEnabled = enableHighlight

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

        let anim = defaults.string(forKey: Self.keyLyricAnimation) ?? "slide"
        switch anim {
        case "fade": animationPopUp.selectItem(at: 1)
        case "pop": animationPopUp.selectItem(at: 2)
        case "instant": animationPopUp.selectItem(at: 3)
        default: animationPopUp.selectItem(at: 0) // slide
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

    private func wireActions() {
        dualLineControl.target = self
        dualLineControl.action = #selector(onDualLineChanged)

        highlightControl.target = self
        highlightControl.action = #selector(onHighlightControlChanged)

        stylePopUp.target = self
        stylePopUp.action = #selector(onStyleChanged)

        animationPopUp.target = self
        animationPopUp.action = #selector(onAnimationChanged)

        longLyricPopUp.target = self
        longLyricPopUp.action = #selector(onLongLyricModeChanged)

        colorPopUp.target = self
        colorPopUp.action = #selector(onColorChanged)

        alignmentControl.target = self
        alignmentControl.action = #selector(onAlignmentChanged)

        fontSizeControl.target = self
        fontSizeControl.action = #selector(onFontSizeChanged)

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
    }

    // MARK: - Action Handlers

    @objc private func onDualLineChanged() {
        let isDual = dualLineControl.selectedSegment == 0
        UserDefaults.standard.set(isDual, forKey: Self.keyDualLine)
    }

    @objc private func onHighlightControlChanged() {
        let isHighlight = highlightControl.selectedSegment == 0
        UserDefaults.standard.set(isHighlight, forKey: Self.keyEnableHighlight)
        stylePopUp.isEnabled = isHighlight
        NotificationCenter.default.post(name: Notification.Name("io.github.ridhaaf.lirik.highlightStyleChanged"), object: nil)
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
        defaults.removeObject(forKey: Self.keyLanguage)
        defaults.removeObject(forKey: Self.keyDualLine)
        defaults.removeObject(forKey: Self.keyEnableHighlight)
        defaults.removeObject(forKey: Self.keyLyricHighlightStyle)
        defaults.removeObject(forKey: Self.keyLyricAnimation)
        defaults.removeObject(forKey: Self.keyLongLyricMode)
        defaults.removeObject(forKey: Self.keyHighlightColor)
        defaults.removeObject(forKey: Self.keyAlignment)
        defaults.removeObject(forKey: Self.keyFontSize)
        defaults.removeObject(forKey: Self.keyPreferredPlayer)
        defaults.removeObject(forKey: Self.keyAdAudioBehavior)
        defaults.removeObject(forKey: Self.keyShowAlbumArt)
        defaults.removeObject(forKey: Self.keyAlbumArtSize)
        defaults.removeObject(forKey: Self.keyEnableCanvas)
        defaults.removeObject(forKey: Self.keyShowTrackInfo)
        defaults.removeObject(forKey: Self.keyShowPauseIcon)
        defaults.removeObject(forKey: Self.keyEnableRomanization)
        defaults.removeObject(forKey: Self.keyShowEqualizer)
        defaults.removeObject(forKey: Self.keyShowPitchVisualizer)
        defaults.removeObject(forKey: Self.keyEnableMenuBarLyrics)
        defaults.removeObject(forKey: Self.keyEnableUpNextCountdown)
        defaults.removeObject(forKey: Self.keyShowHeartButton)
        defaults.removeObject(forKey: Self.keyEnableGestures)
        defaults.removeObject(forKey: Self.keyEnableMarquee)
        defaults.removeObject(forKey: Self.keyEnableKaraokeGlow)
        loadPreferences()
        updateLocalization()
    }

    @objc private func onClearCacheTapped() {
        lyricsCache.clear()
        OfflineLyricsVault.shared.clearVault()
        updateCacheStatus()
        cacheStatusLabel.stringValue = isIndonesian ? "Vault & Cache dibersihkan!" : "Vault & Cache cleared!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateCacheStatus()
        }
    }

    private func updateCacheStatus() {
        let memoryCount = lyricsCache.count
        let vaultCount = OfflineLyricsVault.shared.totalSongsInVault
        let total = max(memoryCount, vaultCount)
        cacheStatusLabel.stringValue = isIndonesian
            ? "Vault: \(total) lagu tersimpan"
            : "Vault: \(total) song\(total == 1 ? "" : "s") cached"
    }
}

@objc(LirikPreferenceViewController)
class LirikPreferenceViewController: SylloPreferenceViewController {
    // Backwards-compatibility subclass for legacy Pock installations
}

