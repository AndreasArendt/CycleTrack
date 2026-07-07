import SwiftUI

struct WatcherSectionView: View {
    let watchers: [Watcher]

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
                            watcherRow(watcher)
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

    private func watcherRow(_ watcher: Watcher) -> some View {
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
