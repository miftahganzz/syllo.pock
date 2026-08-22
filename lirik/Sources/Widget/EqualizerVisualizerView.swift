//
//  EqualizerVisualizerView.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit
import QuartzCore

final class EqualizerVisualizerView: NSView {

    private var barLayers: [CALayer] = []
    private var isAnimating: Bool = false
    private let barCount = 4
    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 2.0
    private let maxBarHeight: CGFloat = 16.0
    private let minBarHeight: CGFloat = 2.5

    var barColor: NSColor = .labelColor {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for layer in barLayers {
                layer.backgroundColor = barColor.cgColor
            }
            CATransaction.commit()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        self.wantsLayer = true
        self.layer?.masksToBounds = true

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        self.frame.size = NSSize(width: totalWidth, height: maxBarHeight)

        for i in 0..<barCount {
            let bar = CALayer()
            let x = CGFloat(i) * (barWidth + barSpacing)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: minBarHeight)
            bar.cornerRadius = barWidth / 2.0
            bar.backgroundColor = barColor.cgColor
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.0) // Scale from bottom up
            self.layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    override var intrinsicContentSize: NSSize {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        return NSSize(width: totalWidth, height: maxBarHeight)
    }

    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            startAnimation()
        } else {
            pauseAnimation()
        }
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        let durations: [CFTimeInterval] = [0.42, 0.65, 0.38, 0.55]
        let heightMultiplierKeyframes: [[NSNumber]] = [
            [0.2, 0.85, 0.35, 1.0, 0.5, 0.2],
            [0.4, 0.2, 0.95, 0.3, 0.7, 0.4],
            [0.3, 1.0, 0.45, 0.9, 0.25, 0.3],
            [0.5, 0.35, 0.8, 0.2, 0.9, 0.5]
        ]

        for (index, bar) in barLayers.enumerated() {
            bar.removeAnimation(forKey: "equalizer")

            let anim = CAKeyframeAnimation(keyPath: "bounds.size.height")
            let mults = heightMultiplierKeyframes[index % heightMultiplierKeyframes.count]
            anim.values = mults.map { CGFloat($0.doubleValue) * self.maxBarHeight }
            anim.duration = durations[index % durations.count]
            anim.repeatCount = .infinity
            anim.autoreverses = true
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            bar.add(anim, forKey: "equalizer")
        }
    }

    private func pauseAnimation() {
        guard isAnimating else { return }
        isAnimating = false

        for bar in barLayers {
            bar.removeAnimation(forKey: "equalizer")
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            bar.frame.size.height = minBarHeight
            CATransaction.commit()
        }
    }
}
