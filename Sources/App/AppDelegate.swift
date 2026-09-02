import AppKit
import BatteryWattCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let telemetryController = TelemetryController()
    private let preferencesController = PreferencesController()
    private let loginItemController = LoginItemController()
    private let historyController = PowerHistoryController()
    private var statusItem: NSStatusItem?
    private var menuController: StatusMenuController?
    private var settingsWindowController: SettingsWindowController?
    private var historyWindowController: HistoryWindowController?
    private var latestSnapshot = BatterySnapshot.unavailable
    private var preferencesObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .batteryWattPreferencesDidChange,
            object: preferencesController,
            queue: .main
        ) { [weak self] _ in
            self?.applyPreferences()
        }

        telemetryController.onUpdate = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        telemetryController.updateInterval(preferencesController.values.refreshInterval)
        telemetryController.start()

        if CommandLine.arguments.contains("--enable-login") {
            _ = loginItemController.setEnabled(true)
        }
        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryController.stop()
        historyController.stop(preferences: preferencesController.values)
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = [.removalAllowed]
        statusItem.isVisible = false
        self.statusItem = statusItem

        guard let button = statusItem.button else { return }
        button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "BatteryWatt"
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel("Battery power unavailable")
    }

    private func configureMenu() {
        let controller = StatusMenuController(loginItemController: loginItemController)
        controller.onRefresh = { [weak self] in
            self?.telemetryController.refreshNow()
        }
        controller.onShowSettings = { [weak self] in
            self?.showSettings()
        }
        controller.onShowHistory = { [weak self] in
            self?.showHistory()
        }
        controller.onCopyDiagnostics = { [weak self] in
            self?.copyDiagnostics()
        }
        statusItem?.menu = controller.menu
        menuController = controller
    }

    private func apply(_ snapshot: BatterySnapshot) {
        latestSnapshot = snapshot
        let preferences = preferencesController.values
        let shouldShow = snapshot.isVisible(using: preferences)
        statusItem?.isVisible = shouldShow
        menuController?.update(with: snapshot, preferences: preferences)

        guard let button = statusItem?.button else { return }
        button.title = shouldShow ? snapshot.menuBarTitle(using: preferences) ?? "" : ""
        button.image = shouldShow ? statusImage(for: snapshot, preferences: preferences) : nil
        button.toolTip = snapshot.accessibilityLabel(using: preferences)
        button.setAccessibilityLabel(snapshot.accessibilityLabel(using: preferences))
        button.setAccessibilityValue(snapshot.menuBarTitle(using: preferences) ?? "Unavailable")

        historyController.record(snapshot, preferences: preferences)
    }

    private func applyPreferences() {
        let preferences = preferencesController.values
        telemetryController.updateInterval(preferences.refreshInterval)
        apply(latestSnapshot)
    }

    private func statusImage(for snapshot: BatterySnapshot, preferences: BatteryWattPreferences) -> NSImage? {
        let symbolName: String?
        switch preferences.iconStyle {
        case .bolt:
            symbolName = "bolt.fill"
        case .direction:
            switch snapshot.direction {
            case .charging: symbolName = "arrow.up"
            case .discharging: symbolName = "arrow.down"
            case .unknown: symbolName = "bolt.fill"
            }
        case .none:
            symbolName = nil
        }

        guard let symbolName,
              let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                preferences: preferencesController,
                loginItemController: loginItemController
            )
        }
        settingsWindowController?.show()
    }

    private func showHistory() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController(
                store: historyController.store,
                preferences: preferencesController
            )
        }
        historyWindowController?.show()
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DiagnosticsFormatter.text(for: latestSnapshot), forType: .string)
    }
}
