// PlaylistsView.swift — Playlist management: create, rename, delete, browse.

import SwiftUI
import SwiftData

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playbackCoordinator) private var coordinator
    @EnvironmentObject private var playback: PlaybackViewModel
    @Query(sort: \Playlist.createdAt, order: .reverse) private var playlists: [Playlist]
    @Query private var allTracks: [Track]

    @State private var showingNewPlaylist: Bool = false
    @State private var newPlaylistName: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if playlists.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(playlists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(playlist: playlist, allTracks: allTracks)) {
                                HStack(spacing: Spacing.md) {
                                    // Playlist artwork: first track's artwork, or placeholder
                                    let firstTrack = playlist.trackIDs.first.flatMap { id in allTracks.first { $0.id == id } }
                                    ArtworkView(data: firstTrack?.artworkData, size: 44, cornerRadius: Radius.sm)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(Typography.labelLarge)
                                            .foregroundStyle(Color("TextPrimary"))
                                        Text("\(playlist.trackCount) song\(playlist.trackCount == 1 ? "" : "s")")
                                            .font(Typography.bodySmall)
                                            .foregroundStyle(Color("TextSecondary"))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deletePlaylists)
                    }
                    .listStyle(.plain)
                    .background(Color("SurfaceBase"))
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPlaylistName = ""
                        showingNewPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("New playlist")
                }
            }
            .alert("New Playlist", isPresented: $showingNewPlaylist) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Create") { createPlaylist() }
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
            Text("No playlists yet")
                .font(Typography.labelLarge)
                .foregroundStyle(Color("TextSecondary"))
            Button("New Playlist") {
                newPlaylistName = ""
                showingNewPlaylist = true
            }
            .foregroundStyle(Color("Accent"))
            .font(Typography.labelMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let playlist = Playlist(name: name)
        modelContext.insert(playlist)
        try? modelContext.save()
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(playlists[i]) }
        try? modelContext.save()
    }
}

// MARK: - Playlist detail

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist
    let allTracks: [Track]
    @Environment(\.playbackCoordinator) private var coordinator
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.modelContext) private var modelContext

    private var orderedTracks: [Track] {
        playlist.trackIDs.compactMap { id in allTracks.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if orderedTracks.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Text("This playlist is empty")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(Color("TextSecondary"))
                        Text("Add songs from the Library.")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color("TextTertiary"))
                    }
                    .padding(.top, Spacing.xxl)
                } else {
                    ForEach(orderedTracks) { track in
                        TrackRow(track: track, isPlaying: playback.currentTrack?.id == track.id) {
                            Task { try? await coordinator?.loadQueue(tracks: orderedTracks, startIndex: orderedTracks.firstIndex(of: track) ?? 0) }
                        }
                        Divider().padding(.leading, Spacing.base + 44 + Spacing.md)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color("SurfaceBase").ignoresSafeArea())
        .navigationTitle(playlist.name)
    }
}
