import SwiftUI

/// Bateria desenhada à mão, com o nível preenchido e um raio quando está carregando.
struct BatteryGlyph: View {
    let percent: Int
    let isCharging: Bool
    let tint: Color
    var width: CGFloat = 26

    var body: some View {
        let height = width * 0.48
        let level = CGFloat(min(max(percent, 0), 100)) / 100
        HStack(spacing: width * 0.04) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.3, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: max(1, width * 0.045))
                RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                    .fill(tint)
                    .frame(width: max(2, (width - 4) * level), height: height - 4)
                    .padding(.leading, 2)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: width, height: height)
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: max(1.5, width * 0.07), height: height * 0.4)
        }
        .animation(.smooth(duration: 0.4), value: percent)
    }
}

/// Anel de carga usado na ilha aberta sem atividade.
struct BatteryRing: View {
    let percent: Int
    let isCharging: Bool

    private var tint: Color {
        if isCharging { return .green }
        return percent <= 20 ? .red : .white
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: 6)
            VStack(spacing: 0) {
                Image(systemName: isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text("\(percent)%")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .frame(width: 66, height: 66)
    }
}
