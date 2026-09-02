# BatteryWatt Launch Copy

Draft copy for the repository owner to adapt and post manually. Do not mass-post or imply endorsements, usage numbers, or hardware coverage that has not been verified.

## GitHub release announcement

BatteryWatt 1.0.0 is now public: a small native macOS menu bar utility that shows real-time MacBook battery-side power while charging or discharging.

- Native AppKit utility for macOS 13+
- Charging and discharging visibility modes
- Optional local history and CSV export
- No analytics, accounts, cloud sync, or normal-operation network dependency
- Homebrew and official DMG installation

BatteryWatt reports power at the battery, not total wall-outlet or system consumption. The initial release is universal and ad-hoc signed; Intel telemetry is still awaiting physical verification.

https://github.com/nkhaduy/BatteryWatt

## Reddit: r/macapps

I built BatteryWatt, a small native macOS menu bar app that shows how much power is flowing into or out of a MacBook battery in real time.

It supports charging and discharging modes, optional local history, and CSV export. There are no analytics, accounts, or cloud services. The value is battery-side power, so it is not a wall-meter reading or a total system-power reading.

Install with:

```sh
brew install --cask nkhaduy/batterywatt/batterywatt
```

Feedback from different MacBook models is especially useful. Please do not include serial numbers or private diagnostics.

## Reddit: r/mac

BatteryWatt is a native menu bar utility for watching MacBook battery-side watts in real time. It shows both charging and discharging, keeps optional history local, and stays focused on one measurement instead of becoming a full system monitor.

The release is available through Homebrew and GitHub. Battery-side power is intentionally different from charger-rated wattage or total Mac consumption.

## Hacker News: Show HN

### Title

Show HN: BatteryWatt - see MacBook battery power in real time from the menu bar

### Body

I wanted to know how many watts were actually flowing into my MacBook battery instead of seeing the charger's rated wattage, so I built a small native menu bar utility. It now also shows discharge power and optional local history.

BatteryWatt reads AppleSmartBattery telemetry directly through IOKit. It reports battery-side power, not total wall-outlet or system consumption. There are no analytics or server connections, and history is opt-in and local.

The project is open source and the release is available through Homebrew and a checksum-published GitHub DMG. Intel telemetry still needs physical hardware testing.

## Short social post

BatteryWatt shows real-time MacBook battery-side power in the menu bar - charging or discharging, native, private, and local. Homebrew + open source: https://github.com/nkhaduy/BatteryWatt

## Hardware compatibility request

When asking for compatibility reports, request only:

- Mac model and chip
- macOS version
- BatteryWatt version
- Whether charging and discharging telemetry work

Never request serial numbers, account names, full home paths, or unredacted diagnostics.
