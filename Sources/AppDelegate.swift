import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let telemetryController = TelemetryController()
    private let loginItemController = LoginItemController()
    private var statusItem: NSStatusItem?
    private var menuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()

        telemetryController.onUpdate = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        telemetryController.start()

        if CommandLine.arguments.contains("--enable-login") {
            _ = loginItemController.setEnabled(true)
        }

    }

    func applicationWillTerminate(_ notification: Notification) {
        telemetryController.stop()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = [.removalAllowed]
        statusItem.isVisible = false
        self.statusItem = statusItem

        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.font = font
        let boltImage = NSImage(
            systemSymbolName: "bolt.fill",
            accessibilityDescription: "BatteryWatt"
        )
        boltImage?.isTemplate = true
        button.image = boltImage
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.title = "-- W"
        button.toolTip = "BatteryWatt"
        button.setAccessibilityLabel("BatteryWatt power")
        button.setAccessibilityRole(.button)
    }

    private func configureMenu() {
        let controller = StatusMenuController(loginItemController: loginItemController)
        controller.onRefresh = { [weak self] in
            self?.telemetryController.refreshNow()
        }
        statusItem?.menu = controller.menu
        self.menuController = controller
    }

    private func apply(_ snapshot: BatterySnapshot) {
        let shouldShow = snapshot.externalConnected == true && snapshot.isCharging == true
        if statusItem?.isVisible != shouldShow {
            statusItem?.isVisible = shouldShow
        }

        guard shouldShow else { return }

        let title = snapshot.menuBarPowerText
        guard let button = statusItem?.button else { return }
        button.title = title

        button.toolTip = "BatteryWatt — \(snapshot.precisePowerText)"
        menuController?.update(with: snapshot)
    }
}
