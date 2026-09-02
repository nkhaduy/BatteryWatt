import Testing
import Foundation
@testable import BatteryWattCore

struct BatteryPreferencesTests {
    @Test func defaultsPreserveTheOriginalChargingOnlyExperience() {
        let preferences = BatteryWattPreferences.defaults

        #expect(preferences.menuBarVisibility == .chargingOnly)
        #expect(preferences.refreshInterval == .oneSecond)
        #expect(preferences.directionStyle == .boltOnly)
        #expect(preferences.iconStyle == .bolt)
        #expect(preferences.decimalPlaces == 1)
        #expect(preferences.showSpaceBeforeUnit)
        #expect(preferences.hideWhenFull)
        #expect(abs(preferences.hideBelowWatts - 0.5) < 0.001)
        #expect(!preferences.recordHistory)
    }

    @Test func refreshIntervalLabelsUseTheirActualValue() {
        #expect(RefreshInterval.oneSecond.displayName == "1 second")
        #expect(RefreshInterval.tenSeconds.displayName == "10 seconds")
    }

    @Test func preferencesRoundTripThroughUserDefaults() {
        let defaults = UserDefaults(suiteName: "BatteryWattCoreTests")!
        defaults.removePersistentDomain(forName: "BatteryWattCoreTests")
        var preferences = BatteryWattPreferences(store: defaults)
        preferences.menuBarVisibility = .always
        preferences.refreshInterval = .fiveSeconds
        preferences.decimalPlaces = 2
        preferences.recordHistory = true
        preferences.save()

        let restored = BatteryWattPreferences(store: defaults)
        #expect(restored.menuBarVisibility == .always)
        #expect(restored.refreshInterval == .fiveSeconds)
        #expect(restored.decimalPlaces == 2)
        #expect(restored.recordHistory)
    }
}
