import Foundation

final class DataStore {
    static let shared = DataStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let coastDetection = "coastDetection"
        static let waveConditions = "waveConditions"
        static let preferences = "preferences"
        static let lastUpdateTime = "lastUpdateTime"
    }

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.watchWaves.shared") ?? .standard
    }

    // MARK: - Coast Detection

    var coastDetection: CoastDetectionResult? {
        get { decode(CoastDetectionResult.self, forKey: Keys.coastDetection) }
        set { encode(newValue, forKey: Keys.coastDetection) }
    }

    // MARK: - Wave Conditions

    var waveConditions: [WaveCondition]? {
        get { decode([WaveCondition].self, forKey: Keys.waveConditions) }
        set {
            encode(newValue, forKey: Keys.waveConditions)
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdateTime)
        }
    }

    var lastUpdateTime: Date? {
        let interval = defaults.double(forKey: Keys.lastUpdateTime)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    // MARK: - Preferences

    var preferences: UserPreferences {
        get { decode(UserPreferences.self, forKey: Keys.preferences) ?? .default }
        set { encode(newValue, forKey: Keys.preferences) }
    }

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(try? encoder.encode(value), forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
