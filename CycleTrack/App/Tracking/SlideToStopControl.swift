import SwiftUI

struct SlideToStopControl: View {
    @State private var stopSliderOffset: CGFloat

    let onStop: () -> Void

    init(stopSliderOffset: CGFloat = 0, onStop: @escaping () -> Void) {
        self.stopSliderOffset = stopSliderOffset
        self.onStop = onStop
    }

    var body: some View {
        GeometryReader { proxy in
            let knobSize: CGFloat = 44
            let maxOffset = max(0, proxy.size.width - knobSize - 8)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.red.opacity(0.12))

                Text("Slide to stop sharing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(.red.opacity(0.85))
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        Image(systemName: "stop.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: stopSliderOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                stopSliderOffset = min(max(0, value.translation.width), maxOffset)
                            }
                            .onEnded { _ in
                                if stopSliderOffset > maxOffset * 0.80 {
                                    onStop()
                                }

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    stopSliderOffset = 0
                                }
                            }
                    )
            }
        }
        .frame(height: 52)
    }
}

#Preview {
    SlideToStopControl(stopSliderOffset: 0, onStop:  {})
}
