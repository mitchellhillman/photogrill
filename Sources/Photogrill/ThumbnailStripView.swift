import SwiftUI
import UniformTypeIdentifiers

struct ThumbnailStripView: View {
    @ObservedObject var appState: AppState
    @State private var isTargeted = false
    @State private var dropErrorVisible = false

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            if appState.items.isEmpty {
                DropZoneView { urls in appState.add(urls: urls) }
                    .padding(12)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(spacing: 8) {
                        ForEach(appState.items) { item in
                            ThumbnailCell(
                                item: item,
                                isSelected: appState.selectedID == item.id,
                                onSelect: { appState.select(item: item) },
                                onRemove: { appState.remove(item: item) }
                            )
                        }

                        // Add more button
                        addButton
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }

            if dropErrorVisible {
                Text("Unsupported file type — drop RAW files only")
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 8)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private var addButton: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [UTType.rawImage]
            panel.prompt = "Add"
            if panel.runModal() == .OK {
                appState.add(urls: panel.urls)
            }
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                )
        }
        .buttonStyle(.plain)
    }

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        loadDroppedURLs(from: providers) { urls, rejected in
            if !urls.isEmpty { appState.add(urls: urls) }
            if rejected > 0 { showDropError() }
        }
        return true
    }

    private func showDropError() {
        withAnimation { dropErrorVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { dropErrorVisible = false }
        }
    }
}
