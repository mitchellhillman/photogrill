import CoreGraphics
import Foundation

enum FileStatus {
    case pending
    case processing(Double)  // progress 0–1
    case done
    case failed(String)
}

@MainActor
class FileItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL

    @Published var status: FileStatus = .pending
    @Published var thumbnailImage: CGImage? = nil
    @Published var isThumbnailRendering: Bool = false

    var displayName: String { url.lastPathComponent }

    init(url: URL) {
        self.url = url
    }
}
