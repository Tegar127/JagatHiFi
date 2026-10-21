// PlaybackState.swift — Explicit playback state machine and queue model.

import Foundation
import SwiftUI

// MARK: - Playback state

enum PlaybackState: Equatable, Sendable {
    case idle
    case loading(trackID: UUID)
    case playing(trackID: UUID)
    case paused(trackID: UUID)
    case interrupted(trackID: UUID)   // Audio session interruption; resumes on route restoration
    case failed(trackID: UUID, reason: String)

    var isActive: Bool {
        switch self {
        case .playing, .paused, .interrupted: return true
        default: return false
        }
    }

    var currentTrackID: UUID? {
        switch self {
        case .loading(let id), .playing(let id), .paused(let id),
             .interrupted(let id), .failed(let id, _): return id
        case .idle: return nil
        }
    }
}

// MARK: - Repeat mode

enum RepeatMode: String, CaseIterable, Codable, Sendable {
    case off      = "Off"
    case all      = "All"
    case one      = "One"

    var systemImageName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// MARK: - Queue

/// The ordered list of tracks to play, plus position tracking.
struct PlaybackQueue: Sendable {
    private(set) var tracks: [UUID]   // Track IDs in playback order
    private(set) var index: Int       // Current position; -1 if empty

    init(tracks: [UUID] = [], index: Int = -1) {
        self.tracks = tracks
        self.index = tracks.isEmpty ? -1 : max(0, min(index, tracks.count - 1))
    }

    var currentID: UUID? {
        guard !tracks.isEmpty, index >= 0, index < tracks.count else { return nil }
        return tracks[index]
    }

    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool { index < tracks.count - 1 }
    var isEmpty: Bool { tracks.isEmpty }

    mutating func advance() {
        guard hasNext else { return }
        index += 1
    }

    mutating func retreat() {
        guard hasPrevious else { return }
        index -= 1
    }

    mutating func replace(tracks newTracks: [UUID], startingAt startIndex: Int = 0) {
        tracks = newTracks
        index = newTracks.isEmpty ? -1 : max(0, min(startIndex, newTracks.count - 1))
    }

    mutating func appendNext(id: UUID) {
        let insertAt = min(index + 1, tracks.count)
        tracks.insert(id, at: insertAt)
    }

    mutating func append(id: UUID) {
        tracks.append(id)
        if index < 0 { index = 0 }
    }

    mutating func remove(at position: Int) {
        guard position >= 0, position < tracks.count else { return }
        tracks.remove(at: position)
        if tracks.isEmpty {
            index = -1
        } else if position < index {
            index -= 1
        } else if index >= tracks.count {
            index = tracks.count - 1
        }
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let currentID = self.currentID
        tracks.move(fromOffsets: source, toOffset: destination)
        // Restore index to follow the current track
        if let id = currentID {
            index = tracks.firstIndex(of: id) ?? index
        }
    }

    /// Shuffles all tracks except the current one, which stays at index 0.
    mutating func shuffle() {
        guard !tracks.isEmpty else { return }
        let current = currentID
        var rest = tracks.filter { $0 != current }
        rest.shuffle()
        if let current {
            tracks = [current] + rest
            index = 0
        } else {
            tracks = rest
            index = 0
        }
    }
}
