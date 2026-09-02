import Foundation
import BatteryWattCore

final class PowerHistoryController {
    let store = SQLiteHistoryStore()
    private var activeSession: PowerSessionAccumulator?

    func record(_ snapshot: BatterySnapshot, preferences: BatteryWattPreferences) {
        guard preferences.recordHistory,
              let powerWatts = snapshot.powerWatts,
              snapshot.state == .charging || snapshot.state == .discharging,
              let voltage = snapshot.voltageMillivolts,
              let current = snapshot.instantAmperageMilliamps else {
            return
        }

        let sample = PowerSample(
            timestamp: snapshot.timestamp,
            batteryPercentage: snapshot.clampedPercentage,
            state: snapshot.state,
            voltageMillivolts: voltage,
            instantAmperageMilliamps: current,
            powerWatts: powerWatts,
            adapterConnected: snapshot.externalConnected == true
        )
        store.record(sample, retention: preferences.historyRetention)

        if var activeSession {
            if activeSession.add(sample) {
                self.activeSession = activeSession
            } else {
                store.saveSession(activeSession.summary)
                self.activeSession = PowerSessionAccumulator(startingWith: sample)
            }
        } else {
            activeSession = PowerSessionAccumulator(startingWith: sample)
        }
    }

    func stop(preferences: BatteryWattPreferences) {
        if preferences.recordHistory, let activeSession {
            store.saveSession(activeSession.summary)
        }
        activeSession = nil
        store.flush(retention: preferences.historyRetention)
    }
}
