import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let telemetryController = TelemetryController()
    private let loginItemController = LoginItemController()
    private var statusItem: NSStatusItem?
    private var menuController: StatusMenuController?
    private var statusItemView: WhiteStatusItemView?
    private var lastMenuBarTitle = ""

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
        // Keep the native status button/cell for menu handling, while the
        // overlay owns the exact monochrome rendering.
        button.image = NSImage(size: NSSize(width: 14, height: 14))
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.appearance = NSAppearance(named: .darkAqua)
        let statusItemView = WhiteStatusItemView(font: font)
        statusItemView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusItemView)
        NSLayoutConstraint.activate([
            statusItemView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusItemView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusItemView.topAnchor.constraint(equalTo: button.topAnchor),
            statusItemView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        self.statusItemView = statusItemView
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
        button.contentTintColor = .white
        button.appearance = NSAppearance(named: .darkAqua)
        statusItemView?.title = title

        if title != lastMenuBarTitle {
            // The native cell keeps the status item width variable, but its
            // text is transparent so the overlay can draw the white title.
            button.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: button.font ?? .monospacedDigitSystemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: NSColor.clear
                ]
            )
            lastMenuBarTitle = title
        }

        button.toolTip = "BatteryWatt — \(snapshot.precisePowerText)"
        menuController?.update(with: snapshot)
    }
}
