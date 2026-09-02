#if canImport(XCTest)
import XCTest
import Foundation
@testable import BatteryWattCore

final class PowerSessionTests: XCTestCase {
    func testChargingSessionAccumulatesDurationEnergyAndPeak() {
        let start = makeSample(at: 0, state: .charging, watts: 40)
        var session = PowerSessionAccumulator(startingWith: start)
        session.add(makeSample(at: 60, state: .charging, watts: 50))
        session.add(makeSample(at: 120, state: .charging, watts: 30))

        XCTAssertEqual(session.duration, 120, accuracy: 0.001)
        XCTAssertEqual(session.energyWattHours, 1.416667, accuracy: 0.001)
        XCTAssertEqual(session.averageWatts, 42.5, accuracy: 0.001)
        XCTAssertEqual(session.peakWatts, 50, accuracy: 0.001)
    }

    func testLongGapsDoNotIntegrateSleepTime() {
        let start = makeSample(at: 0, state: .discharging, watts: 8)
        var session = PowerSessionAccumulator(startingWith: start)
        session.add(makeSample(at: 600, state: .discharging, watts: 8))

        XCTAssertEqual(session.duration, 0, accuracy: 0.001)
        XCTAssertEqual(session.energyWattHours, 0, accuracy: 0.001)
        XCTAssertEqual(session.sampleCount, 2)
    }

    func testStateChangeEndsTheCurrentSession() {
        let start = makeSample(at: 0, state: .charging, watts: 40)
        var session = PowerSessionAccumulator(startingWith: start)

        let accepted = session.add(makeSample(at: 1, state: .discharging, watts: 8))
        XCTAssertFalse(accepted)
        XCTAssertEqual(session.sampleCount, 1)
    }

    private func makeSample(at seconds: TimeInterval, state: BatteryState, watts: Double) -> PowerSample {
        PowerSample(
            timestamp: Date(timeIntervalSince1970: seconds),
            batteryPercentage: 74,
            state: state,
            voltageMillivolts: 11754,
            instantAmperageMilliamps: state == .charging ? 3400 : -680,
            powerWatts: watts,
            adapterConnected: state == .charging
        )
    }
}
#else
import Testing
import Foundation
@testable import BatteryWattCore

struct PowerSessionTests {
    @Test func chargingSessionAccumulatesDurationEnergyAndPeak() {
        let start = makeSample(at: 0, state: .charging, watts: 40)
        var session = PowerSessionAccumulator(startingWith: start)
        session.add(makeSample(at: 60, state: .charging, watts: 50))
        session.add(makeSample(at: 120, state: .charging, watts: 30))

        #expect(abs(session.duration - 120) < 0.001)
        #expect(abs(session.energyWattHours - 1.416667) < 0.001)
        #expect(abs(session.averageWatts - 42.5) < 0.001)
        #expect(abs(session.peakWatts - 50) < 0.001)
    }

    @Test func longGapsDoNotIntegrateSleepTime() {
        let start = makeSample(at: 0, state: .discharging, watts: 8)
        var session = PowerSessionAccumulator(startingWith: start)
        session.add(makeSample(at: 600, state: .discharging, watts: 8))

        #expect(abs(session.duration) < 0.001)
        #expect(abs(session.energyWattHours) < 0.001)
        #expect(session.sampleCount == 2)
    }

    @Test func stateChangeEndsTheCurrentSession() {
        let start = makeSample(at: 0, state: .charging, watts: 40)
        var session = PowerSessionAccumulator(startingWith: start)

        let accepted = session.add(makeSample(at: 1, state: .discharging, watts: 8))
        #expect(!accepted)
        #expect(session.sampleCount == 1)
    }

    private func makeSample(at seconds: TimeInterval, state: BatteryState, watts: Double) -> PowerSample {
        PowerSample(
            timestamp: Date(timeIntervalSince1970: seconds),
            batteryPercentage: 74,
            state: state,
            voltageMillivolts: 11754,
            instantAmperageMilliamps: state == .charging ? 3400 : -680,
            powerWatts: watts,
            adapterConnected: state == .charging
        )
    }
}
#endif
