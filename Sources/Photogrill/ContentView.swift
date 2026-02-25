import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var selectedID: UUID? = nil

    let settings = ExportSettings()
    let previewEngine = PreviewEngine()
    let thumbnailBatch = ThumbnailBatch()
    let exportEngine = ExportEngine()

    private var lastRenderKey: RenderKey? = nil

    var selectedItem: FileItem? {
        guard let id = selectedID else { return nil }
        return items.first { $0.id == id }
    }

    func add(urls: [URL]) {
        let existing = Set(items.map { $0.url })
        let fresh = urls.filter { !existing.contains($0) }.map { FileItem(url: $0) }
        guard !fresh.isEmpty else { return }
        items.append(contentsOf: fresh)
        if selectedID == nil { selectedID = fresh.first?.id }
        thumbnailBatch.renderAll(items: fresh, settings: settings)
        refreshPreviewIfNeeded()
    }

    func remove(item: FileItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items.remove(at: idx)
        if selectedID == item.id {
            selectedID = items.isEmpty ? nil : items[min(idx, items.count - 1)].id
        }
        refreshPreviewIfNeeded()
    }

    func select(item: FileItem) {
        selectedID = item.id
        refreshPreviewIfNeeded()
    }

    func settingsDidChange() {
        let key = settings.renderKey
        guard key != lastRenderKey else { return }
        lastRenderKey = key
        thumbnailBatch.renderAll(items: items, settings: settings)
        refreshPreviewIfNeeded()
    }

    private func refreshPreviewIfNeeded() {
        if let item = selectedItem {
            previewEngine.render(file: item, settings: settings)
        } else {
            previewEngine.clear()
        }
    }
}

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        VSplitView {
            HSplitView {
                SettingsPanel(settings: state.settings, exportEngine: state.exportEngine, appState: state)
                    .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

                PreviewPanel(engine: state.previewEngine, selected: state.selectedItem)
                    .frame(minWidth: 400)
            }
            .frame(minHeight: 400)

            ThumbnailStripView(appState: state)
                .frame(minHeight: 130, maxHeight: 160)
        }
        .onChange(of: state.settings.whiteBalance) { _ in state.settingsDidChange() }
        .onChange(of: state.settings.colorProfile) { _ in state.settingsDidChange() }
        .onChange(of: state.settings.exposure)     { _ in state.settingsDidChange() }
    }
}
