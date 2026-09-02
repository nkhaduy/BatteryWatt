import AppKit
import BatteryWattCore

final class SettingsWindowController: NSWindowController {
    private let settingsViewController: SettingsViewController

    init(preferences: PreferencesController, loginItemController: LoginItemController) {
        settingsViewController = SettingsViewController(
            preferences: preferences,
            loginItemController: loginItemController
        )
        let window = NSWindow(contentViewController: settingsViewController)
        window.title = "BatteryWatt Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 620))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        if let window {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SettingsViewController: NSViewController {
    private let preferences: PreferencesController
    private let loginItemController: LoginItemController

    private let visibilityPopup = NSPopUpButton()
    private let refreshPopup = NSPopUpButton()
    private let directionPopup = NSPopUpButton()
    private let iconPopup = NSPopUpButton()
    private let decimalsPopup = NSPopUpButton()
    private let spaceCheckbox = NSButton(checkboxWithTitle: "Show space before W", target: nil, action: nil)
    private let fullCheckbox = NSButton(checkboxWithTitle: "Hide when battery is full", target: nil, action: nil)
    private let thresholdField = NSTextField(string: "0.5")
    private let historyCheckbox = NSButton(checkboxWithTitle: "Record local power history", target: nil, action: nil)
    private let retentionPopup = NSPopUpButton()
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)

