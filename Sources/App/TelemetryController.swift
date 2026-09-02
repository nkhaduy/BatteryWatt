import Foundation
import BatteryWattCore

final class TelemetryController {
    var onUpdate: ((BatterySnapshot) -> Void)?

    private let reader = AppleSmartBatteryReader()
    private let queue = DispatchQueue(label: "com.batterywatt.telemetry", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var interval: RefreshInterval = .oneSecond

    func start() {
        guard timer == nil else { return }
        scheduleTimer()
    }

    func updateInterval(_ interval: RefreshInterval) {
        self.interval = interval
        guard timer != nil else { return }
        stop()
        start()
    }

    func refreshNow() {
        queue.async { [weak self] in
            self?.readAndPublish()
        }
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }

    private func scheduleTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(Int(interval.seconds * 1_000)),
            leeway: .milliseconds(100)
        )
        timer.setEventHandler { [weak self] in
            self?.readAndPublish()
        }
        self.timer = timer
        timer.resume()
    }

    private func readAndPublish() {
        let snapshot = reader.read() ?? .unavailable
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(snapshot)
        }
    }
}
