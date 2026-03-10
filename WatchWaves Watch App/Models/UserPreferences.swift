import Foundation

struct UserPreferences: Codable {
    var useMetricUnits: Bool = true
    var manualCoastDirection: CompassDirection? = nil
    var isAutoDetect: Bool { manualCoastDirection == nil }

    static let `default` = UserPreferences()
}
