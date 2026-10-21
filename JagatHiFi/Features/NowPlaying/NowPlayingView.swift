// NowPlayingView.swift — Full-screen playback screen.
// Large artwork, track info, seeker, transport controls, and audio info panel.
// No decorative gradients applied globally. Accent used on progress/active controls only.

import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var playback: PlaybackViewModel
    @Binding var isPresented: Bool
    @Environment(\.playbackCoordinator) private var coordinator

    @State private var seekValue: Double = 0
    @State private var isSeeking: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    artworkSection
                    trackInfoSection
                    seekerSection
                    transportSection
                    secondaryControlsSection
                    audioInfoSection
                }
                .padding(.horizontal, Spacing.base)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(Color("Accent"))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: playback.currentTime) { _, new in
            if !isSeeking { seekValue = new }
        }
    }

    // MARK: - Artwork

    private var artworkSection: some View {
        ArtworkView(
            data: playback.currentTrack?.artworkData,
            size: artworkSize,
            cornerRadius: Radius.xl
        )
        .padding(.top, Spacing.lg)
        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        // Shadow here: single artwork elevation to lift it from the surface (R-12 purpose).
    }

    private var artworkSize: CGFloat {
        min(UIScreen.main.bounds.width - Spacing.base * 2 - 32, 360)
    }

    // MARK: - Track info

    private var trackInfoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(playback.currentTrack?.displayTitle ?? "Not Playing")
                    .font(Typography.albumTitle(22))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(2)
                Text(playback.currentTrack?.displayArtist ?? "")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
                Text(playback.currentTrack?.displayAlbum ?? "")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color("TextTertiary"))
                    .lineLimit(1)
            }
            Spacer()
            favoriteButton
        }
    }

    private var favoriteButton: some View {
        Button {
            playback.currentTrack?.isFavorite.toggle()
        } label: {
            Image(systemName: playback.currentTrack?.isFavorite == true ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundStyle(playback.currentTrack?.isFavorite == true
                    ? Color("Accent")
                    : Color("TextTertiary"))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playback.currentTrack?.isFavorite == true ? "Remove from favorites" : "Add to favorites")
        .animation(Motion.spring, value: playback.currentTrack?.isFavorite)
    }

    // MARK: - Seeker

    private var seekerSection: some View {
        VStack(spacing: Spacing.xs) {
            Slider(
                value: $seekValue,
                in: 0 ... max(playback.duration, 1),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing {
                        Task { try? await coordinator?.seek(to: seekValue) }
                    }
                }
            )
            .tint(Color("Accent"))
            .accessibilityLabel("Seek position")

            HStack {
                Text(formatTime(seekValue))
                    .font(Typography.techReadout)
                    .foregroundStyle(Color("TextTertiary"))
                Spacer()
                Text(formatTime(playback.duration))
                    .font(Typography.techReadout)
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
    }

    // MARK: - Transport controls

    private var transportSection: some View {
        HStack(spacing: Spacing.xl) {
            bigTransportButton(
                systemImage: "backward.fill",
                label: "Previous track",
                action: { Task { try? await coordinator?.playPrevious() } }
            )

            playPauseButton

            bigTransportButton(
                systemImage: "forward.fill",
                label: "Next track",
                action: { Task { try? await coordinator?.playNext() } }
            )
        }
        .padding(.vertical, Spacing.sm)
    }

    private var playPauseButton: some View {
        let isPlaying: Bool = {
            if case .playing = playback.state { return true }
            return false
        }()

        return Button {
            Task { await coordinator?.togglePlayPause() }
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color("Accent"))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
        .animation(Motion.standard, value: isPlaying)
    }

    private func bigTransportButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Secondary controls (shuffle, repeat)

    private var secondaryControlsSection: some View {
        HStack {
            // Shuffle
            Button {
                Task { await coordinator?.setShuffle(!playback.isShuffled) }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(playback.isShuffled ? Color("Accent") : Color("TextTertiary"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.isShuffled ? "Shuffle on" : "Shuffle off")

            Spacer()

            // Repeat
            Button {
                Task {
                    let next: RepeatMode
                    switch playback.repeatMode {
                    case .off: next = .all
                    case .all: next = .one
                    case .one: next = .off
                    }
                    await coordinator?.setRepeat(next)
                }
            } label: {
                Image(systemName: playback.repeatMode.systemImageName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(playback.repeatMode == .off ? Color("TextTertiary") : Color("Accent"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .overlay(alignment: .topTrailing) {
                        if playback.repeatMode == .one {
                            // Small "1" badge — functionally needed label (R-09 purpose)
                            Text("1")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color("Accent"))
                                .offset(x: 6, y: -4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repeat: \(playback.repeatMode.rawValue)")
        }
    }

    // MARK: - Audio info panel

    private var audioInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Source")
                .font(Typography.labelSmall)
                .foregroundStyle(Color("TextTertiary"))
                .textCase(.uppercase)
                .tracking(0.8)

            if let track = playback.currentTrack {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Spacing.sm) {
                    audioInfoRow(label: "Format", value: track.format.rawValue)
                    audioInfoRow(label: "Sample Rate", value: track.sampleRate.map { formatSampleRate($0) } ?? "Unknown")
                    audioInfoRow(label: "Bit Depth", value: track.bitDepth.map { "\($0) bit" } ?? "Unknown")
                    audioInfoRow(label: "Channels", value: track.channelCount.map { formatChannels($0) } ?? "Unknown")
                }
            } else {
                Text("No track loaded")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
        .padding(Spacing.base)
        .raisedSurface()
    }

    private func audioInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.techLabel)
                .foregroundStyle(Color("TextTertiary"))
            Text(value)
                .font(Typography.techReadout)
                .foregroundStyle(Color("TextPrimary"))
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatSampleRate(_ hz: Double) -> String {
        if hz >= 1000 { return String(format: "%.1f kHz", hz / 1000) }
        return String(format: "%.0f Hz", hz)
    }

    private func formatChannels(_ count: Int) -> String {
        switch count {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(count) ch"
        }
    }
}
