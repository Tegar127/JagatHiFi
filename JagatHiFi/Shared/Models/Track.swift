// Track.swift — Core domain model for a music track.
// Uses SwiftData for persistence. File access uses security-scoped bookmarks.

import Foundation
import SwiftData

/// The codec/container format detected for a source file.
enum AudioFormat: String, Codable, Sendable {
    case flac = "FLAC"
    case alac = "ALAC"
    case wav  = "WAV"
    case aiff = "AIFF"
    case mp3  = "MP3"
    case aac  = "AAC"
    case m4a  = "M4A"
    case unknown = "Unknown"
}

/// Persistent model for a single audio track in the library.
@Model
final class Track: @unchecked Sendable {

    // MARK: – Identity

    @Attribute(.unique) var id: UUID
    var dateAdded: Date

    // MARK: – File

    /// Last-known absolute path. May become stale if the file moves.
    var filePath: String
    /// Security-scoped bookmark data for sandbox-persistent access.
    var bookmarkData: Data?

    // MARK: – Metadata

    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var genre: String
    var year: Int?
    var trackNumber: Int?
    var trackTotal: Int?
    var discNumber: Int?
    var discTotal: Int?
    var duration: Double      // seconds; 0 if unknown
    var comment: String

    // MARK: – Technical

    var format: AudioFormat
    var sampleRate: Double?   // Hz, e.g. 44100, 96000
    var bitDepth: Int?        // bits per sample, e.g. 16, 24
    var channelCount: Int?    // 1=mono, 2=stereo, …

    // MARK: – ReplayGain (stored in dB; nil means tag absent)

    var replayGainTrackGain: Double?
    var replayGainAlbumGain: Double?
    var replayGainTrackPeak: Double?
    var replayGainAlbumPeak: Double?

    // MARK: – User State

    var isFavorite: Bool
    var lastPlayedAt: Date?
    var playCount: Int

    // MARK: – Artwork

    /// Embedded artwork as raw JPEG/PNG bytes, if present.
    /// Stored separately to avoid bloating queries. Use ArtworkCache for display.
    @Attribute(.externalStorage) var artworkData: Data?

    // MARK: – Init

    init(
        id: UUID = .init(),
        filePath: String,
        bookmarkData: Data? = nil,
        title: String = "",
        artist: String = "",
        albumArtist: String = "",
        album: String = "",
        genre: String = "",
        year: Int? = nil,
        trackNumber: Int? = nil,
        trackTotal: Int? = nil,
        discNumber: Int? = nil,
        discTotal: Int? = nil,
        duration: Double = 0,
        comment: String = "",
        format: AudioFormat = .unknown,
        sampleRate: Double? = nil,
        bitDepth: Int? = nil,
        channelCount: Int? = nil,
        replayGainTrackGain: Double? = nil,
        replayGainAlbumGain: Double? = nil,
        replayGainTrackPeak: Double? = nil,
        replayGainAlbumPeak: Double? = nil,
        isFavorite: Bool = false,
        artworkData: Data? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.filePath = filePath
        self.bookmarkData = bookmarkData
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.album = album
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.trackTotal = trackTotal
        self.discNumber = discNumber
        self.discTotal = discTotal
        self.duration = duration
        self.comment = comment
        self.format = format
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.replayGainTrackGain = replayGainTrackGain
        self.replayGainAlbumGain = replayGainAlbumGain
        self.replayGainTrackPeak = replayGainTrackPeak
        self.replayGainAlbumPeak = replayGainAlbumPeak
        self.isFavorite = isFavorite
        self.artworkData = artworkData
        self.dateAdded = dateAdded
        self.lastPlayedAt = nil
        self.playCount = 0
    }

    // MARK: – Derived display helpers

    var displayTitle: String { title.isEmpty ? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent : title }
    var displayArtist: String { artist.isEmpty ? "Unknown Artist" : artist }
    var displayAlbum: String { album.isEmpty ? "Unknown Album" : album }
    var displayAlbumArtist: String { albumArtist.isEmpty ? displayArtist : albumArtist }
    var fileURL: URL { URL(fileURLWithPath: filePath) }

    var isFileAccessible: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }

    var formattedDuration: String {
        guard duration > 0 else { return "--:--" }
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
