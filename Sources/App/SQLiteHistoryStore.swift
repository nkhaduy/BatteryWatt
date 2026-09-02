import Foundation
import SQLite3
import BatteryWattCore

struct HistoryPoint: Equatable {
    let timestamp: Date
    let watts: Double
    let state: BatteryState
}

struct HistoryStats {
    let currentWatts: Double?
    let averageWatts: Double?
    let peakWatts: Double?
}

final class SQLiteHistoryStore {
    private let queue = DispatchQueue(label: "com.batterywatt.history", qos: .utility)
    private var database: OpaquePointer?
    private var pendingSamples: [PowerSample] = []

    private var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("BatteryWatt", isDirectory: true)
            .appendingPathComponent("PowerHistory.sqlite3")
    }

    init() {}

    deinit {
        queue.sync {
            flushOnQueue(retention: .oneDay)
            if let database {
                sqlite3_close(database)
            }
        }
    }

    func record(_ sample: PowerSample, retention: HistoryRetention) {
        queue.async { [weak self] in
            guard let self else { return }
            openDatabase()
            guard database != nil else { return }
            pendingSamples.append(sample)
            if pendingSamples.count >= 15 {
                flushOnQueue(retention: retention)
            }
        }
    }

    func saveSession(_ summary: PowerSessionSummary) {
        queue.async { [weak self] in
            self?.openDatabase()
            self?.insertSessionOnQueue(summary)
        }
    }

    func flush(retention: HistoryRetention = .oneDay) {
        queue.sync {
            flushOnQueue(retention: retention)
        }
    }

    func points(since date: Date) -> [HistoryPoint] {
        queue.sync {
            openDatabase()
            flushOnQueue(retention: .thirtyDays)
            return queryPointsOnQueue(since: date)
        }
    }

    func stats(since date: Date) -> HistoryStats {
        let points = points(since: date)
        guard !points.isEmpty else {
            return HistoryStats(currentWatts: nil, averageWatts: nil, peakWatts: nil)
        }
        return HistoryStats(
            currentWatts: points.last?.watts,
            averageWatts: points.map(\.watts).reduce(0, +) / Double(points.count),
            peakWatts: points.map(\.watts).max()
        )
    }

    func exportCSV(to url: URL, since date: Date) -> Bool {
        queue.sync {
            openDatabase()
            flushOnQueue(retention: .thirtyDays)
            let rows = queryCSVRowsOnQueue(since: date)
            let header = "timestamp,battery_percent,state,voltage_v,current_a,power_w\n"
            let body = rows.map { row in
                "\(row.timestamp),\(row.batteryPercentage),\(row.state),\(row.voltage),\(row.current),\(row.watts)"
            }.joined(separator: "\n")
            do {
                try (header + body + (body.isEmpty ? "" : "\n")).write(to: url, atomically: true, encoding: .utf8)
                return true
            } catch {
                return false
            }
        }
    }

    func lastSession() -> PowerSessionSummary? {
        queue.sync {
            openDatabase()
            guard let database else { return nil }
            let sql = """
            SELECT state, start, end, duration, energy_wh, average_w, peak_w,
                   sample_count, start_battery_percent, end_battery_percent
            FROM sessions ORDER BY end DESC LIMIT 1
            """
            guard let statement = prepare(sql, database: database) else { return nil }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return PowerSessionSummary(
                state: BatteryState(rawValue: text(statement, column: 0)) ?? .unknown,
                start: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                end: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                duration: sqlite3_column_double(statement, 3),
                energyWattHours: sqlite3_column_double(statement, 4),
                averageWatts: sqlite3_column_double(statement, 5),
                peakWatts: sqlite3_column_double(statement, 6),
                sampleCount: Int(sqlite3_column_int64(statement, 7)),
                startBatteryPercentage: optionalInt(statement, column: 8),
                endBatteryPercentage: optionalInt(statement, column: 9)
            )
        }
    }

    private func openDatabase() {
        guard database == nil else { return }
        let directory = databaseURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return
        }

        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            if let database {
                sqlite3_close(database)
            }
            database = nil
            return
        }

        execute("PRAGMA journal_mode = WAL;")
        execute("PRAGMA synchronous = NORMAL;")
        execute("""
        CREATE TABLE IF NOT EXISTS samples (
            timestamp REAL PRIMARY KEY,
            battery_percent INTEGER,
            state TEXT NOT NULL,
            voltage_mv INTEGER NOT NULL,
            current_ma INTEGER NOT NULL,
            watts REAL NOT NULL,
            adapter_connected INTEGER NOT NULL
        );
        """)
        execute("""
        CREATE TABLE IF NOT EXISTS minute_samples (
            timestamp REAL PRIMARY KEY,
            battery_percent INTEGER,
            state TEXT NOT NULL,
            voltage_mv REAL NOT NULL,
            current_ma REAL NOT NULL,
            watts_avg REAL NOT NULL,
            watts_peak REAL NOT NULL,
            adapter_connected INTEGER NOT NULL
        );
        """)
        execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            state TEXT NOT NULL,
            start REAL NOT NULL,
            end REAL NOT NULL,
            duration REAL NOT NULL,
            energy_wh REAL NOT NULL,
            average_w REAL NOT NULL,
            peak_w REAL NOT NULL,
            sample_count INTEGER NOT NULL,
            start_battery_percent INTEGER,
            end_battery_percent INTEGER
        );
        """)
    }

    private func flushOnQueue(retention: HistoryRetention) {
        guard let database, !pendingSamples.isEmpty else {
            pruneOnQueue(retention: retention)
            return
        }

        execute("BEGIN TRANSACTION;")
        let sql = """
        INSERT OR REPLACE INTO samples
        (timestamp, battery_percent, state, voltage_mv, current_ma, watts, adapter_connected)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        guard let statement = prepare(sql, database: database) else {
            execute("ROLLBACK;")
            return
        }
        for sample in pendingSamples {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_double(statement, 1, sample.timestamp.timeIntervalSince1970)
            bindOptionalInt(statement, index: 2, value: sample.batteryPercentage)
            bindText(statement, index: 3, value: sample.state.rawValue)
            sqlite3_bind_int64(statement, 4, sqlite3_int64(sample.voltageMillivolts))
            sqlite3_bind_int64(statement, 5, sqlite3_int64(sample.instantAmperageMilliamps))
            sqlite3_bind_double(statement, 6, sample.powerWatts)
            sqlite3_bind_int(statement, 7, sample.adapterConnected ? 1 : 0)
            _ = sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        pendingSamples.removeAll(keepingCapacity: true)
        execute("COMMIT;")
        rollUpOnQueue()
        pruneOnQueue(retention: retention)
    }

    private func rollUpOnQueue() {
        let cutoff = Date().timeIntervalSince1970 - 3600
        execute("""
        INSERT OR REPLACE INTO minute_samples
        (timestamp, battery_percent, state, voltage_mv, current_ma, watts_avg, watts_peak, adapter_connected)
        SELECT CAST(timestamp / 60 AS INTEGER) * 60,
               CAST(AVG(battery_percent) AS INTEGER),
               MAX(state), AVG(voltage_mv), AVG(current_ma), AVG(watts), MAX(watts), MAX(adapter_connected)
        FROM samples WHERE timestamp < \(cutoff) GROUP BY CAST(timestamp / 60 AS INTEGER);
        """)
        execute("DELETE FROM samples WHERE timestamp < \(cutoff);")
    }

    private func pruneOnQueue(retention: HistoryRetention) {
        let cutoff = Date().timeIntervalSince1970 - TimeInterval(retention.rawValue) * 3600
        execute("DELETE FROM minute_samples WHERE timestamp < \(cutoff);")
        execute("DELETE FROM samples WHERE timestamp < \(cutoff);")
    }

    private func queryPointsOnQueue(since date: Date) -> [HistoryPoint] {
        guard let database else { return [] }
        let now = Date().timeIntervalSince1970
        let rawSince = max(date.timeIntervalSince1970, now - 3600)
        let sql = """
        SELECT timestamp, watts_avg, state FROM minute_samples WHERE timestamp >= ? AND timestamp < ?
        UNION ALL
        SELECT timestamp, watts, state FROM samples WHERE timestamp >= ?
        ORDER BY timestamp ASC;
        """
        guard let statement = prepare(sql, database: database) else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, rawSince)
        sqlite3_bind_double(statement, 3, rawSince)

        var points: [HistoryPoint] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            points.append(HistoryPoint(
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0)),
                watts: sqlite3_column_double(statement, 1),
                state: BatteryState(rawValue: text(statement, column: 2)) ?? .unknown
            ))
        }
        return points
    }

    private func queryCSVRowsOnQueue(since date: Date) -> [CSVRow] {
        guard let database else { return [] }
        let sql = """
        SELECT timestamp, battery_percent, state, voltage_mv / 1000.0, current_ma / 1000.0, watts
        FROM samples WHERE timestamp >= ?
        UNION ALL
        SELECT timestamp, battery_percent, state, voltage_mv / 1000.0, current_ma / 1000.0, watts_avg
        FROM minute_samples WHERE timestamp >= ?
        ORDER BY timestamp ASC;
        """
        guard let statement = prepare(sql, database: database) else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, date.timeIntervalSince1970)
        var rows: [CSVRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(CSVRow(
                timestamp: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))),
                batteryPercentage: optionalInt(statement, column: 1).map(String.init) ?? "",
                state: text(statement, column: 2),
                voltage: String(format: "%.3f", sqlite3_column_double(statement, 3)),
                current: String(format: "%.3f", sqlite3_column_double(statement, 4)),
                watts: String(format: "%.3f", sqlite3_column_double(statement, 5))
            ))
        }
        return rows
    }

    private func insertSessionOnQueue(_ summary: PowerSessionSummary) {
        guard let database else { return }
        let sql = """
        INSERT INTO sessions
        (state, start, end, duration, energy_wh, average_w, peak_w, sample_count, start_battery_percent, end_battery_percent)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        guard let statement = prepare(sql, database: database) else { return }
        defer { sqlite3_finalize(statement) }
        bindText(statement, index: 1, value: summary.state.rawValue)
        sqlite3_bind_double(statement, 2, summary.start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 3, summary.end.timeIntervalSince1970)
        sqlite3_bind_double(statement, 4, summary.duration)
        sqlite3_bind_double(statement, 5, summary.energyWattHours)
        sqlite3_bind_double(statement, 6, summary.averageWatts)
        sqlite3_bind_double(statement, 7, summary.peakWatts)
        sqlite3_bind_int64(statement, 8, sqlite3_int64(summary.sampleCount))
        bindOptionalInt(statement, index: 9, value: summary.startBatteryPercentage)
        bindOptionalInt(statement, index: 10, value: summary.endBatteryPercentage)
        _ = sqlite3_step(statement)
    }

    private func execute(_ sql: String) {
        guard let database else { return }
        sqlite3_exec(database, sql, nil, nil, nil)
    }

    private func prepare(_ sql: String, database: OpaquePointer) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        return statement
    }

    private func bindText(_ statement: OpaquePointer, index: Int32, value: String) {
        _ = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
    }

    private func bindOptionalInt(_ statement: OpaquePointer, index: Int32, value: Int?) {
        if let value {
            sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }

    private func optionalInt(_ statement: OpaquePointer, column: Int32) -> Int? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, column))
    }
}

private struct CSVRow {
    let timestamp: String
    let batteryPercentage: String
    let state: String
    let voltage: String
    let current: String
    let watts: String
}
