// SettingsView.swift — User preferences: ReplayGain, audio output info.

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.playbackCoordinator) private var coordinator
    @EnvironmentObject private var playback: PlaybackViewModel

    var body: some View {
        NavigationStack {
            Form {
                replayGainSection
                audioOutputSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color("SurfaceBase").ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }

    // MARK: - ReplayGain

    private var replayGainSection: some View {
        Section {
            Picker("Mode", selection: $playback.replayGainSettings.mode) {
                ForEach(ReplayGainMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .onChange(of: playback.replayGainSettings.mode) { _, _ in
                Task { await coordinator?.updateReplayGainSettings(playback.replayGainSettings) }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Preamp")
                    Spacer()
                    Text(String(format: "%+.1f dB", playback.replayGainSettings.preamp))
                        .font(Typography.techReadout)
                        .foregroundStyle(Color("TextSecondary"))
                }
                Slider(value: $playback.replayGainSettings.preamp, in: -12...12, step: 0.5)
                    .tint(Color("Accent"))
                    .onChange(of: playback.replayGainSettings.preamp) { _, _ in
                        Task { await coordinator?.updateReplayGainSettings(playback.replayGainSettings) }
                    }
            }

            Toggle("Prevent Clipping", isOn: $playback.replayGainSettings.preventClipping)
                .tint(Color("Accent"))
                .onChange(of: playback.replayGainSettings.preventClipping) { _, _ in
                    Task { await coordinator?.updateReplayGainSettings(playback.replayGainSettings) }
                }
        } header: {
            Text("ReplayGain")
        } footer: {
            Text("Adjusts volume based on tags embedded in your audio files. Does not modify the original files.")
                .font(Typography.bodySmall)
                .foregroundStyle(Color("TextTertiary"))
        }
    }

    // MARK: - Audio output

    private var audioOutputSection: some View {
        Section("Output") {
            outputInfoRow(label: "Route", value: currentOutputRoute)
#if os(macOS)
            outputInfoRow(label: "Device", value: currentOutputDevice)
#endif
        }
    }

    private func outputInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            Text(value)
                .font(Typography.techReadout)
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var currentOutputRoute: String {
#if os(iOS)
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.first?.portName ?? "Unknown"
#else
        return currentOutputDevice
#endif
    }

#if os(macOS)
    private var currentOutputDevice: String {
        // Use Core Audio to get the default output device name.
        var defaultDeviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size, &defaultDeviceID
        )
        guard status == noErr, defaultDeviceID != kAudioObjectUnknown else { return "Unknown" }
        return deviceName(for: defaultDeviceID) ?? "Unknown"
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return status == noErr ? name as String : nil
    }
#endif

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0 (1)")
                    .foregroundStyle(Color("TextSecondary"))
            }
            HStack {
                Text("Decoder")
                Spacer()
                Text("AVAudioFile (AVFoundation)")
                    .font(Typography.techReadout)
                    .foregroundStyle(Color("TextSecondary"))
            }
            HStack {
                Text("Gapless")
                Spacer()
                Text("Scheduled buffers")
                    .font(Typography.techReadout)
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }
}
