import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Metal
import Foundation

// MARK: - Shared render core

struct RenderCore {
    /// One CIContext shared across the whole app (Metal-backed where available).
    static let shared: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext()
    }()

    /// Creates and configures a CIRAWFilter from a RenderKey.
    static func makeFilter(url: URL, key: RenderKey) -> CIRAWFilter? {
        guard let filter = CIRAWFilter(imageURL: url) else { return nil }

        // For preset WB temperatures, override neutralTemperature.
        // For asShot / auto, leave the filter at its default (camera profile).
        if let k = key.whiteBalance.kelvin {
            filter.neutralTemperature = k
            filter.neutralTint = 0
        }

        filter.exposure = Float(key.exposure)
        return filter
    }

    /// Renders a CIRAWFilter output to a CGImage, scaled down to maxLongEdge.
    static func render(
        filter: CIRAWFilter,
        maxLongEdge: Int,
        colorSpace: CGColorSpace
    ) -> CGImage? {
        guard let outputImage = filter.outputImage else { return nil }

        let extent = outputImage.extent
        let longEdge = max(extent.width, extent.height)
        let scale = longEdge > CGFloat(maxLongEdge) ? CGFloat(maxLongEdge) / longEdge : 1.0

        let image: CIImage
        if scale < 1.0 {
            let scaleFilter = CIFilter.lanczosScaleTransform()
            scaleFilter.inputImage = outputImage
            scaleFilter.scale = Float(scale)
            scaleFilter.aspectRatio = 1.0
            image = scaleFilter.outputImage ?? outputImage
        } else {
            image = outputImage
        }

        return shared.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace)
    }
}

// MARK: - Large preview

@MainActor
class PreviewEngine: ObservableObject {
    @Published var previewImage: CGImage? = nil
    @Published var isRendering: Bool = false

    private var previewTask: Task<Void, Never>?

    func render(file: FileItem, settings: ExportSettings) {
        previewTask?.cancel()
        isRendering = true

        let url = file.url
        let key = settings.renderKey
        let colorSpace = settings.colorProfile.cgColorSpace

        // Task {} inherits @MainActor, so self access is safe.
        // Heavy work is dispatched inside a nested Task.detached.
        previewTask = Task { [weak self] in
            guard let self else { return }

            // Debounce — suspends on main actor, but that's fine for 250ms
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { self.isRendering = false; return }

            // Render on a background thread
            let cgImage = await Task.detached(priority: .userInitiated) {
                guard let filter = RenderCore.makeFilter(url: url, key: key) else { return nil as CGImage? }
                return RenderCore.render(filter: filter, maxLongEdge: 1200, colorSpace: colorSpace)
            }.value

            guard !Task.isCancelled else { self.isRendering = false; return }
            self.previewImage = cgImage
            self.isRendering = false
        }
    }

    func clear() {
        previewTask?.cancel()
        previewImage = nil
        isRendering = false
    }
}

// MARK: - Thumbnail batch renderer

@MainActor
class ThumbnailBatch: ObservableObject {
    private var batchTask: Task<Void, Never>?

    func renderAll(items: [FileItem], settings: ExportSettings) {
        batchTask?.cancel()
        let colorSpace = settings.colorProfile.cgColorSpace
        let key = settings.renderKey

        // Capture items as value-type snapshots to avoid data races
        let urls: [(id: UUID, url: URL)] = items.map { ($0.id, $0.url) }

        batchTask = Task { [weak self] in
            guard self != nil else { return }
            for entry in urls {
                guard !Task.isCancelled else { return }

                // Mark as rendering
                if let item = items.first(where: { $0.id == entry.id }) {
                    item.isThumbnailRendering = true
                }

                // Phase 1: fast embedded JPEG preview (background)
                let quickThumb = await Task.detached(priority: .background) { () -> CGImage? in
                    guard let src = CGImageSourceCreateWithURL(entry.url as CFURL, nil) else { return nil }
                    let opts: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                        kCGImageSourceThumbnailMaxPixelSize: 200
                    ]
                    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
                }.value

                if let img = quickThumb,
                   let item = items.first(where: { $0.id == entry.id }) {
                    item.thumbnailImage = img
                }

                guard !Task.isCancelled else { return }

                // Phase 2: accurate CIRAWFilter render (background)
                let accurateThumb = await Task.detached(priority: .background) { () -> CGImage? in
                    guard let filter = RenderCore.makeFilter(url: entry.url, key: key) else { return nil }
                    return RenderCore.render(filter: filter, maxLongEdge: 200, colorSpace: colorSpace)
                }.value

                if let img = accurateThumb,
                   let item = items.first(where: { $0.id == entry.id }) {
                    item.thumbnailImage = img
                }

                if let item = items.first(where: { $0.id == entry.id }) {
                    item.isThumbnailRendering = false
                }

                await Task.yield()
            }
        }
    }

    func cancel() {
        batchTask?.cancel()
    }
}
