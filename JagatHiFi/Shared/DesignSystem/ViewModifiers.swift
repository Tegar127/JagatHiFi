// ViewModifiers.swift — Reusable SwiftUI view modifiers built on design tokens.

import SwiftUI

// MARK: - Surface modifier
// Applies the standard raised surface treatment: background, subtle border, corner radius.

struct RaisedSurface: ViewModifier {
    var radius: CGFloat = Radius.lg

    func body(content: Content) -> some View {
        content
            .background(Color("SurfaceRaised"))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color("Separator"), lineWidth: 0.5)
            )
    }
}

// MARK: - Now Playing elevation
// Single shadow used only on the Now Playing bar for elevation above content (R-12 purpose).

struct NowPlayingElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: -4)
    }
}

// MARK: - Track row press state

struct TrackRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color("SurfaceOverlay")
                    : Color.clear
            )
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

// MARK: - Accessible focus ring (R-32)

struct AccessibleFocusRing: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Color("Accent"), lineWidth: focused ? 2 : 0)
                    .animation(Motion.standard, value: focused)
            )
    }
}

// MARK: - Convenience extensions

extension View {
    func raisedSurface(radius: CGFloat = Radius.lg) -> some View {
        modifier(RaisedSurface(radius: radius))
    }

    func nowPlayingElevation() -> some View {
        modifier(NowPlayingElevation())
    }

    func accessibleFocusRing() -> some View {
        modifier(AccessibleFocusRing())
    }
}
