// NowPlayingBar.swift — Persistent compact player shown at the bottom of all screens.
// Provides play/pause, prev/next, and artwork. Tapping opens full NowPlayingView.
// All controls have real actions (R-26). Three states: playing, paused, idle (R-27).

import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var playback: PlaybackViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        if let track = playback.currentTrack {
            compactBar(track)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func compactBar(_ track: Track) -> some View {
        Button {
            withAnimation(Motion.spring) { isExpanded = true }
        } label: {
            HStack(spacing: Spacing.md) {
                ArtworkView(data: track.artworkData, size: 44, cornerRadius: Radius.sm)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayTitle)
                        .font(Typography.labelLarge)
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Transport controls — all have real actions (R-26)
                HStack(spacing: Spacing.sm) {
                    transportButton(
                        systemImage: "backward.fill",
                        accessibilityLabel: "Previous track",
                        action: { Task { await prevAction() } }
                    )
                    transportButton(
                        systemImage: isPlaying ? "pause.fill" : "play.fill",
                        accessibilityLabel: isPlaying ? "Pause" : "Play",
                        isLarge: true,
                        action: { Task { await toggleAction() } }
                    )
                    transportButton(
                        systemImage: "forward.fill",
                        accessibilityLabel: "Next track",
                        action: { Task { await nextAction() } }
                    )
                }
            }
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.sm)
            .background {
                // Thin progress tint at the bottom — accent used once (R-13 dose cap)
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        let fraction = playback.duration > 0
                            ? min(playback.currentTime / playback.duration, 1.0)
                            : 0
                        Rectangle()
                            .fill(Color("Accent"))
                            .frame(width: geo.size.width * fraction, height: 2)
                            .animation(Motion.standard, value: fraction)
                    }
                    .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .raisedSurface(radius: 0)
        .nowPlayingElevation()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now Playing: \(track.displayTitle) by \(track.displayArtist)")
    }

    private var isPlaying: Bool {
        if case .playing = playback.state { return true }
        return false
    }

    private func transportButton(
        systemImage: String,
        accessibilityLabel: String,
        isLarge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isLarge ? 22 : 16, weight: .semibold))
                .foregroundStyle(isLarge ? Color("Accent") : Color("TextPrimary"))
                .frame(width: 44, height: 44)   // minimum tap target (antislop R-03 tap size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Actions

    private func toggleAction() async {
        await coordinator?.togglePlayPause()
    }

    private func nextAction() async {
        try? await coordinator?.playNext()
    }

    private func prevAction() async {
        try? await coordinator?.playPrevious()
    }

    // Coordinator access via environment is injected by the app root
    @Environment(\.playbackCoordinator) private var coordinator: PlaybackCoordinator?
}

// MARK: - Environment key

private struct PlaybackCoordinatorKey: EnvironmentKey {
    static let defaultValue: PlaybackCoordinator? = nil
}

extension EnvironmentValues {
    var playbackCoordinator: PlaybackCoordinator? {
        get { self[PlaybackCoordinatorKey.self] }
        set { self[PlaybackCoordinatorKey.self] = newValue }
    }
}
