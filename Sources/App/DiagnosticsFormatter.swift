import Foundation
import Darwin
import BatteryWattCore

enum DiagnosticsFormatter {
    static func text(for snapshot: BatterySnapshot) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let model = modelIdentifier() ?? "unknown"
        let voltage = snapshot.voltageMillivolts.map(String.init) ?? "unavailable"
        let current = snapshot.instantAmperageMilliamps.map(String.init) ?? "unavailable"
        let power = snapshot.powerWatts.map { String(format: "%.5f W", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "unavailable"

        return """
        BatteryWatt \(version)
        macOS \(osVersion)
        Mac model \(model)
        State \(snapshot.state.rawValue)
        Battery \(snapshot.clampedPercentage.map { "\($0)%" } ?? "unavailable")
        External connected \(snapshot.externalConnected.map { $0 ? "yes" : "no" } ?? "unknown")
        Is charging \(snapshot.isCharging.map { $0 ? "yes" : "no" } ?? "unknown")
        Voltage \(voltage) mV
        Instant amperage \(current) mA
        Battery-side power \(power)
        Telemetry source \(snapshot.telemetrySource.rawValue)
        """
    }

    private static func modelIdentifier() -> String? {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
