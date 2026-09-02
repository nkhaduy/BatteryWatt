import Foundation

public struct PowerSample: Equatable, Sendable {
    public let timestamp: Date
    public let batteryPercentage: Int?
    public let state: BatteryState
    public let voltageMillivolts: Int
    public let instantAmperageMilliamps: Int
    public let powerWatts: Double
    public let adapterConnected: Bool

    public init(
        timestamp: Date,
        batteryPercentage: Int?,
        state: BatteryState,
        voltageMillivolts: Int,
        instantAmperageMilliamps: Int,
        powerWatts: Double,
        adapterConnected: Bool
    ) {
        self.timestamp = timestamp
        self.batteryPercentage = batteryPercentage
        self.state = state
        self.voltageMillivolts = voltageMillivolts
        self.instantAmperageMilliamps = instantAmperageMilliamps
        self.powerWatts = powerWatts
        self.adapterConnected = adapterConnected
    }
}

public struct PowerSessionSummary: Equatable, Sendable {
    public let state: BatteryState
    public let start: Date
    public let end: Date
    public let duration: TimeInterval
    public let energyWattHours: Double
    public let averageWatts: Double
    public let peakWatts: Double
    public let sampleCount: Int
    public let startBatteryPercentage: Int?
    public let endBatteryPercentage: Int?

    public init(
        state: BatteryState,
        start: Date,
        end: Date,
        duration: TimeInterval,
        energyWattHours: Double,
        averageWatts: Double,
        peakWatts: Double,
        sampleCount: Int,
        startBatteryPercentage: Int?,
        endBatteryPercentage: Int?
    ) {
        self.state = state
        self.start = start
        self.end = end
        self.duration = duration
        self.energyWattHours = energyWattHours
        self.averageWatts = averageWatts
        self.peakWatts = peakWatts
        self.sampleCount = sampleCount
        self.startBatteryPercentage = startBatteryPercentage
        self.endBatteryPercentage = endBatteryPercentage
    }
}

public struct PowerSessionAccumulator: Sendable {
    public static let maximumIntegrationGap: TimeInterval = 120

    public let state: BatteryState
    public let start: Date
    public private(set) var end: Date
    public private(set) var duration: TimeInterval = 0
    public private(set) var energyWattHours: Double = 0
    public private(set) var peakWatts: Double
    public private(set) var sampleCount = 1
    public private(set) var startBatteryPercentage: Int?
    public private(set) var endBatteryPercentage: Int?

    private var previousSample: PowerSample

    public init(startingWith sample: PowerSample) {
        state = sample.state
        start = sample.timestamp
        end = sample.timestamp
        peakWatts = sample.powerWatts
        startBatteryPercentage = sample.batteryPercentage
        endBatteryPercentage = sample.batteryPercentage
        previousSample = sample
    }

    @discardableResult
    public mutating func add(_ sample: PowerSample) -> Bool {
        guard sample.state == state else { return false }

        sampleCount += 1
        end = sample.timestamp
        endBatteryPercentage = sample.batteryPercentage
        peakWatts = max(peakWatts, sample.powerWatts)

        let gap = sample.timestamp.timeIntervalSince(previousSample.timestamp)
        if gap > 0 && gap <= Self.maximumIntegrationGap {
            duration += gap
            energyWattHours += ((previousSample.powerWatts + sample.powerWatts) / 2) * gap / 3600
        }

        previousSample = sample
        return true
    }

    public var averageWatts: Double {
        guard duration > 0 else { return peakWatts }
        return energyWattHours * 3600 / duration
    }

    public var summary: PowerSessionSummary {
        PowerSessionSummary(
            state: state,
            start: start,
            end: end,
            duration: duration,
            energyWattHours: energyWattHours,
            averageWatts: averageWatts,
            peakWatts: peakWatts,
            sampleCount: sampleCount,
            startBatteryPercentage: startBatteryPercentage,
            endBatteryPercentage: endBatteryPercentage
        )
    }
}
