//
//  LoopingVideoView.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import AVFoundation

final class LoopingVideoView: NSView {

    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    private(set) var hasVideo: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        self.wantsLayer = true
        self.layer?.masksToBounds = true
        self.layer?.cornerRadius = 4

        let pLayer = AVPlayerLayer()
        pLayer.videoGravity = .resizeAspectFill
        pLayer.frame = self.bounds
        pLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(pLayer)
        self.playerLayer = pLayer
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = self.bounds
    }

    func loadVideo(url: URL) {
        clear()

        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true

        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        self.player = queuePlayer
        self.playerLayer?.player = queuePlayer

        queuePlayer.play()
        hasVideo = true
        self.isHidden = false
    }

    func playVideo() {
        player?.play()
    }

    func pauseVideo() {
        player?.pause()
    }

    func clear() {
        player?.pause()
        playerLooper?.disableLooping()
        playerLooper = nil
        player = nil
        playerLayer?.player = nil
        hasVideo = false
        self.isHidden = true
    }
}
