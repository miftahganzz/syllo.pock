//
//  PitchMelodyVisualizerView.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import QuartzCore

final class PitchMelodyVisualizerView: NSView {

    var barColor: NSColor = .white {
        didSet {
            needsDisplay = true
        }
    }

    private(set) var isPlaying: Bool = false
    private var animationTimer: Timer?
    private var pitchHeights: [CGFloat] = [0.4, 0.7, 0.9, 0.5, 0.8, 0.6, 0.95, 0.3, 0.75]
    private var targetHeights: [CGFloat] = [0.4, 0.7, 0.9, 0.5, 0.8, 0.6, 0.95, 0.3, 0.75]
    private var phase: CGFloat = 0.0

    override var isOpaque: Bool {
        return false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.wantsLayer = true
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: 32).isActive = true
        self.heightAnchor.constraint(equalToConstant: 18).isActive = true
    }

    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing

        if playing {
            startPitchAnimation()
        } else {
            stopPitchAnimation()
        }
    }

    private func startPitchAnimation() {
        stopPitchAnimation()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 0.15

            for i in 0..<self.pitchHeights.count {
                let wave = sin(self.phase + CGFloat(i) * 0.7) * 0.4 + 0.55
                self.pitchHeights[i] += (wave - self.pitchHeights[i]) * 0.35
            }
            self.needsDisplay = true
        }
    }

    private func stopPitchAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        for i in 0..<pitchHeights.count {
            pitchHeights[i] = 0.2
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barCount = pitchHeights.count
        let spacing: CGFloat = 1.5
        let totalSpacing = CGFloat(barCount - 1) * spacing
        let barWidth = max(1.5, (bounds.width - totalSpacing) / CGFloat(barCount))
        let maxHeight = bounds.height - 2

        ctx.saveGState()

        for (index, heightFraction) in pitchHeights.enumerated() {
            let barHeight = max(2.0, maxHeight * heightFraction)
            let x = CGFloat(index) * (barWidth + spacing)
            let y = (bounds.height - barHeight) / 2

            let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)

            // Dynamic gradient fill for each pitch bar
            let alpha = 0.4 + (heightFraction * 0.6)
            barColor.withAlphaComponent(alpha).setFill()
            path.fill()
        }

        ctx.restoreGState()
    }
}
