// ArtistsView.swift — Artist browser.

import SwiftUI
import SwiftData

struct ArtistsView: View {
    @Query(sort: \Track.artist) private var tracks: [Track]

    private var artists: [(String, [Track])] {
        let grouped = Dictionary(grouping: tracks, by: { $0.displayArtist })
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if artists.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(artists, id: \.0) { name, artistTracks in
                            NavigationLink(destination: ArtistDetailView(artistName: name, tracks: artistTracks)) {
                                HStack(spacing: Spacing.md) {
                                    ArtworkView(data: artistTracks.first?.artworkData, size: 44, cornerRadius: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(Typography.labelLarge)
                                            .foregroundStyle(Color("TextPrimary"))
                                        Text("\(artistTracks.count) song\(artistTracks.count == 1 ? "" : "s")")
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(Color("TextSecondary"))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color("SurfaceBase"))
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Artists")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "music.mic")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
            Text("No artists yet")
                .font(Typography.labelLarge)
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ArtistDetailView: View {
    let artistName: String
    let tracks: [Track]
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.playbackCoordinator) private var coordinator

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks.sorted { $0.displayAlbum < $1.displayAlbum }) { track in
                    TrackRow(track: track, isPlaying: playback.currentTrack?.id == track.id) {
                        Task { try? await coordinator?.loadQueue(tracks: tracks, startIndex: tracks.firstIndex(of: track) ?? 0) }
                    }
                    Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color("SurfaceBase").ignoresSafeArea())
        .navigationTitle(artistName)
    }
}
