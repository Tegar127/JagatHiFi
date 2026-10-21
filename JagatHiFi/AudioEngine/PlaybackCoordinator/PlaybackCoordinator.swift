// PlaybackCoordinator.swift — Central audio playback engine.
// Manages AVAudioEngine, player nodes, decoder lifecycle, and state transitions.
// Runs on a dedicated background actor; publishes state to @MainActor observers.

import Foundation
import AVFoundation
import Combine
import MediaPlayer

// MARK: - Published playback model (observed on main actor)

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published var state: PlaybackState = .idle
    @Published var queue: PlaybackQueue = PlaybackQueue()
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var replayGainSettings: ReplayGainSettings = .default
    @Published var currentTrack: Track?
    @Published var errorMessage: String?
}

// MARK: - Playback coordinator actor

actor PlaybackCoordinator {

    // MARK: - Audio engine

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var currentDecoder: (any AudioDecoder)?
    private var nextDecoder: (any AudioDecoder)?
    private var replayGain = ReplayGainProcessor(settings: .default)

    // MARK: - State

    private var internalQueue = PlaybackQueue()
    private var trackLookup: [UUID: Track] = [:]
    private var currentState: PlaybackState = .idle
    private var repeatMode: RepeatMode = .off
    private var isShuffled: Bool = false
    private var originalOrder: [UUID] = []

    // Scheduling
    private var scheduledSegmentCount: Int = 0
    private var isPreloadingNext: Bool = false
    private var currentSegmentID: UUID = .init()

    // Time tracking
    private var currentTime: Double = 0
    private var startHostTime: UInt64 = 0
    private var pausedAtTime: Double = 0

    // Coordination with ViewModel
    weak var viewModel: PlaybackViewModel?

    // MARK: - Setup

    func configure() throws {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        try engine.start()

        #if os(iOS)
        configureAudioSession()
        #endif
    }

    #if os(iOS)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            let msg = "Audio session error: \(error.localizedDescription)"
            Task { await self.publishError(msg) }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            Task { await self?.handleInterruption(note) }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            Task { await self?.handleRouteChange(note) }
        }
    }
    #endif

    // MARK: - Queue management

    func loadQueue(tracks: [Track], startIndex: Int = 0) async throws {
        trackLookup = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        originalOrder = tracks.map(\.id)
        internalQueue = PlaybackQueue(tracks: originalOrder, startingAt: startIndex)
        await publishViewModel()
        if let id = internalQueue.currentID {
            try await play(trackID: id)
        }
    }

    func playNext() async throws {
        switch repeatMode {
        case .one:
            if let id = internalQueue.currentID { try await play(trackID: id) }
        case .all:
            if internalQueue.hasNext {
                advanceQueue()
            } else {
                replaceQueue(tracks: internalQueue.isEmpty ? [] : originalOrder, startingAt: 0)
            }
            if let id = internalQueue.currentID { try await play(trackID: id) }
        case .off:
            guard internalQueue.hasNext else {
                await stop()
                return
            }
            advanceQueue()
            if let id = internalQueue.currentID { try await play(trackID: id) }
        }
    }

    func playPrevious() async throws {
        // If more than 3 seconds into the track, seek to start instead of going back.
        if currentTime > 3.0 {
            try await seek(to: 0)
            return
        }
        guard internalQueue.hasPrevious else {
            try await seek(to: 0)
            return
        }
        retreatQueue()
        if let id = internalQueue.currentID { try await play(trackID: id) }
    }

    // MARK: - Core playback controls

    func play(trackID: UUID) async throws {
        guard let track = trackLookup[trackID] else { return }

        // Cancel any pre-loading in progress
        currentSegmentID = UUID()
        isPreloadingNext = false

        // Stop current playback cleanly
        playerNode.stop()
        await currentDecoder?.close()
        currentDecoder = nil

        // Transition to loading state
        currentState = .loading(trackID: track.id)
        await publishViewModel(track: track)

        guard let decoder = AudioDecoderFactory.makeDecoder(for: track.fileURL) else {
            let err = "Unsupported format: \(track.fileURL.pathExtension)"
            currentState = .failed(trackID: track.id, reason: err)
            await publishError(err)
            return
        }

        do {
            try await decoder.open()
        } catch {
            currentState = .failed(trackID: track.id, reason: error.localizedDescription)
            await publishError(error.localizedDescription)
            return
        }

        currentDecoder = decoder

        // Resolve ReplayGain
        let resolvedGain = replayGain.resolveGain(
            trackGain: track.replayGainTrackGain,
            albumGain: track.replayGainAlbumGain,
            trackPeak: track.replayGainTrackPeak,
            albumPeak: track.replayGainAlbumPeak
        )

        // Reconfigure engine if format changed
        if let format = decoder.outputFormat {
            if !engine.isRunning { try engine.start() }
            // Reconnect with the correct format for the new track
            engine.disconnectNodeOutput(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        }

        // Schedule and start
        await scheduleBuffers(decoder: decoder, gain: resolvedGain, segmentID: currentSegmentID)

        currentState = .playing(trackID: track.id)
        currentTime = 0
        if let dur = track.duration > 0 ? track.duration : decoder.outputFormat.map({ _ in 0 }) {
            pausedAtTime = 0
            _ = dur
        }

        await publishViewModel(track: track)
        playerNode.play()

        // Pre-load next track after playback starts
        Task { await preloadNextTrack() }
    }

    func togglePlayPause() async {
        switch currentState {
        case .playing(let id):
            playerNode.pause()
            pausedAtTime = currentTime
            currentState = .paused(trackID: id)
            await publishViewModel()
        case .paused(let id):
            playerNode.play()
            currentState = .playing(trackID: id)
            await publishViewModel()
        default:
            break
        }
    }

    func stop() async {
        playerNode.stop()
        await currentDecoder?.close()
        currentDecoder = nil
        await nextDecoder?.close()
        nextDecoder = nil
        currentState = .idle
        currentTime = 0
        await publishViewModel()
    }

    func seek(to position: Double) async throws {
        guard let decoder = currentDecoder,
              let format = decoder.outputFormat,
              case let trackID = currentState.currentTrackID,
              let id = trackID else { return }

        playerNode.stop()

        let frame = AVAudioFramePosition(position * format.sampleRate)
        try await decoder.seek(to: frame)
        currentTime = position
        pausedAtTime = position

        // Re-schedule from new position
        await scheduleBuffers(decoder: decoder, gain: replayGain.resolveGain(
            trackGain: trackLookup[id]?.replayGainTrackGain,
            albumGain: trackLookup[id]?.replayGainAlbumGain,
            trackPeak: trackLookup[id]?.replayGainTrackPeak,
            albumPeak: trackLookup[id]?.replayGainAlbumPeak
        ), segmentID: currentSegmentID)

        if case .playing = currentState {
            playerNode.play()
        }
    }

    func setVolume(_ volume: Float) {
        playerNode.volume = max(0, min(1, volume))
    }

    func setShuffle(_ on: Bool) async {
        isShuffled = on
        if on {
            shuffleQueue()
        } else {
            let current = internalQueue.currentID
            replaceQueue(tracks: originalOrder)
            if let id = current, let pos = originalOrder.firstIndex(of: id) {
                replaceQueue(tracks: originalOrder, startingAt: pos)
            }
        }
        await publishViewModel()
    }

    func setRepeat(_ mode: RepeatMode) async {
        repeatMode = mode
        await publishViewModel()
    }

    func updateReplayGainSettings(_ settings: ReplayGainSettings) async {
        replayGain = ReplayGainProcessor(settings: settings)
        await publishViewModel()
    }

    // MARK: - Buffer scheduling

    private func scheduleBuffers(
        decoder: any AudioDecoder,
        gain: ResolvedGain,
        segmentID: UUID
    ) async {
        guard let format = decoder.outputFormat else { return }

        let bufferSize: AVAudioFrameCount = 8192
        var scheduledCount = 0

        while scheduledCount < 3 { // pre-fill 3 buffers
            guard currentSegmentID == segmentID else { return }
            do {
                guard let buffer = try await decoder.decode(frameCount: bufferSize) else { break }
                replayGain.apply(gain, to: buffer)
                await scheduleBuffer(buffer, format: format, segmentID: segmentID)
                scheduledCount += 1
            } catch {
                break
            }
        }

        // Continue scheduling on completion callbacks
        Task { await continuouslySchedule(decoder: decoder, gain: gain, segmentID: segmentID) }
    }

    @MainActor
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat, segmentID: UUID) {
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { [weak self] in
                await self?.bufferCompleted(segmentID: segmentID)
            }
        }
    }

    private func continuouslySchedule(
        decoder: any AudioDecoder,
        gain: ResolvedGain,
        segmentID: UUID
    ) async {
        let bufferSize: AVAudioFrameCount = 8192
        while true {
            guard currentSegmentID == segmentID else { return }
            do {
                guard let buffer = try await decoder.decode(frameCount: bufferSize) else {
                    // EOF — track will finish naturally via completion callbacks
                    return
                }
                replayGain.apply(gain, to: buffer)
                await scheduleBuffer(buffer, format: buffer.format, segmentID: segmentID)
            } catch {
                return
            }
        }
    }

    private func bufferCompleted(segmentID: UUID) async {
        guard currentSegmentID == segmentID else { return }
        // Update current time from playerNode's sample time
        updateCurrentTime()
        // Check if the track has actually finished
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
            if let trackID = currentState.currentTrackID,
               let track = trackLookup[trackID],
               track.duration > 0,
               elapsed >= track.duration - 0.1 {
                try? await playNext()
            }
        }
    }

    private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }
        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate + pausedAtTime
        currentTime = max(0, elapsed)
        let time = currentTime
        let vm = viewModel
        Task { @MainActor in
            vm?.currentTime = time
        }
    }

    // MARK: - Gapless pre-loading

    private func preloadNextTrack() async {
        guard !isPreloadingNext else { return }
        guard internalQueue.hasNext || repeatMode == .all else { return }

        isPreloadingNext = true
        defer { isPreloadingNext = false }

        var nextIndex = internalQueue.index + 1
        if nextIndex >= internalQueue.tracks.count && repeatMode == .all {
            nextIndex = 0
        }
        guard nextIndex < internalQueue.tracks.count else { return }

        let nextID = internalQueue.tracks[nextIndex]
        guard let nextTrack = trackLookup[nextID] else { return }

        await nextDecoder?.close()
        guard let decoder = AudioDecoderFactory.makeDecoder(for: nextTrack.fileURL) else { return }
        do {
            try await decoder.open()
            nextDecoder = decoder
        } catch {
            nextDecoder = nil
        }
    }

    // MARK: - Interruption and route handling

    #if os(iOS)
    private func handleInterruption(_ notification: Notification) async {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            if case .playing(let id) = currentState {
                playerNode.pause()
                currentState = .interrupted(trackID: id)
                await publishViewModel()
            }
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume), case .interrupted(let id) = currentState {
                try? AVAudioSession.sharedInstance().setActive(true)
                if !engine.isRunning { try? engine.start() }
                playerNode.play()
                currentState = .playing(trackID: id)
                await publishViewModel()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) async {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // Pause on headphone/DAC removal (standard iOS behaviour)
        if reason == .oldDeviceUnavailable {
            if case .playing(let id) = currentState {
                playerNode.pause()
                currentState = .paused(trackID: id)
                await publishViewModel()
            }
        }
    }
    #endif

    // MARK: - Queue mutation helpers

    private func advanceQueue() {
        var q = internalQueue
        q.advance()
        internalQueue = q
    }

    private func retreatQueue() {
        var q = internalQueue
        q.retreat()
        internalQueue = q
    }

    private func replaceQueue(tracks: [UUID], startingAt: Int = 0) {
        var q = internalQueue
        q.replace(tracks: tracks, startingAt: startingAt)
        internalQueue = q
    }

    private func shuffleQueue() {
        var q = internalQueue
        q.shuffle()
        internalQueue = q
    }

    // MARK: - ViewModel publishing

    private func publishViewModel(track: Track? = nil) async {
        let state = currentState
        let queue = internalQueue
        let repeat_ = repeatMode
        let shuffled = isShuffled
        let time = currentTime
        let resolvedTrack = track ?? (currentState.currentTrackID.flatMap { trackLookup[$0] })
        let duration = resolvedTrack?.duration ?? 0
        let vm = viewModel

        await MainActor.run {
            vm?.state = state
            vm?.queue = queue
            vm?.repeatMode = repeat_
            vm?.isShuffled = shuffled
            vm?.currentTime = time
            vm?.duration = duration
            if let t = resolvedTrack { vm?.currentTrack = t }
        }
    }

    private func publishError(_ message: String) async {
        let vm = viewModel
        await MainActor.run {
            vm?.errorMessage = message
        }
    }
}

// MARK: - PlaybackQueue initializer convenience

extension PlaybackQueue {
    init(tracks: [UUID], startingAt index: Int) {
        self.init(tracks: tracks, index: index)
    }
}
