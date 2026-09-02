# Architecture

BatteryWatt is a Swift Package Manager project with two meaningful layers:

## BatteryWattCore

`Sources/Core` is Foundation-only. It owns immutable battery snapshots, state classification, visibility policy, formatting, preferences, power samples, and session math. It has no AppKit, IOKit, SQLite, shell, or network dependency, which keeps the behavior easy to test.

## AppKit shell

`Sources/App` owns the native application lifecycle, direct AppleSmartBattery IOKit reads, refresh scheduling, menu bar status item, Settings, Launch at Login, SQLite history, native graph, CSV export, and sanitized diagnostics.

Telemetry is read directly on a utility queue and published to the main queue for UI updates. Missing services and missing keys produce an unavailable snapshot rather than a crash. The normal refresh path never starts a shell process.

History is opt-in. Samples are buffered and written in batches to SQLite. Raw samples are retained briefly, older data is compacted to minute points, and retention pruning bounds storage. Session integration ignores backward clock movement and gaps longer than two minutes so sleep is not counted as continuous power.

The app remains an accessory application (`LSUIElement`) with no Dock icon. Menu bar images are template SF Symbols so macOS controls their foreground color in light and dark appearances.

