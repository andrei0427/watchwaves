import Foundation
import WatchKit
import WidgetKit

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()

    private let apiClient = MarineAPIClient()
    private let store = DataStore.shared
    private let refreshInterval: TimeInterval = 30 * 60 // 30 minutes

    func scheduleNextRefresh() {
        let preferredDate = Date(timeIntervalSinceNow: refreshInterval)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error {
                print("Failed to schedule background refresh: \(error)")
            }
        }
    }

    func handleBackgroundRefresh() async {
        // Use cached ocean coordinate — don't re-probe coast in background
        guard let coast = store.coastDetection,
              let selectedCoast = effectiveCoast(from: coast) else {
            scheduleNextRefresh()
            return
        }

        do {
            let userCoordinate = coast.probeOrigin
            let conditions = try await apiClient.fetchMarineData(at: selectedCoast.oceanCoordinate, windAt: userCoordinate)
            store.waveConditions = conditions
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Background refresh failed: \(error)")
        }

        scheduleNextRefresh()
    }

    private func effectiveCoast(from detection: CoastDetectionResult) -> CoastProbeResult? {
        let prefs = store.preferences
        if let manual = prefs.manualCoastDirection {
            return detection.detectedCoasts.first(where: { $0.direction == manual })
        }
        return detection.nearestCoast
    }
}
