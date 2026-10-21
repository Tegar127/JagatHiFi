// LibraryRepository.swift — Manages the SwiftData music library.
// Handles file importing, bookmark persistence, metadata extraction, and duplicate detection.

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import result

enum ImportResult: Sendable {
    case success(track: Track)
    case duplicate(existing: Track)
    case failure(url: URL, error: Error)
}

// MARK: - Scan progress

struct ScanProgress: Sendable {
    let current: Int
    let total: Int
    var fraction: Double { total > 0 ? Double(current) / Double(total) : 0 }
}

// MARK: - Repository

@MainActor
final class LibraryRepository: ObservableObject {

    @Published var isScanning: Bool = false
    @Published var scanProgress: ScanProgress?
    @Published var lastImportSummary: ImportSummary?

    private let modelContext: ModelContext
    private let metadataReader = MetadataReader()

    struct ImportSummary {
        let imported: Int
        let duplicates: Int
        let failed: Int
        let errors: [(URL, String)]
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Importing

    /// Imports an array of file URLs. Creates security-scoped bookmarks where needed.
    func importFiles(_ urls: [URL]) async -> ImportSummary {
        isScanning = true
        scanProgress = ScanProgress(current: 0, total: urls.count)
        defer {
            isScanning = false
            scanProgress = nil
        }

        var imported = 0, duplicates = 0, failed = 0
        var errors: [(URL, String)] = []

        for (i, url) in urls.enumerated() {
            scanProgress = ScanProgress(current: i + 1, total: urls.count)
            let result = await importSingle(url: url)
            switch result {
            case .success:    imported += 1
            case .duplicate:  duplicates += 1
            case .failure(_, let err):
                failed += 1
                errors.append((url, err.localizedDescription))
            }
        }

        let summary = ImportSummary(
            imported: imported,
            duplicates: duplicates,
            failed: failed,
            errors: errors
        )
        lastImportSummary = summary
        return summary
    }

    private func importSingle(url: URL) async -> ImportResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        // Duplicate check: same absolute path
        let path = url.path
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate { $0.filePath == path }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return .duplicate(existing: existing)
        }

        // Format support check
        let ext = url.pathExtension.lowercased()
        guard ["flac","alac","wav","aiff","aif","mp3","aac","m4a"].contains(ext) else {
            return .failure(url: url, error: MetadataError.unsupportedFormat(ext))
        }

        // Bookmark for persistent sandbox access
        let bookmarkData = try? url.bookmarkData(
            options: bookmarkCreationOptions(),
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Read metadata
        var meta: RawTrackMetadata
        do {
            meta = try await metadataReader.read(from: url, accessingSecurityScope: false)
        } catch {
            // Create a minimal track even if metadata fails — file is still importable
            meta = RawTrackMetadata()
            meta.format = MetadataReader.detectFormat(url: url)
        }

        let track = Track(
            filePath: path,
            bookmarkData: bookmarkData,
            title: meta.title ?? "",
            artist: meta.artist ?? "",
            albumArtist: meta.albumArtist ?? "",
            album: meta.album ?? "",
            genre: meta.genre ?? "",
            year: meta.year,
            trackNumber: meta.trackNumber,
            trackTotal: meta.trackTotal,
            discNumber: meta.discNumber,
            discTotal: meta.discTotal,
            duration: meta.duration ?? 0,
            comment: meta.comment ?? "",
            format: meta.format,
            sampleRate: meta.sampleRate,
            bitDepth: meta.bitDepth,
            channelCount: meta.channelCount,
            replayGainTrackGain: meta.replayGainTrackGain,
            replayGainAlbumGain: meta.replayGainAlbumGain,
            replayGainTrackPeak: meta.replayGainTrackPeak,
            replayGainAlbumPeak: meta.replayGainAlbumPeak,
            artworkData: meta.artworkData
        )

        modelContext.insert(track)
        do {
            try modelContext.save()
            return .success(track: track)
        } catch {
            modelContext.delete(track)
            return .failure(url: url, error: error)
        }
    }

    // MARK: - Bookmark resolution

    /// Resolves a security-scoped bookmark, refreshing stale data if needed.
    func resolveBookmark(for track: Track) throws -> URL {
        guard let data = track.bookmarkData else {
            // Fall back to stored path — may work if sandbox access was already granted
            guard FileManager.default.fileExists(atPath: track.filePath) else {
                throw BookmarkError.missingBookmark(track.filePath)
            }
            return URL(fileURLWithPath: track.filePath)
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: bookmarkResolutionOptions(),
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            // Refresh bookmark data
            if let fresh = try? url.bookmarkData(
                options: bookmarkCreationOptions(),
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                track.bookmarkData = fresh
                try? modelContext.save()
            }
        }

        return url
    }

    // MARK: - Library management

    /// Removes a track from the library without deleting the source file.
    func removeTrack(_ track: Track) throws {
        modelContext.delete(track)
        try modelContext.save()
    }

    /// Refreshes metadata for a single track from its file.
    func refreshMetadata(for track: Track) async throws {
        let url: URL
        do {
            url = try resolveBookmark(for: track)
        } catch {
            throw error
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let meta = try await metadataReader.read(from: url)
        track.title        = meta.title ?? track.title
        track.artist       = meta.artist ?? track.artist
        track.albumArtist  = meta.albumArtist ?? track.albumArtist
        track.album        = meta.album ?? track.album
        track.genre        = meta.genre ?? track.genre
        track.year         = meta.year ?? track.year
        track.trackNumber  = meta.trackNumber ?? track.trackNumber
        track.duration     = meta.duration ?? track.duration
        track.sampleRate   = meta.sampleRate ?? track.sampleRate
        track.bitDepth     = meta.bitDepth ?? track.bitDepth
        track.channelCount = meta.channelCount ?? track.channelCount
        if let art = meta.artworkData { track.artworkData = art }
        try modelContext.save()
    }

    // MARK: - Platform bookmark helpers

    private func bookmarkCreationOptions() -> URL.BookmarkCreationOptions {
        #if os(macOS)
        return [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        #else
        return []
        #endif
    }

    private func bookmarkResolutionOptions() -> URL.BookmarkResolutionOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }
}

// MARK: - Bookmark errors

enum BookmarkError: LocalizedError {
    case missingBookmark(String)
    case staleAndInaccessible(String)

    var errorDescription: String? {
        switch self {
        case .missingBookmark(let path):
            return "No saved access for file at \(path). Re-import the file to restore access."
        case .staleAndInaccessible(let path):
            return "The file at \(path) cannot be found. It may have been moved or deleted."
        }
    }
}
