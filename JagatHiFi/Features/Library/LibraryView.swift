// LibraryView.swift — Primary library browsing screen.
// Three states: empty (no tracks imported), loaded (track list), error (R-27).
// No AI template layout. Content structure follows actual library content.

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playbackCoordinator) private var coordinator
    @EnvironmentObject private var playback: PlaybackViewModel
    @EnvironmentObject private var libraryRepo: LibraryRepository

    @Query(sort: \Track.dateAdded, order: .reverse) private var tracks: [Track]
    @State private var searchText: String = ""
    @State private var showingImporter: Bool = false
    @State private var showingImportSummary: Bool = false
    @State private var sortOrder: TrackSortOrder = .dateAdded

    var body: some View {
        NavigationStack {
            Group {
                if tracks.isEmpty && !libraryRepo.isScanning {
                    emptyState
                } else if libraryRepo.isScanning {
                    loadingState
                } else {
                    trackList
                }
            }
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Library")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search songs, artists, albums")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    importButton
                }
                ToolbarItem(placement: .secondaryAction) {
                    sortMenu
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: supportedUTTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .alert("Import Result", isPresented: $showingImportSummary) {
                Button("OK", role: .cancel) {}
            } message: {
                if let summary = libraryRepo.lastImportSummary {
                    Text(importSummaryMessage(summary))
                }
            }
        }
    }

    // MARK: - Empty state (R-27)

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "music.note.list")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
            VStack(spacing: Spacing.xs) {
                Text("No music yet")
                    .font(Typography.albumTitle(20))
                    .foregroundStyle(Color("TextPrimary"))
                Text("Import audio files from your device or connected storage.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            Button("Import Music") {
                showingImporter = true
            }
            .foregroundStyle(Color("Accent"))
            .font(Typography.labelLarge)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color("AccentDimmed"))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityLabel("Import music files")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading state (R-27)

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView(value: libraryRepo.scanProgress?.fraction ?? 0)
                .tint(Color("Accent"))
                .padding(.horizontal, Spacing.xl)
            if let progress = libraryRepo.scanProgress {
                Text("Importing \(progress.current) of \(progress.total)...")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Track list

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredTracks) { track in
                    TrackRow(
                        track: track,
                        isPlaying: playback.currentTrack?.id == track.id
                    ) {
                        playTrack(track)
                    }
                    if track.id != filteredTracks.last?.id {
                        Divider()
                            .padding(.leading, Spacing.base + 44 + Spacing.md)
                    }
                }
            }
            .padding(.bottom, 100) // Room for NowPlayingBar
        }
    }

    // MARK: - Toolbar items

    private var importButton: some View {
        Button {
            showingImporter = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Import music")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOrder) {
                ForEach(TrackSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort options")
    }

    // MARK: - Filtering and sorting

    private var filteredTracks: [Track] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = query.isEmpty ? tracks : tracks.filter { track in
            track.displayTitle.localizedCaseInsensitiveContains(query)
            || track.displayArtist.localizedCaseInsensitiveContains(query)
            || track.displayAlbum.localizedCaseInsensitiveContains(query)
        }
        switch sortOrder {
        case .dateAdded: break // already sorted by query
        case .title:  result.sort { $0.displayTitle < $1.displayTitle }
        case .artist: result.sort { $0.displayArtist < $1.displayArtist }
        case .album:  result.sort { $0.displayAlbum < $1.displayAlbum }
        }
        return result
    }

    // MARK: - Import

    private var supportedUTTypes: [UTType] {
        [.audio, .mp3, .aiff, .wav, .init("org.xiph.flac") ?? .audio, .m4a]
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                _ = await libraryRepo.importFiles(urls)
                showingImportSummary = true
            }
        case .failure(let err):
            // Surface the error rather than silently swallowing it
            libraryRepo.lastImportSummary = LibraryRepository.ImportSummary(
                imported: 0, duplicates: 0, failed: 1,
                errors: [(URL(fileURLWithPath: "/"), err.localizedDescription)]
            )
            showingImportSummary = true
        }
    }

    private func playTrack(_ track: Track) {
        Task {
            try? await coordinator?.loadQueue(tracks: filteredTracks, startIndex: filteredTracks.firstIndex(of: track) ?? 0)
        }
    }

    private func importSummaryMessage(_ s: LibraryRepository.ImportSummary) -> String {
        var parts: [String] = []
        if s.imported > 0 { parts.append("\(s.imported) track\(s.imported == 1 ? "" : "s") imported") }
        if s.duplicates > 0 { parts.append("\(s.duplicates) already in library") }
        if s.failed > 0 { parts.append("\(s.failed) failed") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Sort order

enum TrackSortOrder: String, CaseIterable, Identifiable {
    case dateAdded, title, artist, album
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .title:     return "Title"
        case .artist:    return "Artist"
        case .album:     return "Album"
        }
    }
}
