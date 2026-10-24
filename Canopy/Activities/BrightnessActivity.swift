import CanopyCore
import SwiftUI

/// Indicador de brilho que aparece por um instante quando o brilho da tela muda.
@MainActor
final class BrightnessActivity: IslandActivity {
    static let activityID = "brightness"

    let id = BrightnessActivity.activityID
    let priority = ActivityPriority.alert
    private let brightness: BrightnessController

    init(brightness: BrightnessController) {
        self.brightness = brightness
    }

    /// Um branco quente, como a luz da tela.
    static let tint = Color(red: 1, green: 0.93, blue: 0.72)

    var accent: Color? { Self.tint }
    let tabSymbol = "sun.max.fill"

    var compactLeading: AnyView { AnyView(SunIcon(brightness: brightness).font(.system(size: 13, weight: .semibold))) }
    var compactTrailing: AnyView { AnyView(BrightnessLevel(brightness: brightness) { LevelSegments(level: $0, tint: Self.tint) }) }
    var minimal: AnyView { AnyView(SunIcon(brightness: brightness)) }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 14) {
                SunIcon(brightness: brightness)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 34)
                BrightnessLevel(brightness: brightness) { level in
                    LevelBar(level: level, tint: Self.tint)
                    LevelPercent(text: "\(Int((level * 100).rounded()))")
                }
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        )
    }
}

/// Um sol que gira e cresce um pouco conforme o brilho sobe, e brilha de verdade no máximo.
private struct SunIcon: View {
    let brightness: BrightnessController

    var body: some View {
        let level = Double(brightness.brightness)
        Image(systemName: level < 0.5 ? "sun.min.fill" : "sun.max.fill")
            .foregroundStyle(BrightnessActivity.tint)
            .contentTransition(.symbolEffect(.replace))
            .rotationEffect(.degrees(level * 90))
            .scaleEffect(0.85 + 0.2 * level)
            .shadow(color: BrightnessActivity.tint.opacity(level * 0.8), radius: 2 + 6 * level)
            .animation(.snappy(duration: 0.2), value: level)
    }
}

/// Lê o brilho dentro do próprio body, para só este pedaço redesenhar quando ele muda.
private struct BrightnessLevel<Content: View>: View {
    let brightness: BrightnessController
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        content(Double(brightness.brightness))
    }
}
