import CanopyCore
import SwiftUI

/// Clima agora e nas próximas horas, como o widget do iPhone.
struct WeatherPage: View {
    @Environment(WeatherService.self) private var weather
    @AppStorage(SettingsKey.preciseLocation) private var preciseLocation = false

    var body: some View {
        Group {
            if let forecast = weather.forecast {
                HStack(spacing: 18) {
                    current(forecast)
                        .entrance(0)
                    Spacer(minLength: 0)
                    hourly(forecast)
                        .entrance(1)
                }
            } else if weather.failed {
                VStack(spacing: 10) {
                    Label("Não deu para carregar o clima", systemImage: "cloud.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Button("Tentar de novo", action: weather.refresh)
                        .buttonStyle(CapsuleButtonStyle())
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Olhando o céu…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .frame(maxHeight: .infinity)
        .onAppear { weather.refreshIfNeeded() }
    }

    private func current(_ forecast: WeatherForecast) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: preciseLocation ? "location.fill" : "location")
                    .font(.system(size: 10, weight: .bold))
                Text(weather.city ?? "Sua região")
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))

            HStack(alignment: .center, spacing: 10) {
                Text(WeatherService.degrees(forecast.temperature))
                    .font(.system(size: 52, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Image(systemName: forecast.condition.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 34))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }

            Text(forecast.condition.description)
                .font(.system(size: 13, weight: .semibold))
            Text(details(forecast))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .fixedSize()
    }

    private func details(_ forecast: WeatherForecast) -> String {
        var parts: [String] = []
        if let high = forecast.high, let low = forecast.low {
            parts.append("Máx \(WeatherService.degrees(high))  Mín \(WeatherService.degrees(low))")
        }
        if let uv = forecast.uvIndex {
            parts.append("UV \(Int(uv.rounded()))")
        }
        return parts.joined(separator: " · ")
    }

    private func hourly(_ forecast: WeatherForecast) -> some View {
        HStack(spacing: 14) {
            ForEach(forecast.hours, id: \.date) { hour in
                VStack(spacing: 7) {
                    Text(hour.date, format: .dateTime.hour())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Image(systemName: hour.condition.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 18))
                        .frame(height: 22)
                    Text(WeatherService.degrees(hour.temperature))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                }
                .frame(minWidth: 30)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
