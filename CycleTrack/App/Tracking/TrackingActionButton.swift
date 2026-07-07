import SwiftUI

struct CycleTrackActionButton: View {
    let action: TrackingAction
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            CycleTrackActionButtonLabel(action: action)
        }
        .buttonStyle(CycleTrackActionButtonStyle())
    }
}

typealias TrackingActionButton = CycleTrackActionButton

private struct CycleTrackActionButtonLabel: View {
    let action: TrackingAction

    var body: some View {
        VStack(spacing: 6) {
            icon
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())

            Text(action.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        if let systemImage = action.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
        } else if let image = action.resourceImage {
            Image(image)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .clipped()
        } else {
            Image(systemName: "questionmark")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
        }
    }
}

private struct CycleTrackActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
