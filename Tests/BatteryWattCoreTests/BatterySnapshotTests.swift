#if canImport(XCTest)
import XCTest
import Foundation
@testable import BatteryWattCore

final class BatterySnapshotTests: XCTestCase {
    func testPowerUsesMillivoltsAndMilliamps() {
        let snapshot = BatterySnapshot(
            batteryPercentage: 74,
            instantAmperageMilliamps: -4775,
            voltageMillivolts: 11754,
            externalConnected: false,
            isCharging: false,
            fullyCharged: false,
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.powerWatts ?? 0, 56.12535, accuracy: 0.00001)
        XCTAssertEqual(snapshot.state, .discharging)
    }

    func testChargingOnlyVisibilityRequiresExternalPowerAndCharging() {
        let charging = makeSnapshot(externalConnected: true, isCharging: true)
        let connectedButNotCharging = makeSnapshot(externalConnected: true, isCharging: false)
        let unplugged = makeSnapshot(externalConnected: false, isCharging: false)

        XCTAssertTrue(charging.isVisible(using: .defaults))
        XCTAssertFalse(connectedButNotCharging.isVisible(using: .defaults))
        XCTAssertFalse(unplugged.isVisible(using: .defaults))
    }

    func testVisibilityModesSupportDischargingAndAdapterStates() {
        let discharging = makeSnapshot(externalConnected: false, isCharging: false)
        let connected = makeSnapshot(externalConnected: true, isCharging: false)
        let always = BatteryWattPreferences.defaults.with(menuBarVisibility: .always)
        let onBattery = BatteryWattPreferences.defaults.with(menuBarVisibility: .onBatteryOnly)
        let adapter = BatteryWattPreferences.defaults.with(menuBarVisibility: .adapterConnected)

        XCTAssertTrue(discharging.isVisible(using: always))
        XCTAssertTrue(discharging.isVisible(using: onBattery))
        XCTAssertTrue(connected.isVisible(using: adapter))
        XCTAssertFalse(connected.isVisible(using: always))
    }

    func testUnavailableSnapshotDoesNotCrashOrBecomeVisible() {
        XCTAssertNil(BatterySnapshot.unavailable.powerWatts)
        XCTAssertFalse(BatterySnapshot.unavailable.isVisible(using: .defaults))
        XCTAssertEqual(BatterySnapshot.unavailable.state, .unknown)
    }

    func testDisplayFormattingUsesRequestedDecimalPlaces() {
        XCTAssertEqual(PowerFormatter.powerText(4.18, preferences: .defaults), "4.2 W")
        XCTAssertEqual(PowerFormatter.powerText(19.84, preferences: .defaults), "19.8 W")
        XCTAssertEqual(PowerFormatter.powerText(56.13, preferences: .defaults), "56.1 W")
    }

    func testDirectionAndSpacingFormattingStayExplicit() {
        let direction = BatteryWattPreferences.defaults.with(
            directionStyle: .direction,
            iconStyle: .direction,
            showSpaceBeforeUnit: false
        )
        let signed = BatteryWattPreferences.defaults.with(
            directionStyle: .signed,
            showSpaceBeforeUnit: true
        )

        XCTAssertEqual(PowerFormatter.powerText(7.2, direction: .discharging, preferences: direction), "↓ 7.2W")
        XCTAssertEqual(PowerFormatter.powerText(7.2, direction: .discharging, preferences: signed), "-7.2 W")

        let adapterConnected = BatteryWattPreferences.defaults.with(directionStyle: .signed)
        XCTAssertEqual(PowerFormatter.powerText(7.2, direction: .unknown, preferences: adapterConnected), "7.2 W")
    }

    private func makeSnapshot(externalConnected: Bool, isCharging: Bool) -> BatterySnapshot {
        BatterySnapshot(
            batteryPercentage: 74,
            instantAmperageMilliamps: isCharging ? 4775 : -650,
            voltageMillivolts: 11754,
            externalConnected: externalConnected,
            isCharging: isCharging,
            fullyCharged: false,
            timestamp: Date(timeIntervalSince1970: 100)
        )
    }
}
#else
import Testing
import Foundation
@testable import BatteryWattCore

