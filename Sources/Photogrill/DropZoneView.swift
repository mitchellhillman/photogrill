import SwiftUI
import UniformTypeIdentifiers

private let rawExtensions: Set<String> = [
    "arw", "cr2", "cr3", "nef", "nrw", "dng", "raf",
    "rw2", "orf", "pef", "ptx", "srw", "3fr", "mrw",
    "x3f", "rwl", "erf", "kdc", "dcr", "mef"
]

func loadDroppedURLs(from providers: [NSItemProvider], completion: @escaping ([URL], Int) -> Void) {
    var accepted: [URL] = []
    var rejected = 0
    let group = DispatchGroup()

    for provider in providers {
        group.enter()
        // loadObject(ofClass: NSURL.self) returns the original persistent file URL,
        // unlike loadFileRepresentation which gives a temp copy deleted after the callback.
        provider.loadObject(ofClass: NSURL.self) { item, _ in
            defer { group.leave() }
            guard let url = item as? URL else { rejected += 1; return }
            if rawExtensions.contains(url.pathExtension.lowercased()) {
                accepted.append(url)
            } else {
                rejected += 1
            }
        }
    }

    group.notify(queue: .main) { completion(accepted, rejected) }
}

struct DropZoneView: View {
    let onDrop: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                Text("Drop RAW files here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button("Browse…") {
                    browseForFiles()
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            loadDroppedURLs(from: providers) { urls, _ in
                if !urls.isEmpty { onDrop(urls) }
            }
            return true
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private func browseForFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType.rawImage]
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            onDrop(panel.urls)
        }
    }
}
