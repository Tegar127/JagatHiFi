// AVAudioFileDecoder.swift
// Concrete AudioDecoder using AVAudioFile (FLAC, ALAC, WAV, AIFF, MP3, AAC, M4A).
// AVAudioFile handles decoding natively on Apple platforms for all these formats.

import Foundation
import AVFoundation

actor AVAudioFileDecoder: AudioDecoder {

    nonisolated let url: URL
    private var audioFile: AVAudioFile?
    private(set) nonisolated(unsafe) var outputFormat: AVAudioFormat?
    private(set) nonisolated(unsafe) var frameCount: AVAudioFrameCount = 0

    // Buffer size per read. 4096 frames is typical; large enough for efficiency,
    // small enough for responsive seeking.
    private let readFrameCount: AVAudioFrameCount = 4096

    init(url: URL) {
        self.url = url
    }

    // MARK: - AudioDecoder

    func open() async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioDecoderError.fileNotFound(url)
        }

        do {
            // AVAudioFile reads the file at the original bit depth and sample rate.
            // The output format here is the processing format (Float32, same sample rate).
            let file = try AVAudioFile(forReading: url)
            self.audioFile = file
            self.outputFormat = file.processingFormat
            self.frameCount = AVAudioFrameCount(file.length)
        } catch {
            throw AudioDecoderError.openFailed(error.localizedDescription)
        }
    }

    func decode(frameCount requested: AVAudioFrameCount) async throws -> AVAudioPCMBuffer? {
        guard let file = audioFile, let format = outputFormat else {
            throw AudioDecoderError.openFailed("Decoder not opened")
        }

        // End of file
        if file.framePosition >= file.length { return nil }

        let framesToRead = min(requested, AVAudioFrameCount(file.length - file.framePosition))
        guard framesToRead > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
            throw AudioDecoderError.decodeFailed("Could not allocate PCM buffer")
        }

        do {
            try file.read(into: buffer, frameCount: framesToRead)
        } catch {
            throw AudioDecoderError.decodeFailed(error.localizedDescription)
        }

        guard buffer.frameLength > 0 else { return nil }
        return buffer
    }

    func seek(to frame: AVAudioFramePosition) async throws {
        guard let file = audioFile else {
            throw AudioDecoderError.seekFailed("Decoder not opened")
        }
        guard frame >= 0 && frame <= file.length else {
            throw AudioDecoderError.seekFailed("Frame position \(frame) out of range (0...\(file.length))")
        }
        file.framePosition = frame
    }

    func close() async {
        audioFile = nil
        outputFormat = nil
        frameCount = 0
    }
}
