import SwiftUI

struct PreviewPanel: View {
    @ObservedObject var engine: PreviewEngine
    let selected: FileItem?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if let item = selected {
                VStack(spacing: 8) {
                    ZStack {
                        if let img = engine.previewImage {
                            Image(decorative: img, scale: 1.0, orientation: .up)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .transition(.opacity.animation(.easeIn(duration: 0.15)))
                        }

                        if engine.isRendering {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    metaRow(for: item)
                        .padding(.bottom, 8)
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Drop RAW files below to get started")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func metaRow(for item: FileItem) -> some View {
        HStack(spacing: 12) {
            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.primary)

            if let size = fileSize(for: item.url) {
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let dims = imageDimensions(for: item.url) {
                Text(dims)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fileSize(for url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func imageDimensions(for url: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return "\(w) × \(h)"
    }
}