    init(preferences: PreferencesController, loginItemController: LoginItemController) {
        self.preferences = preferences
        self.loginItemController = loginItemController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 860))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(top: 26, left: 28, bottom: 28, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        scrollView.documentView = contentView
        view = scrollView

        let preferences = self.preferences.values
        configurePopups(preferences)
        loginCheckbox.state = loginItemController.isEnabled ? .on : .off

        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin(_:))
        spaceCheckbox.target = self
        spaceCheckbox.action = #selector(toggleSpace(_:))
        fullCheckbox.target = self
        fullCheckbox.action = #selector(toggleFull(_:))
        historyCheckbox.target = self
        historyCheckbox.action = #selector(toggleHistory(_:))
        thresholdField.target = self
        thresholdField.action = #selector(updateThreshold(_:))
        thresholdField.alignment = .right
        thresholdField.formatter = decimalFormatter()
        thresholdField.setAccessibilityLabel("Hide readings below watts")

        fullCheckbox.state = preferences.hideWhenFull ? .on : .off
        spaceCheckbox.state = preferences.showSpaceBeforeUnit ? .on : .off
        historyCheckbox.state = preferences.recordHistory ? .on : .off
        thresholdField.stringValue = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), preferences.hideBelowWatts)

        stack.addArrangedSubview(section("General", [
            loginCheckbox,
            row("Menu Bar Visibility", visibilityPopup),
            row("Refresh Interval", refreshPopup)
        ]))
        stack.addArrangedSubview(section("Display", [
            row("Direction Style", directionPopup),
            row("Icon", iconPopup),
            row("Decimals", decimalsPopup),
            spaceCheckbox
        ]))
        stack.addArrangedSubview(section("Behavior", [
            fullCheckbox,
            row("Hide readings below", suffixField(thresholdField, suffix: "W"))
        ]))
        stack.addArrangedSubview(section("History", [
            historyCheckbox,
            row("Retention", retentionPopup),
            historyDescription()
        ]))
        stack.addArrangedSubview(supportDescription())
    }

    private func configurePopups(_ preferences: BatteryWattPreferences) {
        visibilityPopup.addItems(withTitles: MenuBarVisibility.allCases.map(\.displayName))
        refreshPopup.addItems(withTitles: RefreshInterval.allCases.map(\.displayName))
        directionPopup.addItems(withTitles: DirectionStyle.allCases.map(\.displayName))
        iconPopup.addItems(withTitles: IconStyle.allCases.map(\.displayName))
        decimalsPopup.addItems(withTitles: ["0", "1", "2"])
        retentionPopup.addItems(withTitles: HistoryRetention.allCases.map(\.displayName))

        visibilityPopup.selectItem(withTitle: preferences.menuBarVisibility.displayName)
        refreshPopup.selectItem(withTitle: preferences.refreshInterval.displayName)
        directionPopup.selectItem(withTitle: preferences.directionStyle.displayName)
        iconPopup.selectItem(withTitle: preferences.iconStyle.displayName)
        decimalsPopup.selectItem(withTitle: "\(preferences.decimalPlaces)")
        retentionPopup.selectItem(withTitle: preferences.historyRetention.displayName)

        visibilityPopup.target = self
        visibilityPopup.action = #selector(updateVisibility(_:))
        refreshPopup.target = self
        refreshPopup.action = #selector(updateRefresh(_:))
        directionPopup.target = self
        directionPopup.action = #selector(updateDirection(_:))
        iconPopup.target = self
        iconPopup.action = #selector(updateIcon(_:))
        decimalsPopup.target = self
        decimalsPopup.action = #selector(updateDecimals(_:))
        retentionPopup.target = self
        retentionPopup.action = #selector(updateRetention(_:))

        for control in [visibilityPopup, refreshPopup, directionPopup, iconPopup, decimalsPopup, retentionPopup] {
            control.setAccessibilityRole(.popUpButton)
        }
    }

    private func section(_ title: String, _ views: [NSView]) -> NSView {
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.setAccessibilityRole(.staticText)

        let stack = NSStackView(views: [titleLabel] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func row(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 16
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 190).isActive = true
        control.widthAnchor.constraint(equalToConstant: 190).isActive = true
        return row
    }

    private func suffixField(_ field: NSTextField, suffix: String) -> NSView {
        let suffixLabel = NSTextField(labelWithString: suffix)
        suffixLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [field, suffixLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        return stack
    }

    private func historyDescription() -> NSView {
        let label = NSTextField(labelWithString: "History stays on this Mac. Samples are batched and older data is compacted automatically.")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 390
        label.setAccessibilityRole(.staticText)
        return label
    }

    private func supportDescription() -> NSView {
        let label = NSTextField(labelWithString: "BatteryWatt is designed for MacBook models with an internal battery. On a desktop Mac, it stays hidden when no AppleSmartBattery service is available.")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 390
        label.setAccessibilityRole(.staticText)
        return label
    }

    private func decimalFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimum = 0
        formatter.maximum = 10_000
        formatter.maximumFractionDigits = 2
        return formatter
    }

    @objc private func toggleLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        if !loginItemController.setEnabled(enabled) {
            sender.state = enabled ? .off : .on
        }
    }

    @objc private func toggleSpace(_ sender: NSButton) {
        preferences.update { $0.showSpaceBeforeUnit = sender.state == .on }
    }

    @objc private func toggleFull(_ sender: NSButton) {
        preferences.update { $0.hideWhenFull = sender.state == .on }
    }

    @objc private func toggleHistory(_ sender: NSButton) {
        preferences.update { $0.recordHistory = sender.state == .on }
    }

    @objc private func updateThreshold(_ sender: NSTextField) {
        let value = max(sender.doubleValue, 0)
        preferences.update { $0.hideBelowWatts = value }
        sender.stringValue = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    @objc private func updateVisibility(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let value = MenuBarVisibility.allCases.first(where: { $0.displayName == title }) else { return }
        preferences.update { $0.menuBarVisibility = value }
    }

    @objc private func updateRefresh(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let value = RefreshInterval.allCases.first(where: { $0.displayName == title }) else { return }
        preferences.update { $0.refreshInterval = value }
    }

    @objc private func updateDirection(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let value = DirectionStyle.allCases.first(where: { $0.displayName == title }) else { return }
        preferences.update { $0.directionStyle = value }
    }

    @objc private func updateIcon(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let value = IconStyle.allCases.first(where: { $0.displayName == title }) else { return }
        preferences.update { $0.iconStyle = value }
    }

    @objc private func updateDecimals(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem, let value = Int(title) else { return }
        preferences.update { $0.decimalPlaces = value }
    }

    @objc private func updateRetention(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem,
              let value = HistoryRetention.allCases.first(where: { $0.displayName == title }) else { return }
        preferences.update { $0.historyRetention = value }
    }
}
