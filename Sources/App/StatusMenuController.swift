import AppKit
import BatteryWattCore

final class StatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    var onRefresh: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onCopyDiagnostics: (() -> Void)?

    private let loginItemController: LoginItemController
    private let batteryView = MenuHeaderView(title: "Battery")
    private let powerView = MenuPowerView()
    private let voltageView = MenuMetricRowView(title: "Voltage")
    private let currentView = MenuMetricRowView(title: "Current")
    private let statusView = MenuMetricRowView(title: "Status")
    private let adapterView = MenuMetricRowView(title: "Adapter")
    private let noteView = MenuNoteView(text: "Battery-side power · entirely on-device")
    private lazy var loginMenuItem = NSMenuItem(
        title: "Launch at Login",
        action: #selector(toggleLogin(_:)),
        keyEquivalent: ""
    )

    init(loginItemController: LoginItemController) {
        self.loginItemController = loginItemController
        super.init()
        buildMenu()
    }

    func update(with snapshot: BatterySnapshot, preferences: BatteryWattPreferences) {
        batteryView.value = snapshot.clampedPercentage.map { "\($0)%" } ?? "--%"
        if let power = snapshot.powerWatts {
            powerView.value = PowerFormatter.powerText(
                power,
                direction: snapshot.direction,
                preferences: preferences
            )
        } else {
            powerView.value = "--"
        }
        voltageView.value = snapshot.voltageMillivolts.map { String(format: "%.3f V", Double($0) / 1_000) } ?? "-- V"
        currentView.value = snapshot.instantAmperageMilliamps.map { String(format: "%.3f A", Double($0) / 1_000) } ?? "-- A"
        statusView.value = snapshot.state.rawValue
        adapterView.value = snapshot.externalConnected.map { $0 ? "Connected" : "Not connected" } ?? "--"

        powerView.setValueAccessibility(snapshot.powerWatts.map {
            PowerFormatter.powerText($0, direction: snapshot.direction, preferences: preferences)
        } ?? "Unavailable")
        statusView.setValueAccessibility(snapshot.state.rawValue)
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
        menu.addItem(makeViewItem(noteView))
        menu.addItem(.separator())

        addActionItem(title: "Refresh Now", action: #selector(refresh))
        addActionItem(title: "Settings…", action: #selector(showSettings))
        addActionItem(title: "Power History…", action: #selector(showHistory))

        loginMenuItem.target = self
        menu.addItem(loginMenuItem)

        addActionItem(title: "Copy Diagnostics", action: #selector(copyDiagnostics))
        addActionItem(title: "About BatteryWatt", action: #selector(showAbout))
        addActionItem(title: "Quit BatteryWatt", action: #selector(quit), keyEquivalent: "q")
    }

    private func addActionItem(title: String, action: Selector, keyEquivalent: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
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
        }
    }

    @objc private func refresh() {
        onRefresh?()
    }

    @objc private func showSettings() {
        onShowSettings?()
    }

    @objc private func showHistory() {
        onShowHistory?()
    }

    @objc private func copyDiagnostics() {
        onCopyDiagnostics?()
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
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)

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

    required init?(coder: NSCoder) { nil }
}

private final class MenuPowerView: NSView {
    private let label = NSTextField(labelWithString: "Battery-side power")
    private let valueLabel = NSTextField(labelWithString: "--")

    var value: String {
        get { valueLabel.stringValue }
        set { valueLabel.stringValue = newValue }
    }

    func setValueAccessibility(_ value: String) {
        valueLabel.setAccessibilityValue(value)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 48)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 48).isActive = true
        setAccessibilityRole(.group)
        setAccessibilityLabel("Battery-side power")
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

    required init?(coder: NSCoder) { nil }
}

private final class MenuMetricRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "--")

    var value: String {
        get { valueLabel.stringValue }
        set { valueLabel.stringValue = newValue }
    }

    func setValueAccessibility(_ value: String) {
        valueLabel.setAccessibilityValue(value)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 22)
    }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
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

    required init?(coder: NSCoder) { nil }
}

private final class MenuNoteView: NSView {
    private let label: NSTextField

    init(text: String) {
        label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }
}
