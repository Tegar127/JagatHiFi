// ArtworkView.swift — Artwork display component with placeholder state (R-27: empty state).

import SwiftUI

/// Displays album artwork from raw data or a fallback placeholder.
/// The placeholder uses text and a music-note symbol — no generic AI illustration (R-22).
struct ArtworkView: View {
    let data: Data?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = Radius.md

    var body: some View {
        Group {
            if let data, let image = platformImage(from: data) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color("SurfaceOverlay")
            Image(systemName: "music.note")
                .font(.system(size: size * 0.35, weight: .light))
                .foregroundStyle(Color("TextTertiary"))
        }
    }

#if os(macOS)
    private func platformImage(from data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
    }
#else
    private func platformImage(from data: Data) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
#endif
}

#Preview {
    HStack(spacing: Spacing.md) {
        ArtworkView(data: nil, size: 56)
        ArtworkView(data: nil, size: 120, cornerRadius: Radius.lg)
    }
    .padding()
    .background(Color("SurfaceBase"))
}
