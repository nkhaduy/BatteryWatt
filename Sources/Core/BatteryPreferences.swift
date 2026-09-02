import Foundation

public enum MenuBarVisibility: String, Codable, CaseIterable, Sendable {
    case chargingOnly
    case always
    case onBatteryOnly
    case adapterConnected

    public var displayName: String {
        switch self {
        case .chargingOnly: return "Charging only"
        case .always: return "Always"
        case .onBatteryOnly: return "On battery only"
        case .adapterConnected: return "Adapter connected"
        }
    }
}

public enum RefreshInterval: Int, Codable, CaseIterable, Sendable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10

    public var seconds: TimeInterval { TimeInterval(rawValue) }
    public var displayName: String { "(rawValue) second\(rawValue == 1 ? "" : "s")" }
}

public enum DirectionStyle: String, Codable, CaseIterable, Sendable {
    case boltOnly
    case direction
    case signed

    public var displayName: String {
        switch self {
        case .boltOnly: return "Bolt only"
        case .direction: return "Direction"
        case .signed: return "Signed"
        }
    }
}

public enum IconStyle: String, Codable, CaseIterable, Sendable {
    case bolt
    case direction
    case none

    public var displayName: String {
        switch self {
        case .bolt: return "Bolt"
        case .direction: return "Direction"
        case .none: return "None"
        }
    }
}

public enum HistoryRetention: Int, Codable, CaseIterable, Sendable {
    case oneHour = 1
    case oneDay = 24
    case sevenDays = 168
    case thirtyDays = 720

    public var displayName: String {
        switch self {
        case .oneHour: return "1 hour"
        case .oneDay: return "24 hours"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        }
    }
}

public struct BatteryWattPreferences {
    public static let defaults = BatteryWattPreferences()

    public var menuBarVisibility: MenuBarVisibility
    public var refreshInterval: RefreshInterval
    public var directionStyle: DirectionStyle
    public var iconStyle: IconStyle
    public var decimalPlaces: Int
    public var showSpaceBeforeUnit: Bool
    public var hideWhenFull: Bool
    public var hideBelowWatts: Double
    public var recordHistory: Bool
    public var historyRetention: HistoryRetention

    private let store: UserDefaults?

    public init() {
        menuBarVisibility = .chargingOnly
        refreshInterval = .oneSecond
        directionStyle = .boltOnly
        iconStyle = .bolt
        decimalPlaces = 1
        showSpaceBeforeUnit = true
        hideWhenFull = true
        hideBelowWatts = 0.5
        recordHistory = false
        historyRetention = .oneDay
        store = nil
    }

    public init(store: UserDefaults) {
        let defaults = BatteryWattPreferences()
        menuBarVisibility = MenuBarVisibility(rawValue: store.string(forKey: Keys.menuBarVisibility) ?? "") ?? defaults.menuBarVisibility
        refreshInterval = RefreshInterval(rawValue: store.integer(forKey: Keys.refreshInterval)) ?? defaults.refreshInterval
        directionStyle = DirectionStyle(rawValue: store.string(forKey: Keys.directionStyle) ?? "") ?? defaults.directionStyle
        iconStyle = IconStyle(rawValue: store.string(forKey: Keys.iconStyle) ?? "") ?? defaults.iconStyle
        decimalPlaces = min(max(store.object(forKey: Keys.decimalPlaces) as? Int ?? defaults.decimalPlaces, 0), 2)
        showSpaceBeforeUnit = store.object(forKey: Keys.showSpaceBeforeUnit) as? Bool ?? defaults.showSpaceBeforeUnit
        hideWhenFull = store.object(forKey: Keys.hideWhenFull) as? Bool ?? defaults.hideWhenFull
        hideBelowWatts = max(store.object(forKey: Keys.hideBelowWatts) as? Double ?? defaults.hideBelowWatts, 0)
        recordHistory = store.object(forKey: Keys.recordHistory) as? Bool ?? defaults.recordHistory
        historyRetention = HistoryRetention(rawValue: store.integer(forKey: Keys.historyRetention)) ?? defaults.historyRetention
        self.store = store
    }

    public func with(
        menuBarVisibility: MenuBarVisibility? = nil,
        refreshInterval: RefreshInterval? = nil,
        directionStyle: DirectionStyle? = nil,
        iconStyle: IconStyle? = nil,
        decimalPlaces: Int? = nil,
        showSpaceBeforeUnit: Bool? = nil,
        hideWhenFull: Bool? = nil,
        hideBelowWatts: Double? = nil,
        recordHistory: Bool? = nil,
        historyRetention: HistoryRetention? = nil
    ) -> BatteryWattPreferences {
        var copy = self
        if let menuBarVisibility { copy.menuBarVisibility = menuBarVisibility }
        if let refreshInterval { copy.refreshInterval = refreshInterval }
        if let directionStyle { copy.directionStyle = directionStyle }
        if let iconStyle { copy.iconStyle = iconStyle }
        if let decimalPlaces { copy.decimalPlaces = min(max(decimalPlaces, 0), 2) }
        if let showSpaceBeforeUnit { copy.showSpaceBeforeUnit = showSpaceBeforeUnit }
        if let hideWhenFull { copy.hideWhenFull = hideWhenFull }
        if let hideBelowWatts { copy.hideBelowWatts = max(hideBelowWatts, 0) }
        if let recordHistory { copy.recordHistory = recordHistory }
        if let historyRetention { copy.historyRetention = historyRetention }
        return copy
    }

    public mutating func save() {
        guard let store else { return }
        store.set(menuBarVisibility.rawValue, forKey: Keys.menuBarVisibility)
        store.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
        store.set(directionStyle.rawValue, forKey: Keys.directionStyle)
        store.set(iconStyle.rawValue, forKey: Keys.iconStyle)
        store.set(decimalPlaces, forKey: Keys.decimalPlaces)
        store.set(showSpaceBeforeUnit, forKey: Keys.showSpaceBeforeUnit)
        store.set(hideWhenFull, forKey: Keys.hideWhenFull)
        store.set(hideBelowWatts, forKey: Keys.hideBelowWatts)
        store.set(recordHistory, forKey: Keys.recordHistory)
        store.set(historyRetention.rawValue, forKey: Keys.historyRetention)
    }

    private enum Keys {
        static let menuBarVisibility = "menuBarVisibility"
        static let refreshInterval = "refreshInterval"
        static let directionStyle = "directionStyle"
        static let iconStyle = "iconStyle"
        static let decimalPlaces = "decimalPlaces"
        static let showSpaceBeforeUnit = "showSpaceBeforeUnit"
        static let hideWhenFull = "hideWhenFull"
        static let hideBelowWatts = "hideBelowWatts"
        static let recordHistory = "recordHistory"
        static let historyRetention = "historyRetention"
    }
}

public enum PowerFormatter {
    public static func powerText(
        _ watts: Double,
        direction: PowerDirection = .unknown,
        preferences: BatteryWattPreferences
    ) -> String {
        let number: String
        switch preferences.decimalPlaces {
        case 0:
            number = String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), abs(watts))
        case 2:
            number = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), abs(watts))
        default:
            number = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), abs(watts))
        }

        let signedNumber: String
        switch preferences.directionStyle {
        case .boltOnly, .direction:
            if preferences.directionStyle == .direction {
                signedNumber = direction == .charging ? "↑ \(number)" : direction == .discharging ? "↓ \(number)" : number
            } else {
                signedNumber = number
            }
        case .signed:
            signedNumber = direction == .discharging ? "-\(number)" : "+\(number)"
        }

        return signedNumber + (preferences.showSpaceBeforeUnit ? " W" : "W")
    }
}
