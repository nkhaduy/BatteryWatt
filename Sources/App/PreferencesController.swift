import Foundation
import BatteryWattCore

extension Notification.Name {
    static let batteryWattPreferencesDidChange = Notification.Name("BatteryWattPreferencesDidChange")
}

final class PreferencesController {
    private(set) var values: BatteryWattPreferences

    init(store: UserDefaults = .standard) {
        values = BatteryWattPreferences(store: store)
    }

    func update(_ change: (inout BatteryWattPreferences) -> Void) {
        var updated = values
        change(&updated)
        updated.save()
        values = updated
        NotificationCenter.default.post(name: .batteryWattPreferencesDidChange, object: self)
    }
}
