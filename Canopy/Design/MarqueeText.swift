import SwiftUI

/// Texto de uma linha que rola devagar quando não cabe, como no Apple Music.
struct MarqueeText: View {
    let text: String
    let font: Font
    var speed: Double = 28
    var pause: Double = 2.2

    @State private var textWidth: CGFloat = 0
    @State private var startedAt = Date.now
    private let gap: CGFloat = 36

    var body: some View {
        // O texto escondido dá a altura de uma linha e ocupa a largura disponível.
        Text(text)
            .font(font)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    let overflows = textWidth > geometry.size.width + 1
                    TimelineView(.animation(minimumInterval: 1 / 60, paused: !overflows)) { context in
                        HStack(spacing: gap) {
                            label
                            if overflows { label }
                        }
                        .offset(x: overflows ? -offset(at: context.date) : 0)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                    .clipped()
                    .mask {
                        if overflows {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.04),
                                    .init(color: .black, location: 0.9),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.black
                        }
                    }
                }
            }
            .onChange(of: text) { startedAt = .now }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
    }

    /// Para no começo, rola até a cópia ocupar o lugar do original e recomeça.
    private func offset(at date: Date) -> CGFloat {
        let distance = Double(textWidth + gap)
        let period = pause + distance / speed
        let elapsed = date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: period)
        return elapsed < pause ? 0 : CGFloat((elapsed - pause) * speed)
    }
}
