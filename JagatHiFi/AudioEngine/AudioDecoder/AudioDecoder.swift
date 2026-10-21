// AudioDecoder.swift — Abstract decoder interface.
// New decoders can be swapped in without changing the playback coordinator or UI.

import Foundation
import AVFoundation

// MARK: - Protocol

/// The contract for any audio decoder used by the playback engine.
/// Conforming types must be Sendable — decoding happens on a background queue.
protocol AudioDecoder: Sendable {

    /// Source file URL this decoder was opened for.
    var url: URL { get }

    /// Format of the decoded audio output (e.g. 44100 Hz, Float32, stereo).
    /// Populated after a successful open.
    var outputFormat: AVAudioFormat? { get }

    /// Total frame count, if known after opening. May be 0 for streamed sources.
    var frameCount: AVAudioFrameCount { get }

    /// Opens the file and prepares for decoding. Throws on unsupported/corrupted files.
    func open() async throws

    /// Decodes up to `frameCount` frames into a new PCM buffer.
    /// Returns nil when end-of-file is reached.
    func decode(frameCount: AVAudioFrameCount) async throws -> AVAudioPCMBuffer?

    /// Seeks to the nearest decodable position at or before `frame`.
    func seek(to frame: AVAudioFramePosition) async throws

    /// Releases resources. Safe to call multiple times.
    func close() async
}

// MARK: - Error types

enum AudioDecoderError: LocalizedError {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case openFailed(String)
    case decodeFailed(String)
    case seekFailed(String)
    case invalidFile(URL)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedFormat(let ext):
            return "Unsupported format: \(ext)"
        case .openFailed(let reason):
            return "Failed to open audio file: \(reason)"
        case .decodeFailed(let reason):
            return "Decoding error: \(reason)"
        case .seekFailed(let reason):
            return "Seek failed: \(reason)"
        case .invalidFile(let url):
            return "Invalid or corrupted file: \(url.lastPathComponent)"
        }
    }
}

// MARK: - Factory

/// Selects the appropriate decoder for a given file URL.
/// Returns nil when the format is not supported, so the caller can show an error.
struct AudioDecoderFactory {
    static func makeDecoder(for url: URL) -> (any AudioDecoder)? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "flac", "alac", "wav", "aiff", "aif", "mp3", "aac", "m4a":
            return AVAudioFileDecoder(url: url)
        default:
            return nil
        }
    }
}
