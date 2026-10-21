// Playlist.swift — SwiftData model for user-created playlists.

import Foundation
import SwiftData

/// A user-created ordered playlist.
@Model
final class Playlist: @unchecked Sendable {

    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    /// Ordered track IDs. Track objects are fetched separately to keep
    /// the playlist row lightweight and avoid cascade issues on track removal.
    var trackIDs: [UUID]

    init(name: String, id: UUID = .init()) {
        self.id = id
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.trackIDs = []
    }

    var trackCount: Int { trackIDs.count }
}
