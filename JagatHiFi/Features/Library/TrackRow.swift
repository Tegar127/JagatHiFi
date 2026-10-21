// TrackRow.swift — Single track row for library/album/playlist lists.
// Shows artwork, title, artist, duration, and format badge.
// Correct empty/loading/error states provided by the parent list views (R-27).

import SwiftUI

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: Spacing.md) {
                // Artwork or now-playing indicator
                ZStack {
                    ArtworkView(data: track.artworkData, size: 44, cornerRadius: Radius.sm)
                    if isPlaying {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(.black.opacity(0.5))
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("Accent"))
                    }
                }
                .frame(width: 44, height: 44)

                // Track metadata
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(track.displayTitle)
                            .font(Typography.labelLarge)
                            .foregroundStyle(isPlaying ? Color("Accent") : Color("TextPrimary"))
                            .lineLimit(1)

                        if track.format != .unknown && track.format != .mp3 && track.format != .aac {
                            // Format badge — functionally informative (R-09 purpose: actual format label)
                            Text(track.format.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color("TextTertiary"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color("SurfaceOverlay"))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                    }

                    Text(track.displayArtist)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Duration
                if track.duration > 0 {
                    Text(track.formattedDuration)
                        .font(Typography.techReadout)
                        .foregroundStyle(Color("TextTertiary"))
                        .monospacedDigit()
                }

                // Missing file indicator
                if !track.isFileAccessible {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("ErrorColor"))
                        .accessibilityLabel("File unavailable")
                }
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.base)
            .contentShape(Rectangle())
        }
        .buttonStyle(TrackRowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = "\(track.displayTitle) by \(track.displayArtist)"
        if isPlaying { label = "Now playing: \(label)" }
        if !track.isFileAccessible { label += ", file unavailable" }
        return label
    }
}

#Preview {
    let t = Track(filePath: "/music/test.flac", title: "Nocturne in E-flat", artist: "Chopin", album: "Nocturnes", duration: 284, format: .flac, sampleRate: 96000, bitDepth: 24, channelCount: 2)
    return VStack(spacing: 0) {
        TrackRow(track: t, isPlaying: true)
        Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
        TrackRow(track: t, isPlaying: false)
    }
    .background(Color("SurfaceBase"))
}
