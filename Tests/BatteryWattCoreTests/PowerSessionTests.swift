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
