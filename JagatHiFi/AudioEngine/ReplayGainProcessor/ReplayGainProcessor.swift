// ReplayGainProcessor.swift — Applies ReplayGain gain adjustment to PCM audio buffers.
// This is a pure computation component, independent of SwiftUI and playback plumbing.

import Foundation
import AVFoundation
import Accelerate

// MARK: - Settings

enum ReplayGainMode: String, CaseIterable, Codable, Sendable {
    case disabled = "Disabled"
    case track    = "Track"
    case album    = "Album"
}

struct ReplayGainSettings: Sendable, Codable {
    var mode: ReplayGainMode = .track
    /// User preamp in dB, applied on top of the tag gain. Range: -12 to +12 dB.
    var preamp: Double = 0.0
    /// Prevent clipping based on peak information.
    var preventClipping: Bool = true

    static let `default` = ReplayGainSettings()
}

// MARK: - Gain resolution

struct ResolvedGain: Sendable {
    let linearGain: Float   // Multiplier to apply to PCM samples
    let source: GainSource

    enum GainSource: Sendable {
        case trackTag(dB: Double)
        case albumTag(dB: Double)
        case unity               // No tag; gain = 1.0
        case disabled
    }
}

/// Resolves and applies ReplayGain to audio according to settings and available tags.
struct ReplayGainProcessor: Sendable {

    let settings: ReplayGainSettings

    // MARK: - Gain resolution

    /// Resolves the linear gain multiplier for a given track's ReplayGain metadata.
    /// Documented calculation: linear = 10 ^ ((gain_dB + preamp_dB) / 20)
    func resolveGain(
        trackGain: Double?,
        albumGain: Double?,
        trackPeak: Double?,
        albumPeak: Double?
    ) -> ResolvedGain {
        guard settings.mode != .disabled else {
            return ResolvedGain(linearGain: 1.0, source: .disabled)
        }

        let (gainDB, peak, source): (Double, Double?, ResolvedGain.GainSource)
        switch settings.mode {
        case .album:
            if let ag = albumGain {
                gainDB = ag
                peak   = albumPeak ?? trackPeak
                source = .albumTag(dB: ag)
            } else if let tg = trackGain {
                // Fall back to track gain when album gain is absent
                gainDB = tg
                peak   = trackPeak
                source = .trackTag(dB: tg)
            } else {
                return ResolvedGain(linearGain: 1.0, source: .unity)
            }
        case .track:
            if let tg = trackGain {
                gainDB = tg
                peak   = trackPeak
                source = .trackTag(dB: tg)
            } else {
                return ResolvedGain(linearGain: 1.0, source: .unity)
            }
        case .disabled:
            return ResolvedGain(linearGain: 1.0, source: .disabled)
        }

        let adjustedDB = gainDB + settings.preamp
        var linear = Float(pow(10.0, adjustedDB / 20.0))

        // Clipping prevention: if peak * linear > 1.0, cap linear to 1.0 / peak
        if settings.preventClipping, let peak, peak > 0 {
            let maxLinear = Float(1.0 / peak)
            linear = min(linear, maxLinear)
        }

        return ResolvedGain(linearGain: linear, source: source)
    }

    // MARK: - In-place application to PCM buffer

    /// Applies the linear gain multiplier to all channels of a float PCM buffer.
    /// This runs on a background audio queue, not on the main thread.
    /// Does not modify the original file.
    func apply(_ gain: ResolvedGain, to buffer: AVAudioPCMBuffer) {
        guard gain.linearGain != 1.0 else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0 ..< channelCount {
            let data = channelData[channel]
            vDSP_vsmul(data, 1, [gain.linearGain], data, 1, vDSP_Length(frameCount))
        }
    }
}
