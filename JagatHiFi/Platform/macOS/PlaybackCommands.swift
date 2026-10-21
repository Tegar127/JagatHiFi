// PlaybackCommands.swift — macOS menu commands for playback.
// All commands have real keyboard shortcuts and real actions (R-26).

#if os(macOS)
import SwiftUI

struct PlaybackCommands: Commands {
    var body: some Commands {
        CommandMenu("Playback") {
            Button("Play / Pause") { postNotification("togglePlayPause") }
                .keyboardShortcut(" ", modifiers: [])

            Button("Next Track") { postNotification("nextTrack") }
                .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("Previous Track") { postNotification("prevTrack") }
                .keyboardShortcut(.leftArrow, modifiers: .command)

            Divider()

            Button("Toggle Shuffle") { postNotification("toggleShuffle") }
                .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Toggle Repeat") { postNotification("toggleRepeat") }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }

    private func postNotification(_ name: String) {
        NotificationCenter.default.post(name: Notification.Name("JHF.\(name)"), object: nil)
    }
}
#endif
