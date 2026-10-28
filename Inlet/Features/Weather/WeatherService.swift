import Foundation

/// Current conditions for the city set in Settings, from Open-Meteo (free, no
/// key). Only the city name and its coordinates ever leave the Mac.
@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    struct Conditions: Equatable {
        let temperature: Double
        let code: Int
        let isDay: Bool
        let city: String
        let fetchedAt: Date
    }

    @Published private(set) var conditions: Conditions?
    @Published private(set) var lastError: String?

    private var timer: Timer?
    private var fetchedCity: String?
    private var task: Task<Void, Never>?

    private static let refreshInterval: TimeInterval = 30 * 60

    func start() {
        guard timer == nil else { return }
        refresh(force: true)
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(force: true) }
        }
        timer.tolerance = 120
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-fetches when the city changed or the data is stale.
    func refresh(force: Bool = false) {
        let city = Self.city
        let stale = conditions.map { Date.now.timeIntervalSince($0.fetchedAt) > Self.refreshInterval / 2 } ?? true
        guard force || city != fetchedCity || stale else { return }
        fetchedCity = city
        task?.cancel()
        task = Task { [weak self] in
            do {
                let conditions = try await Self.fetch(city: city)
                guard !Task.isCancelled else { return }
                self?.conditions = conditions
                self?.lastError = nil
            } catch is CancellationError {
            } catch {
                self?.lastError = (error as? WeatherError)?.message ?? String(localized: "Couldn’t load the weather")
            }
        }
    }

    static var city: String {
        let value = UserDefaults.standard.string(forKey: Prefs.weatherCity)?.trimmingCharacters(in: .whitespaces) ?? ""
        return value.isEmpty ? "İstanbul" : value
    }

    static var usesFahrenheit: Bool {
        UserDefaults.standard.string(forKey: Prefs.weatherUnit) == "fahrenheit"
    }

    func formattedTemperature(_ conditions: Conditions) -> String {
        let value = Self.usesFahrenheit ? conditions.temperature * 9 / 5 + 32 : conditions.temperature
        return "\(Int(value.rounded()))°"
    }

    // MARK: - Networking

    private struct WeatherError: Error { let message: String }

    private struct GeocodingResponse: Decodable {
        struct Place: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
        }
        let results: [Place]?
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    private static func fetch(city: String) async throws -> Conditions {
        var geo = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        geo.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1"), .init(name: "language", value: "tr")]
        let (geoData, _) = try await URLSession.shared.data(from: geo.url!)
        guard let place = try JSONDecoder().decode(GeocodingResponse.self, from: geoData).results?.first else {
            throw WeatherError(message: String(localized: "Couldn’t find “\(city)”"))
        }

        var forecast = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        forecast.queryItems = [
            .init(name: "latitude", value: String(place.latitude)),
            .init(name: "longitude", value: String(place.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
        ]
        let (data, _) = try await URLSession.shared.data(from: forecast.url!)
        let current = try JSONDecoder().decode(ForecastResponse.self, from: data).current
        return Conditions(temperature: current.temperature_2m, code: current.weather_code,
                          isDay: current.is_day == 1, city: place.name, fetchedAt: .now)
    }

    /// WMO weather code → SF Symbol.
    static func symbol(for conditions: Conditions) -> String {
        switch conditions.code {
        case 0: conditions.isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: conditions.isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}
