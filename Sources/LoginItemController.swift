import Foundation
import ServiceManagement

final class LoginItemController {
    private let preferenceKey = "openAtLogin"
    private let launchAgentLabel = "com.batterywatt.menu"

    private var launchAgentURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentLabel).plist")
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
            return true
        }
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        UserDefaults.standard.set(enabled, forKey: preferenceKey)

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    // Re-register so an app update cannot leave the login item
                    // pointing at an older bundle path.
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                    if SMAppService.mainApp.status == .enabled {
                        removeLaunchAgent()
                        return true
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                    if SMAppService.mainApp.status != .enabled {
                        removeLaunchAgent()
                        return true
                    }
                }
            } catch {
                // Fall through to the LaunchAgent path for ad-hoc/local installs.
            }
        }

        return setLaunchAgent(enabled)
    }

    private func setLaunchAgent(_ enabled: Bool) -> Bool {
        if enabled {
            do {
                let directory = launchAgentURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

                let plist: [String: Any] = [
                    "Label": launchAgentLabel,
                    "ProgramArguments": ["/usr/bin/open", "-gj", Bundle.main.bundlePath],
                    "RunAtLoad": true,
                    "LimitLoadToSessionType": "Aqua",
                    "ProcessType": "Interactive"
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: launchAgentURL, options: .atomic)
                _ = runLaunchctl(["bootstrap", "gui/\(getuid())", launchAgentURL.path])
                return FileManager.default.fileExists(atPath: launchAgentURL.path)
            } catch {
                return false
            }
        }

        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(launchAgentLabel)"])
        removeLaunchAgent()
        return !FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentURL)
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
