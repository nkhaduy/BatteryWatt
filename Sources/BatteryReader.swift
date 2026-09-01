import Foundation
import IOKit

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
            return nil
        }

        let dictionary = unmanagedProperties.takeRetainedValue() as NSDictionary
        let properties = dictionary as? [String: Any] ?? [:]

        return BatterySnapshot(
            percentage: integerValue(properties["CurrentCapacity"]),
            instantAmperage: integerValue(properties["InstantAmperage"]),
            voltage: integerValue(properties["Voltage"]),
            externalConnected: boolValue(properties["ExternalConnected"]),
            isCharging: boolValue(properties["IsCharging"]),
            fullyCharged: boolValue(properties["FullyCharged"]),
            source: .iokit,
            timestamp: Date()
        )
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

final class IoregBatteryReader {
    func read() -> BatterySnapshot? {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-rn", "AppleSmartBattery"]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return parse(String(decoding: data, as: UTF8.self))
        } catch {
            return nil
        }
    }

    private func parse(_ output: String) -> BatterySnapshot? {
        guard !output.isEmpty else { return nil }

        return BatterySnapshot(
            percentage: integerValue(for: "CurrentCapacity", in: output),
            instantAmperage: integerValue(for: "InstantAmperage", in: output),
            voltage: integerValue(for: "Voltage", in: output),
            externalConnected: boolValue(for: "ExternalConnected", in: output),
            isCharging: boolValue(for: "IsCharging", in: output),
            fullyCharged: boolValue(for: "FullyCharged", in: output),
            source: .ioreg,
            timestamp: Date()
        )
    }

    private func rawValue(for key: String, in output: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\"\(escapedKey)\"\\s*=\\s*([^\\r\\n]+)"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = expression.firstMatch(in: output, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return String(output[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func integerValue(for key: String, in output: String) -> Int? {
        guard let value = rawValue(for: key, in: output) else { return nil }
        return Int(value)
    }

    private func boolValue(for key: String, in output: String) -> Bool? {
        guard let value = rawValue(for: key, in: output)?.lowercased() else { return nil }
        switch value {
        case "yes", "true", "1": return true
        case "no", "false", "0": return false
        default: return nil
        }
    }
}
