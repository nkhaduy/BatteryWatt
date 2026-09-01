import AppKit

final class StatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    var onRefresh: (() -> Void)?

    private let loginItemController: LoginItemController
    private let batteryView = MenuHeaderView(title: "Battery")
    private let powerView = MenuPowerView()
    private let voltageView = MenuMetricRowView(title: "Voltage")
    private let currentView = MenuMetricRowView(title: "Current")
    private let statusView = MenuMetricRowView(title: "Status")
    private let adapterView = MenuMetricRowView(title: "Adapter")
    private let refreshRateView = MenuMetricRowView(title: "Refresh rate")
    private lazy var loginMenuItem = NSMenuItem(
        title: "Open at Login",
        action: #selector(toggleLogin(_:)),
        keyEquivalent: ""
    )

    init(loginItemController: LoginItemController) {
        self.loginItemController = loginItemController
        super.init()
        buildMenu()
    }

    func update(with snapshot: BatterySnapshot) {
        batteryView.value = snapshot.clampedPercentage.map { "\($0)%" } ?? "--%"
        powerView.value = snapshot.precisePowerText
        voltageView.value = snapshot.voltage.map { String(format: "%.3f V", Double($0) / 1_000) } ?? "-- V"
        currentView.value = snapshot.signedCurrentAmps.map { String(format: "%.3f A", $0) } ?? "-- A"
        statusView.value = snapshot.status.rawValue
        adapterView.value = snapshot.externalConnected.map { $0 ? "Connected" : "Not connected" } ?? "--"
        refreshRateView.value = "1 second"
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem.state = loginItemController.isEnabled ? .on : .off
    }

    private func buildMenu() {
        menu.autoenablesItems = false
        menu.delegate = self

        menu.addItem(makeViewItem(batteryView))
        menu.addItem(makeViewItem(powerView))
        menu.addItem(.separator())
        menu.addItem(makeViewItem(voltageView))
        menu.addItem(makeViewItem(currentView))
        menu.addItem(makeViewItem(statusView))
        menu.addItem(makeViewItem(adapterView))
        menu.addItem(makeViewItem(refreshRateView))
        menu.addItem(.separator())

        loginMenuItem.target = self
        menu.addItem(loginMenuItem)

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refresh), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let aboutItem = NSMenuItem(title: "About BatteryWatt", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit BatteryWatt", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeViewItem(_ view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        return item
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        let enabled = sender.state == .off
        if loginItemController.setEnabled(enabled) {
            sender.state = enabled ? .on : .off
        } else {
            sender.state = enabled ? .off : .on
        }
    }

    @objc private func refresh() {
        onRefresh?()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private final class MenuHeaderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "--%")

    var value: String {
        get { valueLabel.stringValue }
        set { valueLabel.stringValue = newValue }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 40)
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 40).isActive = true

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .right
        addSubview(titleLabel)
        addSubview(valueLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class MenuPowerView: NSView {
    private let label = NSTextField(labelWithString: "Power")
    private let valueLabel = NSTextField(labelWithString: "-- W")

    var value: String {
        get { valueLabel.stringValue }
        set { valueLabel.stringValue = newValue }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 42)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        valueLabel.textColor = .labelColor
        addSubview(label)
        addSubview(valueLabel)
        label.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            valueLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class MenuMetricRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "--")

    var value: String {
        get { valueLabel.stringValue }
        set { valueLabel.stringValue = newValue }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 22)
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .right
        addSubview(titleLabel)
        addSubview(valueLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
