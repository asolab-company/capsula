import Combine
import CoreLocation
import Foundation
import WeatherKit

struct LocalWeatherSnapshot: Equatable {
    var temperatureText: String
    var iconName: String

    static let placeholder = LocalWeatherSnapshot(
        temperatureText: "--°C",
        iconName: AssetName.weatherSun
    )
}

@MainActor
final class WeatherKitManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var snapshot = LocalWeatherSnapshot.placeholder

    private let locationManager = CLLocationManager()
    private var isLoadingWeather = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            snapshot = .placeholder
        @unknown default:
            snapshot = .placeholder
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isLoadingWeather else { return }
        Task {
            await fetchWeather(for: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        snapshot = .placeholder
        isLoadingWeather = false
    }

    private func fetchWeather(for location: CLLocation) async {
        isLoadingWeather = true
        defer { isLoadingWeather = false }

        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let celsius = current.temperature.converted(to: .celsius).value
            let roundedTemperature = Int(celsius.rounded())
            snapshot = LocalWeatherSnapshot(
                temperatureText: "\(roundedTemperature >= 0 ? "+" : "")\(roundedTemperature)°C",
                iconName: Self.iconName(for: String(describing: current.condition))
            )
        } catch {
            snapshot = .placeholder
        }
    }

    private static func iconName(for condition: String) -> String {
        let value = condition.lowercased()

        if value.contains("thunder") || value.contains("storm") {
            return AssetName.weatherThunderstorm
        }
        if value.contains("hail") {
            return AssetName.weatherHail
        }
        if value.contains("snow") || value.contains("blizzard") || value.contains("flurr") {
            return AssetName.weatherSnow
        }
        if value.contains("sleet") || value.contains("freezing") || value.contains("wintry") {
            return AssetName.weatherSnow
        }
        if value.contains("heavy") && value.contains("rain") {
            return AssetName.weatherHeavyRain
        }
        if value.contains("rain") || value.contains("drizzle") || value.contains("shower") {
            return AssetName.weatherRain
        }
        if value.contains("wind") || value.contains("breez") {
            return AssetName.weatherHeavyWind
        }
        if value.contains("cloud") {
            return value.contains("partial") || value.contains("partly")
                ? AssetName.weatherPartlyCloudy
                : AssetName.weatherCloud
        }
        if value.contains("fog") || value.contains("haze") {
            return AssetName.weatherCloud
        }
        return AssetName.weatherSun
    }
}
