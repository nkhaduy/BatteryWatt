import Foundation

public enum BatteryState: String, Codable, Equatable, Sendable {
    case charging = "Charging"
    case discharging = "Discharging"
    case fullyCharged = "Fully Charged"
    case adapterConnectedNotCharging = "Adapter Connected - Not Charging"
    case unknown = "Unknown"
}

public enum TelemetrySource: String, Codable, Equatable, Sendable {
    case iokit = "IOKit"
    case unavailable = "Unavailable"
}

public enum PowerDirection: Equatable, Sendable {
    case charging
    case discharging
    case unknown
}

public struct BatterySnapshot: Equatable, Sendable {
    public let batteryPercentage: Int?
    public let instantAmperageMilliamps: Int?
    public let voltageMillivolts: Int?
    public let externalConnected: Bool?
    public let isCharging: Bool?
    public let fullyCharged: Bool?
    public let telemetrySource: TelemetrySource
    public let timestamp: Date

    public init(
        batteryPercentage: Int?,
        instantAmperageMilliamps: Int?,
        voltageMillivolts: Int?,
        externalConnected: Bool?,
        isCharging: Bool?,
        fullyCharged: Bool?,
        telemetrySource: TelemetrySource = .iokit,
        timestamp: Date
    ) {
        self.batteryPercentage = batteryPercentage
        self.instantAmperageMilliamps = instantAmperageMilliamps
        self.voltageMillivolts = voltageMillivolts
        self.externalConnected = externalConnected
        self.isCharging = isCharging
        self.fullyCharged = fullyCharged
        self.telemetrySource = telemetrySource
        self.timestamp = timestamp
    }

    public static let unavailable = BatterySnapshot(
        batteryPercentage: nil,
        instantAmperageMilliamps: nil,
        voltageMillivolts: nil,
        externalConnected: nil,
        isCharging: nil,
        fullyCharged: nil,
        telemetrySource: .unavailable,
        timestamp: Date()
    )

    public var clampedPercentage: Int? {
        guard let batteryPercentage else { return nil }
        return min(max(batteryPercentage, 0), 100)
    }

    public var powerWatts: Double? {
        guard let instantAmperageMilliamps, let voltageMillivolts else { return nil }
        return abs(Double(voltageMillivolts) * Double(instantAmperageMilliamps) / 1_000_000)
    }

    public var state: BatteryState {
        if externalConnected == true && isCharging == true {
            return .charging
        }
        if externalConnected == true && isCharging == false {
            if fullyCharged == true || clampedPercentage == 100 {
                return .fullyCharged
            }
            return .adapterConnectedNotCharging
        }
        if externalConnected == false && isCharging == false && powerWatts != nil {
            return .discharging
        }
        return .unknown
    }

    public var direction: PowerDirection {
        switch state {
        case .charging: return .charging
        case .discharging: return .discharging
        case .fullyCharged, .adapterConnectedNotCharging, .unknown: return .unknown
        }
    }

    public var hasValidReading: Bool {
        voltageMillivolts != nil && instantAmperageMilliamps != nil
    }

    public func menuBarTitle(using preferences: BatteryWattPreferences) -> String? {
        switch state {
        case .charging, .discharging:
            guard let powerWatts else { return nil }
            return PowerFormatter.powerText(powerWatts, direction: direction, preferences: preferences)
        case .fullyCharged:
            return "Full"
        case .adapterConnectedNotCharging:
            return "AC"
        case .unknown:
            return nil
        }
    }

    public func accessibilityLabel(using preferences: BatteryWattPreferences) -> String {
        guard let powerWatts else { return "Battery power unavailable" }
        let stateText = state.rawValue.lowercased()
        let powerText = PowerFormatter.powerText(powerWatts, direction: direction, preferences: preferences)
        return "Battery power, \(stateText), \(powerText)"
    }

    public func isVisible(using preferences: BatteryWattPreferences) -> Bool {
        guard hasValidReading else { return false }

        if preferences.hideWhenFull && (fullyCharged == true || clampedPercentage == 100) {
            return false
        }

        switch preferences.menuBarVisibility {
        case .chargingOnly:
            return state == .charging && isAboveThreshold(preferences.hideBelowWatts)
        case .always:
            return (state == .charging || state == .discharging) && isAboveThreshold(preferences.hideBelowWatts)
        case .onBatteryOnly:
            return state == .discharging && isAboveThreshold(preferences.hideBelowWatts)
        case .adapterConnected:
            return externalConnected == true
        }
    }

    private func isAboveThreshold(_ threshold: Double) -> Bool {
        guard let powerWatts else { return false }
        return powerWatts >= threshold
    }
}
