import Foundation
import IOKit
import BatteryWattCore

final class AppleSmartBatteryReader {
    func read() -> BatterySnapshot? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            return nil
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { return nil }
            defer { IOObjectRelease(service) }

            var unmanagedProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service,
                &unmanagedProperties,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let unmanagedProperties else {
                continue
            }

            let dictionary = unmanagedProperties.takeRetainedValue() as NSDictionary
            let properties = dictionary as? [String: Any] ?? [:]
            return BatterySnapshot(
                batteryPercentage: integerValue(properties["CurrentCapacity"]),
                instantAmperageMilliamps: integerValue(properties["InstantAmperage"]),
                voltageMillivolts: integerValue(properties["Voltage"]),
                externalConnected: boolValue(properties["ExternalConnected"]),
                isCharging: boolValue(properties["IsCharging"]),
                fullyCharged: boolValue(properties["FullyCharged"]),
                telemetrySource: .iokit,
                timestamp: Date()
            )
        }
    }

    private func integerValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let value = value as? Int {
            return value
        }
        if let value = value as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let value = value as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "yes", "true", "1": return true
            case "no", "false", "0": return false
            default: return nil
            }
        }
        return nil
    }
}
