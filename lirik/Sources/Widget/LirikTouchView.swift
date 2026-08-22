//
//  LirikTouchView.swift
//  lirik
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import AppKit

final class LirikTouchView: NSView {

    var onSingleTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onPanBegan: ((_ initialX: CGFloat) -> Void)?
    var onPanChanged: ((_ deltaX: CGFloat) -> Void)?
    var onPanEnded: ((_ deltaX: CGFloat) -> Void)?
    var onPanCancelled: (() -> Void)?

    var onTwoFingerSwipeHorizontal: ((_ deltaX: CGFloat) -> Void)?
    var onTwoFingerSwipeVertical: ((_ deltaY: CGFloat) -> Void)?

    private var initialTouchPoint: NSPoint?
    private var isPanning: Bool = false
    private var isTwoFingerGesture: Bool = false
    private var lastTapTimestamp: TimeInterval = 0
    private var singleTapTimer: Timer?
    private var longPressTimer: Timer?
    private var longPressTriggered: Bool = false

    override var acceptsTouchEvents: Bool {
        get { return true }
        set { }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    // MARK: - Touch Bar Multi-Touch Handling

    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        longPressTriggered = false

        if touches.count >= 2 {
            isTwoFingerGesture = true
            isPanning = false
            cancelTimers()
            initialTouchPoint = touches.first?.location(in: self)
            return
        }

        guard let touch = touches.first else { return }
        initialTouchPoint = touch.location(in: self)
        isPanning = false
        isTwoFingerGesture = false

        // Start Long-Press Timer (0.55s)
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
            guard let self, !self.isPanning, !self.isTwoFingerGesture else { return }
            self.longPressTriggered = true
            self.cancelTimers()
            self.onLongPress?()
        }
    }

    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)

        if touches.count >= 2 {
            isTwoFingerGesture = true
            cancelTimers()
            if let initial = initialTouchPoint, let touch = touches.first {
                let current = touch.location(in: self)
                let dx = current.x - initial.x
                let dy = current.y - initial.y
                if abs(dx) > abs(dy) {
                    onTwoFingerSwipeHorizontal?(dx)
                } else {
                    onTwoFingerSwipeVertical?(dy)
                }
            }
            return
        }

        guard let initial = initialTouchPoint,
              let touch = touches.first else { return }
        let current = touch.location(in: self)
        let dx = current.x - initial.x

        if !isPanning && abs(dx) > 7 {
            isPanning = true
            cancelTimers()
            onPanBegan?(initial.x)
        }
        if isPanning {
            onPanChanged?(dx)
        }
    }

    override func touchesEnded(with event: NSEvent) {
        let wasLongPress = longPressTriggered
        cancelTimers()

        if isTwoFingerGesture {
            isTwoFingerGesture = false
            initialTouchPoint = nil
            return
        }

        if isPanning {
            if let initial = initialTouchPoint,
               let touch = event.touches(matching: .ended, in: self).first {
                let dx = touch.location(in: self).x - initial.x
                onPanEnded?(dx)
            } else {
                onPanEnded?(0)
            }
            isPanning = false
            initialTouchPoint = nil
            return
        }

        initialTouchPoint = nil
        guard !wasLongPress else { return }

        let now = event.timestamp
        if now - lastTapTimestamp < 0.38 {
            // Double Tap Detected!
            lastTapTimestamp = 0
            onDoubleTap?()
        } else {
            lastTapTimestamp = now
            singleTapTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self] _ in
                self?.onSingleTap?()
            }
        }
    }

    override func touchesCancelled(with event: NSEvent) {
        cancelTimers()
        if isPanning {
            onPanCancelled?()
            isPanning = false
        }
        isTwoFingerGesture = false
        initialTouchPoint = nil
    }

    private func cancelTimers() {
        singleTapTimer?.invalidate()
        singleTapTimer = nil
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Mouse / Trackpad Fallback Handling

    override func mouseDown(with event: NSEvent) {
        initialTouchPoint = convert(event.locationInWindow, from: nil)
        isPanning = false
        longPressTriggered = false

        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            guard let self, !self.isPanning else { return }
            self.longPressTriggered = true
            self.cancelTimers()
            self.onLongPress?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let initial = initialTouchPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - initial.x

        if !isPanning && abs(dx) > 8 {
            isPanning = true
            cancelTimers()
            onPanBegan?(initial.x)
        }
        if isPanning {
            onPanChanged?(dx)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let wasLongPress = longPressTriggered
        cancelTimers()

        if isPanning {
            if let initial = initialTouchPoint {
                let current = convert(event.locationInWindow, from: nil)
                let dx = current.x - initial.x
                onPanEnded?(dx)
            } else {
                onPanEnded?(0)
            }
            isPanning = false
            initialTouchPoint = nil
            return
        }

        initialTouchPoint = nil
        guard !wasLongPress else { return }

        if event.clickCount >= 2 {
            onDoubleTap?()
        } else if event.clickCount == 1 {
            singleTapTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self] _ in
                self?.onSingleTap?()
            }
        }
    }
}
