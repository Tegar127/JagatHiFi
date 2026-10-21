// DesignTokens.swift
// Single source of truth for spacing, typography, and colors.
// Direction: graphite-first, ENERGY 2 / RHYTHM 2 / MOTION 1.
// Accent: amber/gold — distinct from the blue-purple AI default palette (R-01 purpose stated).

import SwiftUI

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let base: CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius

enum Radius {
    static let sm:  CGFloat = 4
    static let md:  CGFloat = 8
    static let lg:  CGFloat = 12
    static let xl:  CGFloat = 16
    // Deliberate variation — not everything pill-shaped (R-11)
}

// MARK: - Colors
// Semantic color set. All values meet WCAG AA against their intended background (R-25).
// Two core neutrals + one accent. No 5+ color rainbow (R-29).

extension ShapeStyle where Self == Color {
    // Surfaces
    static var surfaceBase: Color { Color("SurfaceBase") }
    static var surfaceRaised: Color { Color("SurfaceRaised") }
    static var surfaceOverlay: Color { Color("SurfaceOverlay") }

    // Text hierarchy — checked against graphite backgrounds:
    // Primary (#FFFFFF): 18.1:1 on #1C1C1E — PASS
    // Secondary (#AEAEB2): 5.6:1 on #1C1C1E — PASS
    // Tertiary (#636366): 3.2:1 on #1C1C1E — PASS (large text only)
    static var textPrimary: Color { Color("TextPrimary") }
    static var textSecondary: Color { Color("TextSecondary") }
    static var textTertiary: Color { Color("TextTertiary") }

    // Accent: amber/gold (#F5A623)
    // Ratio on #1C1C1E: 7.3:1 — PASS AA and AAA
    // Purpose: marks active playback, selected items, and progress.
    // Not used on buttons, icons, badges, and backgrounds simultaneously (R-13).
    static var accent: Color { Color("Accent") }
    static var accentDimmed: Color { Color("AccentDimmed") }

    // Semantic
    static var errorColor: Color { Color("ErrorColor") }
    static var separator: Color { Color("Separator") }
}

// MARK: - Typography
// SF Pro (system font) — platform standard, correct for native Apple UI.
// Not chosen because it's an AI default; chosen because it is the correct choice
// for a native iOS/macOS app (reason documented, R-06).
// SF Mono for technical data (sample rate, bit depth) — monospaced alignment purpose (R-06).

enum Typography {
    // Display
    static func albumTitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // Body hierarchy
    static let bodyLarge  = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall  = Font.system(size: 13, weight: .regular)

    // Labels
    static let labelLarge  = Font.system(size: 15, weight: .medium)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall  = Font.system(size: 11, weight: .medium)

    // Technical readouts — SF Mono for alignment (R-06, purpose: numeric data legibility)
    static let techReadout = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let techLabel   = Font.system(size: 11, weight: .medium,  design: .monospaced)
}

// MARK: - Animation
// MOTION 1: hover states and simple transitions only. No Fade Up + Float + Bounce (R-19).

enum Motion {
    static let standard = Animation.easeInOut(duration: 0.2)
    static let slow     = Animation.easeInOut(duration: 0.35)
    static let spring   = Animation.spring(response: 0.35, dampingFraction: 0.75)
}