struct BatterySnapshotTests {
    @Test func powerUsesMillivoltsAndMilliamps() {
        let snapshot = BatterySnapshot(
            batteryPercentage: 74,
            instantAmperageMilliamps: -4775,
            voltageMillivolts: 11754,
            externalConnected: false,
            isCharging: false,
            fullyCharged: false,
            timestamp: Date(timeIntervalSince1970: 100)
        )

        #expect(abs((snapshot.powerWatts ?? 0) - 56.12535) < 0.00001)
        #expect(snapshot.state == .discharging)
    }

    @Test func chargingOnlyVisibilityRequiresExternalPowerAndCharging() {
        let charging = makeSnapshot(externalConnected: true, isCharging: true)
        let connectedButNotCharging = makeSnapshot(externalConnected: true, isCharging: false)
        let unplugged = makeSnapshot(externalConnected: false, isCharging: false)

        #expect(charging.isVisible(using: .defaults))
        #expect(!connectedButNotCharging.isVisible(using: .defaults))
        #expect(!unplugged.isVisible(using: .defaults))
    }

    @Test func visibilityModesSupportDischargingAndAdapterStates() {
        let discharging = makeSnapshot(externalConnected: false, isCharging: false)
        let connected = makeSnapshot(externalConnected: true, isCharging: false)
        let always = BatteryWattPreferences.defaults.with(menuBarVisibility: .always)
        let onBattery = BatteryWattPreferences.defaults.with(menuBarVisibility: .onBatteryOnly)
        let adapter = BatteryWattPreferences.defaults.with(menuBarVisibility: .adapterConnected)

        #expect(discharging.isVisible(using: always))
        #expect(discharging.isVisible(using: onBattery))
        #expect(connected.isVisible(using: adapter))
        #expect(!connected.isVisible(using: always))
    }

    @Test func unavailableSnapshotDoesNotCrashOrBecomeVisible() {
        #expect(BatterySnapshot.unavailable.powerWatts == nil)
        #expect(!BatterySnapshot.unavailable.isVisible(using: .defaults))
        #expect(BatterySnapshot.unavailable.state == .unknown)
    }

    @Test func displayFormattingUsesRequestedDecimalPlaces() {
        #expect(PowerFormatter.powerText(4.18, preferences: .defaults) == "4.2 W")
        #expect(PowerFormatter.powerText(19.84, preferences: .defaults) == "19.8 W")
        #expect(PowerFormatter.powerText(56.13, preferences: .defaults) == "56.1 W")
    }

    @Test func directionAndSpacingFormattingStayExplicit() {
        let direction = BatteryWattPreferences.defaults.with(
            directionStyle: .direction,
            iconStyle: .direction,
            showSpaceBeforeUnit: false
        )
        let signed = BatteryWattPreferences.defaults.with(
            directionStyle: .signed,
            showSpaceBeforeUnit: true
        )

        #expect(PowerFormatter.powerText(7.2, direction: .discharging, preferences: direction) == "↓ 7.2W")
        #expect(PowerFormatter.powerText(7.2, direction: .discharging, preferences: signed) == "-7.2 W")

        let adapterConnected = BatteryWattPreferences.defaults.with(directionStyle: .signed)
        #expect(PowerFormatter.powerText(7.2, direction: .unknown, preferences: adapterConnected) == "7.2 W")
    }

    private func makeSnapshot(externalConnected: Bool, isCharging: Bool) -> BatterySnapshot {
        BatterySnapshot(
            batteryPercentage: 74,
            instantAmperageMilliamps: isCharging ? 4775 : -650,
            voltageMillivolts: 11754,
            externalConnected: externalConnected,
            isCharging: isCharging,
            fullyCharged: false,
            timestamp: Date(timeIntervalSince1970: 100)
        )
    }
}
#endif
