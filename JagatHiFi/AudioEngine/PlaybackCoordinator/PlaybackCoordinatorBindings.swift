// PlaybackCoordinatorBindings.swift
// Adds ViewModel binding and system command handling to PlaybackCoordinator.

import Foundation
import AVFoundation
import MediaPlayer

extension PlaybackCoordinator {

    /// Attaches a ViewModel and sets up system media/command observers.
    func bind(to viewModel: PlaybackViewModel) async {
        self.viewModel = viewModel

        // MediaPlayer remote command center (lock screen / Control Center)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { await self?.togglePlayPause() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { await self?.togglePlayPause() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { try? await self?.playNext() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { try? await self?.playPrevious() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { try? await self?.seek(to: e.positionTime) }
            return .success
        }

        #if os(macOS)
        // macOS menu command notifications
        NotificationCenter.default.addObserver(forName: Notification.Name("JHF.togglePlayPause"), object: nil, queue: nil) { [weak self] _ in
            Task { await self?.togglePlayPause() }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("JHF.nextTrack"), object: nil, queue: nil) { [weak self] _ in
            Task { try? await self?.playNext() }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("JHF.prevTrack"), object: nil, queue: nil) { [weak self] _ in
            Task { try? await self?.playPrevious() }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("JHF.toggleShuffle"), object: nil, queue: nil) { [weak self] _ in
            Task {
                guard let self else { return }
                let current = await self.viewModel?.isShuffled ?? false
                await self.setShuffle(!current)
            }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("JHF.toggleRepeat"), object: nil, queue: nil) { [weak self] _ in
            Task {
                guard let self else { return }
                let current = await self.viewModel?.repeatMode ?? .off
                let next: RepeatMode
                switch current {
                case .off: next = .all
                case .all: next = .one
                case .one: next = .off
                }
                await self.setRepeat(next)
            }
        }
        #endif
    }

    /// Updates the Now Playing info center with the current track's metadata.
    func updateNowPlayingInfo(track: Track, currentTime: Double, duration: Double) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle]       = track.displayTitle
        info[MPMediaItemPropertyArtist]      = track.displayArtist
        info[MPMediaItemPropertyAlbumTitle]  = track.displayAlbum
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        if let data = track.artworkData {
            #if os(iOS)
            if let img = UIImage(data: data) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 512, height: 512)) { _ in img }
            }
            #elseif os(macOS)
            if let img = NSImage(data: data) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: NSSize(width: 512, height: 512)) { _ in img }
            }
            #endif
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
