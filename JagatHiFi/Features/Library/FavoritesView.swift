// FavoritesView.swift — Filtered view of favorite tracks.

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(filter: #Predicate<Track> { $0.isFavorite }, sort: \Track.title) private var tracks: [Track]
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.playbackCoordinator) private var coordinator

    var body: some View {
        NavigationStack {
            Group {
                if tracks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(tracks) { track in
                                TrackRow(track: track, isPlaying: playback.currentTrack?.id == track.id) {
                                    Task { try? await coordinator?.loadQueue(tracks: tracks, startIndex: tracks.firstIndex(of: track) ?? 0) }
                                }
                                Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Favorites")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "heart")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
            Text("No favorites yet")
                .font(Typography.labelLarge)
                .foregroundStyle(Color("TextSecondary"))
            Text("Tap the heart icon on any track.")
                .font(Typography.bodySmall)
                .foregroundStyle(Color("TextTertiary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recently Added

struct RecentlyAddedView: View {
    @Query(sort: \Track.dateAdded, order: .reverse) private var tracks: [Track]
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.playbackCoordinator) private var coordinator

    private var recentTracks: [Track] { Array(tracks.prefix(50)) }

    var body: some View {
        NavigationStack {
            Group {
                if recentTracks.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "clock")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color("TextTertiary"))
                        Text("Nothing added yet")
                            .font(Typography.labelLarge)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(recentTracks) { track in
                                TrackRow(track: track, isPlaying: playback.currentTrack?.id == track.id) {
                                    Task { try? await coordinator?.loadQueue(tracks: recentTracks, startIndex: recentTracks.firstIndex(of: track) ?? 0) }
                                }
                                Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Recently Added")
        }
    }
}
