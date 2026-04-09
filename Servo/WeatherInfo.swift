import CoreLocation
import Foundation
import WeatherKit

// MARK: - WeatherSlot

struct WeatherSlot: Codable {
    /// The hour boundary this snapshot applies to.
    let hour: Date
    /// Pre-formatted context string, e.g. "Weather: 72°F, Mostly Cloudy" or
    /// "Weather: 68°F, Partly Cloudy (40% rain)".
    let contextString: String
}

// MARK: - WeatherInfo

enum WeatherInfo {
    /// Fetches the current hour + next 6 hourly slots from WeatherKit.
    /// Call at most once every 6 hours; subsequent context updates come from the cached slots.
    nonisolated static func fetchSlots() async throws -> [WeatherSlot] {
        let location = try await fetchCurrentLocation()
        let forecast: Forecast<HourWeather> = try await WeatherService.shared.weather(
            for: location,
            including: .hourly
        )

        // Truncate to the start of the current hour so we include the current slot.
        let nowComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        let currentHour = Calendar.current.date(from: nowComponents) ?? Date()

        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0

        return forecast
            .filter { $0.date >= currentHour }
            .prefix(7)
            .map { hourWeather in
                let temp = formatter.string(from: hourWeather.temperature)
                let condition = hourWeather.condition.description
                let rain = hourWeather.precipitationChance
                let rainSuffix = rain >= 0.2 ? " (\(Int((rain * 100).rounded()))% rain)" : ""
                return WeatherSlot(
                    hour: hourWeather.date,
                    contextString: "Weather: \(temp), \(condition)\(rainSuffix)"
                )
            }
    }

    @MainActor
    private static func fetchCurrentLocation() async throws -> CLLocation {
        try await OneTimeLocationFetcher.shared.fetch()
    }
}

// MARK: - Location helper

@MainActor
private final class OneTimeLocationFetcher: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = OneTimeLocationFetcher()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetch() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            default:
                cont.resume(throwing: LocationError.denied)
                continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.denied)
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private enum LocationError: Error {
    case denied
}
