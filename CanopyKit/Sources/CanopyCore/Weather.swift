import Foundation

/// Condição do tempo a partir do código WMO que o Open-Meteo devolve.
public struct WeatherCondition: Sendable, Equatable {
    public var symbol: String
    public var description: String

    public init(code: Int, isDay: Bool) {
        switch code {
        case 0:
            self.init(symbol: isDay ? "sun.max.fill" : "moon.stars.fill", description: "Céu limpo")
        case 1:
            self.init(symbol: isDay ? "sun.max.fill" : "moon.fill", description: "Poucas nuvens")
        case 2:
            self.init(symbol: isDay ? "cloud.sun.fill" : "cloud.moon.fill", description: "Parcialmente nublado")
        case 3:
            self.init(symbol: "cloud.fill", description: "Nublado")
        case 45, 48:
            self.init(symbol: "cloud.fog.fill", description: "Neblina")
        case 51, 53, 55:
            self.init(symbol: "cloud.drizzle.fill", description: "Garoa")
        case 56, 57, 66, 67:
            self.init(symbol: "cloud.sleet.fill", description: "Chuva congelada")
        case 61, 63:
            self.init(symbol: "cloud.rain.fill", description: "Chuva")
        case 65:
            self.init(symbol: "cloud.heavyrain.fill", description: "Chuva forte")
        case 71, 73, 75, 77, 85, 86:
            self.init(symbol: "cloud.snow.fill", description: "Neve")
        case 80, 81, 82:
            self.init(symbol: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill", description: "Pancadas de chuva")
        case 95, 96, 99:
            self.init(symbol: "cloud.bolt.rain.fill", description: "Trovoadas")
        default:
            self.init(symbol: "cloud.fill", description: "Tempo instável")
        }
    }

    public init(symbol: String, description: String) {
        self.symbol = symbol
        self.description = description
    }
}

public struct WeatherForecast: Sendable, Equatable {
    public struct Hour: Sendable, Equatable {
        public var date: Date
        public var temperature: Double
        public var condition: WeatherCondition
    }

    public var temperature: Double
    public var apparentTemperature: Double?
    public var condition: WeatherCondition
    public var high: Double?
    public var low: Double?
    public var uvIndex: Double?
    /// As próximas horas cheias, depois da hora atual.
    public var hours: [Hour]
    public var fetchedAt: Date

    /// Endereço da previsão no Open-Meteo, que é gratuito e não pede chave.
    public static func url(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ]
        return components?.url
    }

    /// Lê a resposta do Open-Meteo pedida com `url(latitude:longitude:)`.
    public static func parse(_ data: Data, now: Date, hourCount: Int = 5) throws -> WeatherForecast {
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let current = response.current
        let currentIsDay = current.is_day.map { $0 != 0 } ?? true

        var hours: [Hour] = []
        if let hourly = response.hourly {
            let startOfHour = now.timeIntervalSince1970 - now.timeIntervalSince1970.truncatingRemainder(dividingBy: 3600)
            for (index, time) in hourly.time.enumerated() where Double(time) > startOfHour {
                guard index < hourly.temperature_2m.count, index < hourly.weather_code.count else { break }
                let isDay = hourly.is_day.flatMap { index < $0.count ? $0[index] != 0 : nil } ?? true
                hours.append(Hour(
                    date: Date(timeIntervalSince1970: Double(time)),
                    temperature: hourly.temperature_2m[index],
                    condition: WeatherCondition(code: hourly.weather_code[index], isDay: isDay)
                ))
                if hours.count == hourCount { break }
            }
        }

        return WeatherForecast(
            temperature: current.temperature_2m,
            apparentTemperature: current.apparent_temperature,
            condition: WeatherCondition(code: current.weather_code, isDay: currentIsDay),
            high: response.daily?.temperature_2m_max.first,
            low: response.daily?.temperature_2m_min.first,
            uvIndex: response.daily?.uv_index_max?.first,
            hours: hours,
            fetchedAt: now
        )
    }
}

// Os nomes seguem o JSON do Open-Meteo.
private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        var temperature_2m: Double
        var apparent_temperature: Double?
        var weather_code: Int
        var is_day: Int?
    }

    struct Hourly: Decodable {
        var time: [Int]
        var temperature_2m: [Double]
        var weather_code: [Int]
        var is_day: [Int]?
    }

    struct Daily: Decodable {
        var temperature_2m_max: [Double]
        var temperature_2m_min: [Double]
        var uv_index_max: [Double]?
    }

    var current: Current
    var hourly: Hourly?
    var daily: Daily?
}

/// Localização aproximada pelo IP, usada quando a localização precisa está desligada.
public struct ApproximateLocation: Sendable, Equatable {
    public var city: String?
    public var latitude: Double
    public var longitude: Double

    public init(city: String?, latitude: Double, longitude: Double) {
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Serviços gratuitos, sem chave, tentados em ordem.
    public static let serviceURLs = [
        URL(string: "https://ipwho.is/")!,
        URL(string: "https://get.geojs.io/v1/ip/geo.json")!,
    ]

    /// Entende as respostas dos dois serviços: um manda números, o outro manda texto.
    public static func parse(_ data: Data) -> ApproximateLocation? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let success = object["success"] as? Bool, !success { return nil }
        guard let latitude = number(object["latitude"]), let longitude = number(object["longitude"]) else { return nil }
        let city = (object["city"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return ApproximateLocation(city: city, latitude: latitude, longitude: longitude)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}
