# BatteryWatt Public Release Design

## Goal

Turn the existing BatteryWatt native menu-bar utility into a trustworthy v1.0.0 public macOS product: it measures battery-side charging and discharging power, stays lightweight and private, ships through verifiable release artifacts, and is understandable to a new GitHub visitor within seconds.

## Scope And Phasing

### P0: Required for v1.0.0

- Charging and discharging measurements from direct IOKit telemetry.
- Charging-only default plus Always, On battery only, and Adapter connected modes.
- Native Settings window with persistent preferences and migration-safe defaults.
- Direction style, icon style, decimals, refresh interval, full-battery and low-reading controls.
- Launch at Login, status/menu accessibility, no Dock icon, and correct lifecycle cleanup.
- Accurate battery-side power wording in the UI, README, privacy statement, and release notes.
- Foundation unit tests for power math, state/visibility logic, unavailable telemetry, and formatting.
- CLI build, check, DMG, ZIP, checksum, and release scripts.
- README, screenshots/demo assets when safely capturable, MIT/community/security/privacy files, CI, and tagged-release automation.

### P1: Included when the native implementation remains bounded

- Opt-in local SQLite history with bounded retention and batched writes.
- Native history window with 1H/24H/7D range selection, compact graph, current/average/peak values, and a last-session summary.
- Session tracking for charging and discharging with sleep/wake gap protection and approximate Wh estimates.
- CSV export through NSSavePanel.
- Sanitized Copy Diagnostics action.

### P2: Explicitly deferred

- Sparkle updates until Developer ID signing and notarization are available.
- Automatic energy aggregation beyond the bounded history store.
- Telemetry change notifications if they add platform-specific complexity without improving measured behavior.
- Intel support if cross-architecture or AppleSmartBattery behavior does not verify on real hardware.

## Product Behavior

Battery power is calculated as:

`Voltage(mV) * abs(InstantAmperage(mA)) / 1_000_000`

Charging is `ExternalConnected == true && IsCharging == true`. Discharging is an unplugged battery with a valid nonzero current. Adapter-connected-but-not-charging and fully charged are separate states. No menu-bar item is shown for unavailable telemetry or idle zero power unless a future explicit product decision changes that behavior.

Visibility modes:

| Mode | Visible state |
| --- | --- |
| Charging only | Active charging, above threshold, and not hidden by full-battery preference |
| Always | Active charging or discharging, subject to threshold/full-battery preferences |
| On battery only | Active discharging, subject to threshold/full-battery preferences |
| Adapter connected | Any valid external adapter state; non-power idle states use a compact status title rather than `0.0 W` |

Default mode remains Charging only for existing and new users. Default direction style is Bolt only. Default icon is `bolt.fill`. Default refresh is one second. Default history recording is off to avoid unexpected local retention and disk work.

## Architecture

The Swift package has a small Foundation core target and a native AppKit executable target.

- `BatteryWattCore`: immutable snapshots, power/state calculations, formatters, display preferences, visibility policy, power samples, and session math. This target has no AppKit, IOKit, shell, or network dependency and is covered by unit tests.
- `BatteryWatt`: AppKit lifecycle, direct AppleSmartBattery IOKit reader, background refresh controller, login-item controller, status item/menu, Settings window, history window, SQLite persistence, diagnostics, and CSV export.
- The normal telemetry path never starts a child process. Missing registry data returns an unavailable snapshot and keeps the process alive.
- SQLite is linked only for opt-in local history. Samples are buffered and written in batches, raw samples are short-lived, and older data is rolled into minute points before retention pruning.

## Native UX

The status item uses a template SF Symbol and semantic AppKit rendering, with a compact one-line wattage title. The menu is a native `NSMenu` containing current battery context, Refresh Now, Settings, History, Launch at Login, diagnostics, About, and Quit. Settings use standard native controls and grouped sections rather than custom web-style panels. The history window uses native drawing for a small graph and no chart dependency.

All dynamic values receive useful accessibility labels, including direction and state text so meaning does not depend on color or arrows.

## Privacy And Security

The app does not make network requests during normal operation and has no analytics or tracking code. History is local, opt-in, bounded, and export-only through a user-selected save panel. Diagnostics exclude serial numbers, usernames, home paths, and device identifiers. Release automation never embeds signing secrets; signing and notarization are optional lanes controlled by CI secrets.

## Release Engineering

The repository uses command-line Swift compilation because no Xcode installation is present on the development Mac. The release script produces an arm64-first universal app when the x86_64 cross-build verifies, an ad-hoc signed `.app`, a DMG with an Applications alias, a ZIP, and `SHA256SUMS.txt`. GitHub Actions builds and tests on macOS runners; tagged releases upload the same artifacts. Developer ID signing/notarization is enabled only when credentials exist.

The public repository is intended to be `nkhaduy/BatteryWatt`, with a separate `nkhaduy/homebrew-batterywatt` tap if the authenticated GitHub account permits creation. The npm package is only an explicit-install helper for official GitHub release DMGs and never uses a postinstall hook.

## Acceptance Criteria

- A first-time user can understand the product, install it, and remove it from README instructions without guessing.
- A current user sees Charging only after upgrade unless they intentionally change the setting.
- Charging and discharging behavior is covered by automated tests and verified against raw telemetry fixtures.
- The installed Release artifact has no Dock icon, no per-second shell child, no network dependency, and only one status item/process after relaunch.
- README media contains only real installed-app captures; unavailable hardware states are reported rather than simulated or fabricated.
- Release artifacts are checksummed, downloadable, and reflected in Homebrew metadata when the public release exists.
- No tracked secrets, private paths, serial numbers, personal notifications, or private screenshots are published.
