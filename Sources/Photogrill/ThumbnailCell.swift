import SwiftUI

struct ThumbnailCell: View {
    @ObservedObject var item: FileItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail image
            Button(action: onSelect) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))

                    if let img = item.thumbnailImage {
                        Image(decorative: img, scale: 1.0, orientation: .up)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ProgressView()
                            .frame(width: 100, height: 100)
                    }
                }
                .frame(width: 100, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.2), value: isSelected)

            // Status badge (bottom-left)
            statusBadge
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Remove button (top-right, hover-only)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(nsColor: .darkGray))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .frame(width: 100, height: 100)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Circle()
                .fill(.gray.opacity(0.8))
                .frame(width: 8, height: 8)
        case .processing(let p):
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.85))
                    .frame(width: 18, height: 18)
                Text("\(Int(p * 100))")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
        }
    }
}
