// AppRootView.swift — Platform-adaptive root view.
// iOS: TabView with NowPlayingBar overlay.
// macOS: NavigationSplitView with sidebar and Now Playing bar.

import SwiftUI
import SwiftData
import Combine

struct AppRootView: View {
    @EnvironmentObject private var playback: PlaybackViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var nowPlayingExpanded: Bool = false

    var body: some View {
#if os(iOS)
        iOSRoot
#else
        macOSRoot
#endif
    }

    // MARK: - iOS root

#if os(iOS)
    @State private var selectedTab: AppTab = .library

    private var iOSRoot: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Library", systemImage: "music.note.list", value: AppTab.library) {
                    libraryTabContent
                }
                Tab("Albums", systemImage: "square.stack", value: AppTab.albums) {
                    AlbumsView()
                }
                Tab("Artists", systemImage: "music.mic", value: AppTab.artists) {
                    ArtistsView()
                }
                Tab("Playlists", systemImage: "music.note.list", value: AppTab.playlists) {
                    PlaylistsView()
                }
            }
            .tint(Color("Accent"))

            // Persistent Now Playing bar above tab bar
            VStack(spacing: 0) {
                Spacer()
                if playback.currentTrack != nil {
                    NowPlayingBar(playback: playback, isExpanded: $nowPlayingExpanded)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: playback.currentTrack?.id)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $nowPlayingExpanded) {
            NowPlayingView(playback: playback, isPresented: $nowPlayingExpanded)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .withLibraryRepo()
    }

    private var libraryTabContent: some View {
        LibraryView()
    }
#endif

    // MARK: - macOS root

#if os(macOS)
    @State private var selectedSidebarItem: SidebarItem? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var macOSRoot: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                macOSSidebar
            } detail: {
                macOSDetailArea
            }
            .frame(minWidth: 800, minHeight: 500)

            // Persistent Now Playing bar at bottom of window
            if playback.currentTrack != nil {
                NowPlayingBar(playback: playback, isExpanded: $nowPlayingExpanded)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Motion.spring, value: playback.currentTrack?.id)
            }
        }
        .sheet(isPresented: $nowPlayingExpanded) {
            NowPlayingView(playback: playback, isPresented: $nowPlayingExpanded)
                .frame(minWidth: 400, minHeight: 600)
        }
        .withLibraryRepo()
    }

    private var macOSSidebar: some View {
        List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
            Label(item.label, systemImage: item.systemImage)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("Jagat Hi-Fi")
        .frame(minWidth: 180)
    }

    private var macOSDetailArea: some View {
        Group {
            switch selectedSidebarItem {
            case .library, nil: LibraryView()
            case .albums:       AlbumsView()
            case .artists:      ArtistsView()
            case .playlists:    PlaylistsView()
            case .favorites:    FavoritesView()
            case .recentlyAdded: RecentlyAddedView()
            case .settings:     SettingsView()
            }
        }
    }
#endif
}

// MARK: - App tabs (iOS)

enum AppTab: Hashable {
    case library, albums, artists, playlists
}

// MARK: - Sidebar items (macOS)

enum SidebarItem: String, CaseIterable, Identifiable {
    case library, albums, artists, playlists, favorites, recentlyAdded, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .library:      return "Songs"
        case .albums:       return "Albums"
        case .artists:      return "Artists"
        case .playlists:    return "Playlists"
        case .favorites:    return "Favorites"
        case .recentlyAdded: return "Recently Added"
        case .settings:     return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .library:      return "music.note"
        case .albums:       return "square.stack"
        case .artists:      return "music.mic"
        case .playlists:    return "music.note.list"
        case .favorites:    return "heart"
        case .recentlyAdded: return "clock"
        case .settings:     return "gearshape"
        }
    }
}

// MARK: - View modifier for LibraryRepository injection

private struct LibraryRepoKey: EnvironmentKey {
    static let defaultValue: LibraryRepository? = nil
}

extension View {
    func withLibraryRepo() -> some View {
        self.modifier(LibraryRepoModifier())
    }
}

private struct LibraryRepoModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var repo = LibraryRepositoryStore.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(repo.repository(for: modelContext))
    }
}

// Lazy singleton to avoid recreating the repository
private final class LibraryRepositoryStore: ObservableObject {
    static let shared = LibraryRepositoryStore()
    private var _repo: LibraryRepository?

    @MainActor
    func repository(for context: ModelContext) -> LibraryRepository {
        if let r = _repo { return r }
        let r = LibraryRepository(modelContext: context)
        _repo = r
        return r
    }
}
