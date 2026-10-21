// MetadataReader.swift — Reads audio metadata from local files using AVFoundation.
// Supports FLAC, ALAC, WAV, AIFF, MP3, AAC/M4A via AVAsset.
// For FLAC specifically, reads ID3/Vorbis comment tags via AVMetadataItem.

import Foundation
import AVFoundation

/// Raw metadata extracted from a file. All fields optional — no fabrication of missing values.
struct RawTrackMetadata: Sendable {
    var title: String?
    var artist: String?
    var albumArtist: String?
    var album: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var trackTotal: Int?
    var discNumber: Int?
    var discTotal: Int?
    var duration: Double?
    var comment: String?
    var artworkData: Data?

    // Technical
    var format: AudioFormat = .unknown
    var sampleRate: Double?
    var bitDepth: Int?
    var channelCount: Int?

    // ReplayGain — parsed from tags, nil means tag absent (not zero)
    var replayGainTrackGain: Double?
    var replayGainAlbumGain: Double?
    var replayGainTrackPeak: Double?
    var replayGainAlbumPeak: Double?
}

/// Reads metadata asynchronously from a local audio file URL.
actor MetadataReader {

    /// Detects format from file extension. AVFoundation handles the actual decoding.
    static func detectFormat(url: URL) -> AudioFormat {
        switch url.pathExtension.lowercased() {
        case "flac": return .flac
        case "alac": return .alac
        case "wav":  return .wav
        case "aiff", "aif": return .aiff
        case "mp3":  return .mp3
        case "aac":  return .aac
        case "m4a":  return .m4a
        default:     return .unknown
        }
    }

    /// Reads metadata from a file URL. Throws on access failure; returns partial data on parse failure.
    func read(from url: URL, accessingSecurityScope: Bool = false) async throws -> RawTrackMetadata {
        if accessingSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                throw MetadataError.securityScopeAccessDenied(url)
            }
            defer { url.stopAccessingSecurityScopedResource() }
            return try await readInternal(url: url)
        } else {
            return try await readInternal(url: url)
        }
    }

    private func readInternal(url: URL) async throws -> RawTrackMetadata {
        let asset = AVURLAsset(url: url)
        var meta = RawTrackMetadata()
        meta.format = Self.detectFormat(url: url)

        // Duration
        let duration = try await asset.load(.duration)
        if duration.isValid && !duration.isIndefinite {
            meta.duration = duration.seconds
        }

        // Audio track info
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        if let audioTrack = tracks.first {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let desc = formatDescriptions.first {
                let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
                meta.sampleRate  = basic.map { $0.mSampleRate }
                meta.channelCount = basic.map { Int($0.mChannelsPerFrame) }
                // Bit depth: available from mBitsPerChannel when > 0
                if let bits = basic?.mBitsPerChannel, bits > 0 {
                    meta.bitDepth = Int(bits)
                }
            }
        }

        // Metadata items
        let items = try await asset.load(.commonMetadata) + asset.load(.metadata)
        parseMetadataItems(items, into: &meta)

        return meta
    }

    private func parseMetadataItems(_ items: [AVMetadataItem], into meta: inout RawTrackMetadata) {
        var replayGainRaw: [String: String] = [:]

        for item in items {
            guard let key = item.commonKey ?? item.key.flatMap({ AVMetadataKey(rawValue: "\($0)") }) else { continue }
            let keyStr = key.rawValue.lowercased()

            // Common metadata keys
            switch key {
            case .commonKeyTitle:
                meta.title = item.stringValue
            case .commonKeyArtist:
                meta.artist = item.stringValue
            case .commonKeyAlbumName:
                meta.album = item.stringValue
            case .commonKeyArtwork:
                meta.artworkData = item.dataValue
            default:
                break
            }

            // Extended / ID3 / Vorbis comment keys
            switch keyStr {
            case "albumartist", "tpe2", "album artist":
                if let v = item.stringValue { meta.albumArtist = v }
            case "genre", "tcon":
                if let v = item.stringValue { meta.genre = v }
            case "tyer", "tdrc", "date", "year":
                if let v = item.stringValue { meta.year = parseYear(v) }
            case "trck", "tracknumber":
                if let v = item.stringValue { parseTrackNumber(v, into: &meta) }
            case "tpos", "discnumber":
                if let v = item.stringValue { parseDiscNumber(v, into: &meta) }
            case "comment", "comm":
                if let v = item.stringValue { meta.comment = v }
            case "replaygain_track_gain":
                if let v = item.stringValue { replayGainRaw["track_gain"] = v }
            case "replaygain_album_gain":
                if let v = item.stringValue { replayGainRaw["album_gain"] = v }
            case "replaygain_track_peak":
                if let v = item.stringValue { replayGainRaw["track_peak"] = v }
            case "replaygain_album_peak":
                if let v = item.stringValue { replayGainRaw["album_peak"] = v }
            default:
                break
            }
        }

        // Parse ReplayGain values
        meta.replayGainTrackGain = replayGainRaw["track_gain"].flatMap(parseGainTag)
        meta.replayGainAlbumGain = replayGainRaw["album_gain"].flatMap(parseGainTag)
        meta.replayGainTrackPeak = replayGainRaw["track_peak"].flatMap(parsePeakTag)
        meta.replayGainAlbumPeak = replayGainRaw["album_peak"].flatMap(parsePeakTag)
    }

    // MARK: - Tag parsers

    private func parseYear(_ string: String) -> Int? {
        let digits = string.prefix(4)
        return Int(digits)
    }

    private func parseTrackNumber(_ string: String, into meta: inout RawTrackMetadata) {
        let parts = string.split(separator: "/")
        meta.trackNumber = Int(parts.first?.trimmingCharacters(in: .whitespaces) ?? "")
        if parts.count > 1 {
            meta.trackTotal = Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
    }

    private func parseDiscNumber(_ string: String, into meta: inout RawTrackMetadata) {
        let parts = string.split(separator: "/")
        meta.discNumber = Int(parts.first?.trimmingCharacters(in: .whitespaces) ?? "")
        if parts.count > 1 {
            meta.discTotal = Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
    }

    /// Parses a ReplayGain gain tag, e.g. "-6.54 dB". Rejects out-of-range values.
    /// Valid range: -60 dB to +60 dB.
    private func parseGainTag(_ string: String) -> Double? {
        let stripped = string.replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)
                             .trimmingCharacters(in: .whitespaces)
        guard let value = Double(stripped) else { return nil }
        guard value >= -60.0 && value <= 60.0 else { return nil }
        return value
    }

    /// Parses a ReplayGain peak tag, e.g. "0.9981". Valid range: 0.0 to 2.0.
    private func parsePeakTag(_ string: String) -> Double? {
        let stripped = string.trimmingCharacters(in: .whitespaces)
        guard let value = Double(stripped) else { return nil }
        guard value >= 0.0 && value <= 2.0 else { return nil }
        return value
    }
}

// MARK: - Errors

enum MetadataError: LocalizedError {
    case securityScopeAccessDenied(URL)
    case unreadableFile(URL)
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .securityScopeAccessDenied(let url):
            return "Access denied to \(url.lastPathComponent). The file may have moved or permissions were revoked."
        case .unreadableFile(let url):
            return "Cannot read \(url.lastPathComponent). The file may be corrupted."
        case .unsupportedFormat(let ext):
            return "The file format \"\(ext)\" is not supported."
        }
    }
}
