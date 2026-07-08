import SwiftUI

struct WatcherSectionView: View {
    let watchers: [Watcher]
    let onRemoveWatcher: (Watcher) -> Void

    private let watcherRowHeight: CGFloat = 38
    private let maxVisibleWatcherRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Watchers", systemImage: "person.and.person")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(activeWatcherCount) active")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if watchers.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No watchers yet")
                            .font(.subheadline.weight(.semibold))

                        Text("Share your live link to invite people.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 8) {
                        ForEach(watchers) { watcher in
                            SwipeToRemoveWatcherRow(watcher: watcher) {
                                onRemoveWatcher(watcher)
                            }
                                .frame(height: watcherRowHeight)
                        }
                    }
                    .padding(.trailing, watchers.count > maxVisibleWatcherRows ? 12 : 0)
                }
                .scrollIndicators(watchers.count > maxVisibleWatcherRows ? .visible : .hidden)
                .frame(height: watcherListHeight)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var watcherListHeight: CGFloat {
        let visibleRows = min(watchers.count, maxVisibleWatcherRows)
        let rowSpacing = max(0, visibleRows - 1) * 8

        return CGFloat(visibleRows) * watcherRowHeight + CGFloat(rowSpacing)
    }

    private var activeWatcherCount: Int {
        watchers.filter(\.isActive).count
    }

}

private struct SwipeToRemoveWatcherRow: View {
    let watcher: Watcher
    let onRemove: () -> Void

    @State private var offset: CGFloat = 0

    private let removeWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    onRemove()
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: removeWidth, height: 38)
                    .background(.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            watcherRow
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            offset = max(-removeWidth, min(0, value.translation.width))
                        }
                        .onEnded { value in
                            let shouldReveal = value.translation.width < -34 || value.predictedEndTranslation.width < -70

                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                offset = shouldReveal ? -removeWidth : 0
                            }
                        }
                )
        }
        .clipped()
    }

    private var watcherRow: some View {
        HStack(spacing: 10) {
            Group {
                if let image = watcher.image {
                        Image(image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 30, height: 30)
            .background(.thinMaterial, in: Circle())
            .clipShape(Circle())

            Text(watcher.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(watcher.isActive ? .green : .secondary.opacity(0.35))
                .frame(width: 8, height: 8)
        }
    }
}

#Preview {
    WatcherSectionView(watchers: [], onRemoveWatcher: { _ in })
}
