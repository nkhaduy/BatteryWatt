import Foundation

final class TelemetryController {
    var onUpdate: ((BatterySnapshot) -> Void)?

    private let directReader = AppleSmartBatteryReader()
    private let fallbackReader = IoregBatteryReader()
    private let queue = DispatchQueue(label: "com.batterywatt.telemetry", qos: .utility)
    private var timer: DispatchSourceTimer?

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.readAndPublish()
        }
        self.timer = timer
        timer.resume()
    }

    func refreshNow() {
        queue.async { [weak self] in
            self?.readAndPublish()
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }

    private func readAndPublish() {
        let directSnapshot = directReader.read()
        let snapshot: BatterySnapshot

        if let directSnapshot,
           directSnapshot.instantAmperage != nil,
           directSnapshot.voltage != nil {
            snapshot = directSnapshot
        } else if let fallbackSnapshot = fallbackReader.read() {
            snapshot = fallbackSnapshot
        } else {
            snapshot = .unavailable
        }

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(snapshot)
        }
    }
}
