// AlbumsView.swift — Album grid browser.

import SwiftUI
import SwiftData

struct AlbumsView: View {
    @Query(sort: \Track.album) private var tracks: [Track]

    private var albums: [AlbumGroup] {
        Dictionary(grouping: tracks, by: { "\($0.displayAlbumArtist)/\($0.displayAlbum)" })
            .map { _, group in
                AlbumGroup(
                    albumArtist: group.first?.displayAlbumArtist ?? "Unknown Artist",
                    albumName: group.first?.displayAlbum ?? "Unknown Album",
                    tracks: group.sorted { ($0.discNumber ?? 0, $0.trackNumber ?? 0) < ($1.discNumber ?? 0, $1.trackNumber ?? 0) },
                    artworkData: group.compactMap(\.artworkData).first
                )
            }
            .sorted { $0.albumName < $1.albumName }
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: Spacing.base)]

    var body: some View {
        NavigationStack {
            Group {
                if albums.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Spacing.base) {
                            ForEach(albums) { album in
                                NavigationLink(value: album) {
                                    AlbumCard(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Spacing.base)
                        .padding(.bottom, 100)
                    }
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Albums")
            .navigationDestination(for: AlbumGroup.self) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.stack")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
            Text("No albums yet")
                .font(Typography.labelLarge)
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Album card

struct AlbumCard: View {
    let album: AlbumGroup

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ArtworkView(data: album.artworkData, size: .infinity, cornerRadius: Radius.md)
                .aspectRatio(1, contentMode: .fit)
            Text(album.albumName)
                .font(Typography.labelMedium)
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)
            Text(album.albumArtist)
                .font(Typography.bodySmall)
                .foregroundStyle(Color("TextSecondary"))
                .lineLimit(1)
        }
    }
}

// MARK: - Album detail

struct AlbumDetailView: View {
    let album: AlbumGroup
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.playbackCoordinator) private var coordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Album header
                HStack(alignment: .top, spacing: Spacing.lg) {
                    ArtworkView(data: album.artworkData, size: 140, cornerRadius: Radius.lg)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(album.albumName)
                            .font(Typography.albumTitle(20))
                            .foregroundStyle(Color("TextPrimary"))
                        Text(album.albumArtist)
                            .font(Typography.bodyLarge)
                            .foregroundStyle(Color("TextSecondary"))
                        if let year = album.tracks.first?.year {
                            Text(String(year))
                                .font(Typography.bodySmall)
                                .foregroundStyle(Color("TextTertiary"))
                        }
                        Spacer()
                        Button("Play Album") {
                            Task { try? await coordinator?.loadQueue(tracks: album.tracks, startIndex: 0) }
                        }
                        .foregroundStyle(Color("Accent"))
                        .font(Typography.labelMedium)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color("AccentDimmed"))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    Spacer()
                }
                .padding(Spacing.base)

                // Track list
                LazyVStack(spacing: 0) {
                    ForEach(album.tracks) { track in
                        TrackRow(
                            track: track,
                            isPlaying: playback.currentTrack?.id == track.id
                        ) {
                            Task { try? await coordinator?.loadQueue(tracks: album.tracks, startIndex: album.tracks.firstIndex(of: track) ?? 0) }
                        }
                        if track.id != album.tracks.last?.id {
                            Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color("SurfaceBase").ignoresSafeArea())
        .navigationTitle(album.albumName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Data model

struct AlbumGroup: Identifiable, Hashable {
    var id: String { "\(albumArtist)/\(albumName)" }
    let albumArtist: String
    let albumName: String
    let tracks: [Track]
    let artworkData: Data?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AlbumGroup, rhs: AlbumGroup) -> Bool { lhs.id == rhs.id }
}
