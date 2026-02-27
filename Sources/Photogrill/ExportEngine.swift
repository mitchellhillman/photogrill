import CoreImage
import ImageIO
import Metal
import UniformTypeIdentifiers
import Foundation

@MainActor
class ExportEngine: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var completedCount: Int = 0

    private var exportTask: Task<Void, Never>?

    func exportAll(items: [FileItem], settings: ExportSettings) {
        guard !isExporting else { return }
        isExporting = true
        completedCount = 0

        let colorSpace = settings.colorProfile.cgColorSpace
        let quality = settings.quality
        let maxDim = settings.maxDimensionEnabled ? settings.maxDimension : Int.max
        let outputFolder = settings.outputFolder
        let renderKey = settings.renderKey

        // Capture item data on the main actor before launching the task
        let work: [(item: FileItem, url: URL, destURL: URL)] = items.map { item in
            (item, item.url, Self.outputURL(for: item.url, folder: outputFolder))
        }

        // Task {} inherits @MainActor: all FileItem and self mutations are safe.
        // Per-file CPU rendering is dispatched to background via Task.detached.
        exportTask = Task { [weak self] in
            guard let self else { return }

            for entry in work {
                guard !Task.isCancelled else { break }

                entry.item.status = .processing(0)

                // Render in background, await result back on main actor
                let renderResult = await Task.detached(priority: .userInitiated) { () -> (CGImage?, [CFString: Any]?, Date?, String?) in
                    // Read source metadata
                    var sourceMetadata: [CFString: Any]? = nil
                    if let src = CGImageSourceCreateWithURL(entry.url as CFURL, nil) {
                        sourceMetadata = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
                    }

                    // Preserve file creation date
                    let creationDate = (try? FileManager.default.attributesOfItem(atPath: entry.url.path))?[.creationDate] as? Date

                    guard let filter = RenderCore.makeFilter(url: entry.url, key: renderKey) else {
                        return (nil, nil, nil, "Could not open RAW file")
                    }
                    guard let img = RenderCore.render(filter: filter, maxLongEdge: maxDim, colorSpace: colorSpace) else {
                        return (nil, nil, nil, "Render failed")
                    }
                    return (img, sourceMetadata, creationDate, nil)
                }.value

                let (cgImage, sourceMetadata, creationDate, renderError) = renderResult

                if let msg = renderError {
                    entry.item.status = .failed(msg)
                    continue
                }
                guard let cgImage else { continue }

                entry.item.status = .processing(0.8)

                guard let dest = CGImageDestinationCreateWithURL(
                    entry.destURL as CFURL,
                    UTType.jpeg.identifier as CFString,
                    1, nil
                ) else {
                    entry.item.status = .failed("Could not create output file")
                    continue
                }

                // Build properties: copy metadata from source, then add JPEG quality
                var props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
                if let meta = sourceMetadata {
                    for key in [kCGImagePropertyExifDictionary,
                                kCGImagePropertyExifAuxDictionary,
                                kCGImagePropertyGPSDictionary,
                                kCGImagePropertyIPTCDictionary,
                                kCGImagePropertyTIFFDictionary] as [CFString] {
                        if let val = meta[key] { props[key] = val }
                    }
                }

                CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)

                if CGImageDestinationFinalize(dest) {
                    // Restore original file creation date
                    if let date = creationDate {
                        try? FileManager.default.setAttributes(
                            [.creationDate: date, .modificationDate: date],
                            ofItemAtPath: entry.destURL.path
                        )
                    }
                    entry.item.status = .done
                    self.completedCount += 1
                } else {
                    entry.item.status = .failed("Write failed")
                }
            }

            self.isExporting = false
        }
    }

    func cancel() {
        exportTask?.cancel()
        isExporting = false
    }

    nonisolated private static func outputURL(for source: URL, folder: URL?) -> URL {
        (folder ?? source.deletingLastPathComponent())
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("jpg")
    }
}
