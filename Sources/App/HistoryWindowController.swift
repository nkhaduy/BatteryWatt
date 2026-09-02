import AppKit
import BatteryWattCore

final class HistoryWindowController: NSWindowController {
    private let historyViewController: HistoryViewController

    init(store: SQLiteHistoryStore, preferences: PreferencesController) {
        historyViewController = HistoryViewController(store: store, preferences: preferences)
        let window = NSWindow(contentViewController: historyViewController)
        window.title = "BatteryWatt History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 620, height: 470))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        if let window {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        historyViewController.refresh()
    }
}

final class HistoryViewController: NSViewController {
    private let store: SQLiteHistoryStore
    private let preferences: PreferencesController
    private let rangeControl = NSSegmentedControl(labels: ["1H", "24H", "7D"], trackingMode: .selectOne, target: nil, action: nil)
    private let chartView = PowerChartView()
    private let currentValue = NSTextField(labelWithString: "--")
    private let averageValue = NSTextField(labelWithString: "--")
    private let peakValue = NSTextField(labelWithString: "--")
    private let sessionValue = NSTextField(labelWithString: "No completed session yet")
    private let emptyLabel = NSTextField(labelWithString: "No local history yet")
    private let exportButton = NSButton(title: "Export CSV…", target: nil, action: nil)

    init(store: SQLiteHistoryStore, preferences: PreferencesController) {
        self.store = store
        self.preferences = preferences
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView()
        let title = NSTextField(labelWithString: "Power history")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Battery-side power, stored only on this Mac.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        rangeControl.selectedSegment = 0
        rangeControl.target = self
        rangeControl.action = #selector(rangeChanged(_:))
        rangeControl.setAccessibilityLabel("History range")

        exportButton.target = self
        exportButton.action = #selector(exportCSV(_:))

        let header = NSStackView(views: [title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4

        let controls = NSStackView(views: [rangeControl, exportButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12

        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        chartView.setAccessibilityLabel("Power history chart")

        let stats = NSStackView(views: [metric("Current", currentValue), metric("Average", averageValue), metric("Peak", peakValue)])
        stats.orientation = .horizontal
        stats.distribution = .fillEqually
        stats.spacing = 18

        sessionValue.font = .systemFont(ofSize: 12)
        sessionValue.textColor = .secondaryLabelColor
        sessionValue.maximumNumberOfLines = 2
        sessionValue.setAccessibilityLabel("Last power session")

        emptyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.isHidden = true

        let stack = NSStackView(views: [header, controls, chartView, emptyLabel, stats, sessionValue])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            controls.widthAnchor.constraint(equalTo: stack.widthAnchor),
            chartView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            emptyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stats.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sessionValue.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        view = root
    }

    func refresh() {
        guard isViewLoaded else { return }
        let range: TimeInterval = rangeControl.selectedSegment == 0 ? 3600 : rangeControl.selectedSegment == 1 ? 86_400 : 604_800
        let since = Date(timeIntervalSinceNow: -range)
        let points = store.points(since: since)
        let stats = store.stats(since: since)
        chartView.points = points
        currentValue.stringValue = format(stats.currentWatts)
        averageValue.stringValue = format(stats.averageWatts)
        peakValue.stringValue = format(stats.peakWatts)
        emptyLabel.isHidden = !points.isEmpty

        if let session = store.lastSession() {
            let direction = session.state == .charging ? "Charging" : "Discharging"
            sessionValue.stringValue = "Last \(direction.lowercased()) session · \(formatDuration(session.duration)) · average \(format(session.averageWatts)) · peak \(format(session.peakWatts)) · ~\(String(format: "%.1f", session.energyWattHours)) Wh"
        } else {
            sessionValue.stringValue = preferences.values.recordHistory ? "No completed session yet" : "Enable local history in Settings to record sessions."
        }
    }

    private func metric(_ title: String, _ value: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        value.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        let stack = NSStackView(views: [titleLabel, value])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        return stack
    }

    private func format(_ watts: Double?) -> String {
        guard let watts else { return "--" }
        return String(format: "%.1f W", locale: Locale(identifier: "en_US_POSIX"), watts)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    @objc private func rangeChanged(_ sender: NSSegmentedControl) {
        refresh()
    }

    @objc private func exportCSV(_ sender: NSButton) {
        CSVExporter(store: store).present()
    }
}

private final class PowerChartView: NSView {
    var points: [HistoryPoint] = [] {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let plot = bounds.insetBy(dx: 12, dy: 18)
        guard points.count > 1 else {
            if points.count == 1 {
                drawPoint(at: plot.midX, y: plot.midY)
            }
            return
        }

        guard let first = points.first, let last = points.last else { return }
        let maxWatts = max(points.map(\.watts).max() ?? 1, 1)
        let span = max(last.timestamp.timeIntervalSince(first.timestamp), 1)
        let grid = NSBezierPath()
        for step in 0...3 {
            let y = plot.minY + plot.height * CGFloat(step) / 3
            grid.move(to: NSPoint(x: plot.minX, y: y))
            grid.line(to: NSPoint(x: plot.maxX, y: y))
        }
        NSColor.separatorColor.setStroke()
        grid.lineWidth = 0.5
        grid.stroke()

        let path = NSBezierPath()
        for (index, point) in points.enumerated() {
            let x = plot.minX + plot.width * CGFloat(point.timestamp.timeIntervalSince(first.timestamp) / span)
            let y = plot.minY + plot.height * CGFloat(point.watts / maxWatts)
            let location = NSPoint(x: x, y: y)
            if index == 0 {
                path.move(to: location)
            } else {
                path.line(to: location)
            }
        }
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawPoint(at x: CGFloat, y: CGFloat) {
        let path = NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6))
        NSColor.controlAccentColor.setFill()
        path.fill()
    }
}
