import CanopyCore
import CoreLocation
import Foundation
import Observation

/// Busca o clima no Open-Meteo. A localização vem do IP, ou do GPS do Mac com a
/// localização precisa ligada nos Ajustes.
@MainActor
@Observable
final class WeatherService {
    private(set) var forecast: WeatherForecast?
    private(set) var city: String?
    private(set) var isLoading = false
    private(set) var failed = false

    @ObservationIgnored private let locator = PreciseLocator()
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    /// Depois disso a previsão é buscada de novo.
    static let maxAge: TimeInterval = 30 * 60

    init() {
        locator.onLocate = { [weak self] latitude, longitude, city in
            self?.city = city ?? self?.city
            self?.fetchForecast(latitude: latitude, longitude: longitude)
        }
        locator.onFail = { [weak self] in
            // Sem GPS, o IP ainda dá uma ideia de onde o Mac está.
            self?.fetchApproximate()
        }
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshIfNeeded()
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }
    }

    func refreshIfNeeded() {
        guard Preferences.weatherEnabled else { return }
        if let forecast, Date.now.timeIntervalSince(forecast.fetchedAt) < Self.maxAge { return }
        refresh()
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        failed = false
        if Preferences.preciseLocation {
            locator.locate()
        } else {
            fetchApproximate()
        }
    }

    private func fetchApproximate() {
        Task {
            for url in ApproximateLocation.serviceURLs {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let location = ApproximateLocation.parse(data)
                else { continue }
                city = location.city
                fetchForecast(latitude: location.latitude, longitude: location.longitude)
                return
            }
            fail()
        }
    }

    private func fetchForecast(latitude: Double, longitude: Double) {
        guard let url = WeatherForecast.url(latitude: latitude, longitude: longitude) else {
            fail()
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let forecast = try? WeatherForecast.parse(data, now: .now)
            else {
                fail()
                return
            }
            self.forecast = forecast
            isLoading = false
            failed = false
        }
    }

    private func fail() {
        isLoading = false
        failed = forecast == nil
    }

    /// Temperatura em graus, em Celsius ou Fahrenheit conforme os Ajustes.
    static func degrees(_ celsius: Double) -> String {
        let value = Preferences.fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}

/// Pede uma única localização ao CoreLocation e o nome da cidade.
@MainActor
private final class PreciseLocator: NSObject, CLLocationManagerDelegate {
    var onLocate: ((Double, Double, String?) -> Void)?
    var onFail: (() -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var isWaiting = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locate() {
        isWaiting = true
        switch manager.authorizationStatus {
        case .notDetermined:
            // A resposta chega em locationManagerDidChangeAuthorization.
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finishWithFailure()
        default:
            manager.requestLocation()
        }
    }

    private func authorizationChanged(allowed: Bool, decided: Bool) {
        guard isWaiting, decided else { return }
        if allowed {
            manager.requestLocation()
        } else {
            finishWithFailure()
        }
    }

    private func located(latitude: Double, longitude: Double) {
        guard isWaiting else { return }
        isWaiting = false
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) { placemarks, _ in
            let city = placemarks?.first?.locality
            Task { @MainActor in self.onLocate?(latitude, longitude, city) }
        }
    }

    private func finishWithFailure() {
        guard isWaiting else { return }
        isWaiting = false
        onFail?()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        MainActor.assumeIsolated { self.located(latitude: latitude, longitude: longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated { self.finishWithFailure() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let allowed = status != .denied && status != .restricted && status != .notDetermined
        let decided = status != .notDetermined
        MainActor.assumeIsolated { self.authorizationChanged(allowed: allowed, decided: decided) }
    }
}
