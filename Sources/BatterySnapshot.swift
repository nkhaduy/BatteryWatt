import Foundation

enum BatteryStatus: String {
    case charging = "Charging"
    case discharging = "Discharging"
    case full = "Full"
    case unavailable = "Unavailable"
}

enum TelemetrySource: String {
    case iokit = "IOKit"
    case ioreg = "ioreg"
    case unavailable = "Unavailable"
}

struct BatterySnapshot {
    let percentage: Int?
    let instantAmperage: Int?
    let voltage: Int?
    let externalConnected: Bool?
    let isCharging: Bool?
    let fullyCharged: Bool?
    let source: TelemetrySource
    let timestamp: Date

    static let unavailable = BatterySnapshot(
        percentage: nil,
        instantAmperage: nil,
        voltage: nil,
        externalConnected: nil,
        isCharging: nil,
        fullyCharged: nil,
        source: .unavailable,
        timestamp: Date()
    )

    var status: BatteryStatus {
        if isCharging == true {
            return .charging
        }
        if fullyCharged == true || percentage == 100 {
            return .full
        }
        if isCharging == false {
            return .discharging
        }
        return .unavailable
    }

    var clampedPercentage: Int? {
        guard let percentage else { return nil }
        return min(max(percentage, 0), 100)
    }

    var powerWatts: Double? {
        guard let instantAmperage, let voltage else { return nil }
        let magnitude = abs(Double(instantAmperage) * Double(voltage) / 1_000_000)

        if status == .full || magnitude < 0.05 {
            return 0
        }
        return status == .discharging ? -magnitude : magnitude
    }

    var signedCurrentAmps: Double? {
        guard let instantAmperage else { return nil }
        let magnitude = abs(Double(instantAmperage) / 1_000)
        return status == .discharging ? -magnitude : magnitude
    }

    var menuBarPowerText: String {
        guard let powerWatts else { return "-- W" }
        return String(format: "%.1f W", abs(powerWatts))
    }

    var precisePowerText: String {
        guard let powerWatts else { return "-- W" }
        return String(format: "%.2f W", abs(powerWatts))
    }
}
