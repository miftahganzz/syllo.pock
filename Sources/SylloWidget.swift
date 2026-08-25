//
//  SylloWidget.swift
//  syllo
//
//  Created by RidhaAF on 2024.
//  Enhanced & Recoded by Miftah on 2026.
//  Licensed under MIT License.
//

import Foundation
import AppKit
import PockKit

@objc(SylloWidget)
class SylloWidget: LyricsWidget {
    // Inherits all PKWidget functionality, rendering, and lifecycle from LyricsWidget
}

@objc(LirikWidget)
class LirikWidget: SylloWidget {
    // Backwards-compatibility alias for legacy Pock configurations
}
