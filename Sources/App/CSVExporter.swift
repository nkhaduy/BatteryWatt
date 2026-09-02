import AppKit

final class CSVExporter {
    private let store: SQLiteHistoryStore

    init(store: SQLiteHistoryStore) {
        self.store = store
    }

    func present() {
        let panel = NSSavePanel()
        let store = self.store
        panel.nameFieldStringValue = "BatteryWatt-history.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let date = Date(timeIntervalSinceNow: -30 * 24 * 60 * 60)
            _ = store.exportCSV(to: url, since: date)
        }
    }
}
