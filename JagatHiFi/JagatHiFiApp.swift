// JagatHiFiApp.swift — Application entry point. Configures SwiftData, playback, and platform roots.

import SwiftUI
import SwiftData

@main
struct JagatHiFiApp: App {

    @StateObject private var playbackViewModel = PlaybackViewModel()
    private let coordinator = PlaybackCoordinator()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(playbackViewModel)
                .environment(\.playbackCoordinator, coordinator)
                .modelContainer(for: [Track.self, Playlist.self])
                .preferredColorScheme(.dark)
                // Dark scheme is appropriate here: audiophile tools have strong precedent
                // for dark-first UI (Roon, Plexamp, VOX). Not forced without reason (R-21).
                .task {
                    do {
                        try coordinator.configure()
                        await coordinator.bind(to: playbackViewModel)
                    } catch {
                        playbackViewModel.errorMessage = "Playback engine could not start: \(error.localizedDescription)"
                    }
                }
        }
#if os(macOS)
        .commands {
            PlaybackCommands()
        }
#endif
    }
}
