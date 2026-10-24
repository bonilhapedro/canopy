import Foundation
import Testing
@testable import CanopyCore

struct WeatherTests {
    @Test func mapsWeatherCodesToSymbols() {
        #expect(WeatherCondition(code: 0, isDay: true).symbol == "sun.max.fill")
        #expect(WeatherCondition(code: 0, isDay: false).symbol == "moon.stars.fill")
        #expect(WeatherCondition(code: 63, isDay: true).description == "Chuva")
        #expect(WeatherCondition(code: 95, isDay: true).symbol == "cloud.bolt.rain.fill")
        #expect(WeatherCondition(code: 1234, isDay: true).symbol == "cloud.fill")
    }

    @Test func parsesOpenMeteo() throws {
        let json = """
        {
          "current": {"time": 1761314400, "temperature_2m": 24.6, "apparent_temperature": 26.1, "weather_code": 2, "is_day": 1},
          "hourly": {
            "time": [1761310800, 1761314400, 1761318000, 1761321600, 1761325200, 1761328800, 1761332400],
            "temperature_2m": [22.0, 24.0, 25.0, 26.0, 25.5, 24.0, 21.0],
            "weather_code": [0, 2, 2, 3, 61, 80, 0],
            "is_day": [1, 1, 1, 1, 1, 0, 0]
          },
          "daily": {"time": [1761271200], "temperature_2m_max": [27.4], "temperature_2m_min": [17.9], "uv_index_max": [8.1]}
        }
        """
        // 14:20, entre a segunda e a terceira hora.
        let now = Date(timeIntervalSince1970: 1_761_315_600)
        let forecast = try WeatherForecast.parse(Data(json.utf8), now: now, hourCount: 4)
        #expect(forecast.temperature == 24.6)
        #expect(forecast.condition.symbol == "cloud.sun.fill")
        #expect(forecast.high == 27.4)
        #expect(forecast.low == 17.9)
        #expect(forecast.uvIndex == 8.1)
        #expect(forecast.hours.count == 4)
        #expect(forecast.hours.first?.temperature == 25.0)
        #expect(forecast.hours.last?.condition.symbol == "cloud.moon.rain.fill")
    }

    @Test func buildsForecastURL() throws {
        let url = try #require(WeatherForecast.url(latitude: -23.55, longitude: -46.63))
        #expect(url.host == "api.open-meteo.com")
        #expect(url.absoluteString.contains("latitude=-23.5500"))
        #expect(url.absoluteString.contains("timeformat=unixtime"))
    }

    @Test func parsesBothIPServices() {
        let numbers = #"{"success": true, "city": "São Paulo", "latitude": -23.55, "longitude": -46.63}"#
        let strings = #"{"city": "Campinas", "latitude": "-22.9", "longitude": "-47.06"}"#
        let failure = #"{"success": false, "message": "limit"}"#
        #expect(ApproximateLocation.parse(Data(numbers.utf8)) == ApproximateLocation(city: "São Paulo", latitude: -23.55, longitude: -46.63))
        #expect(ApproximateLocation.parse(Data(strings.utf8))?.city == "Campinas")
        #expect(ApproximateLocation.parse(Data(strings.utf8))?.latitude == -22.9)
        #expect(ApproximateLocation.parse(Data(failure.utf8)) == nil)
    }
}
