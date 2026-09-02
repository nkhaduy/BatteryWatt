# BatteryWatt Public Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship BatteryWatt 1.0.0 as a focused, native, privacy-first MacBook battery-power monitor with tested source, a polished release surface, and verifiable distribution artifacts.

**Architecture:** Preserve the AppKit shell and direct AppleSmartBattery IOKit path while extracting battery math, state policy, formatting, preferences, samples, and session accounting into a Foundation core target. Add native Settings/history windows and an opt-in SQLite store behind the shell, then package the existing executable as a reproducible app/DMG/ZIP release.

**Tech Stack:** Swift 5.9+/SwiftPM, Foundation, AppKit, IOKit, ServiceManagement, SQLite3, shell scripts, GitHub Actions, GitHub CLI, npm built-ins, and native macOS tools.

**Spec:** `docs/superpowers/specs/2026-09-03-batterywatt-public-release-design.md`

## Global Constraints

- Keep BatteryWatt native AppKit with no Electron, browser runtime, analytics, tracking, or normal-operation network dependency.
- Preserve `com.batterywatt.menu`, `LSUIElement=true`, Charging only as the default, and the existing working telemetry behavior.
- Use direct public IOKit registry access as the normal reader; do not spawn `ioreg` every second.
- Keep battery-side power wording distinct from wall/USB-C adapter draw.
- Prefer Apple Silicon and ship universal2 only after the x86_64 build and telemetry path verify cleanly.
- History is opt-in, local-only, bounded, batched, and must not materially increase CPU, RAM, or disk activity.
- Do not publish fabricated screenshots, demo telemetry, metrics, testimonials, secrets, private paths, or personal data.
- Use ad-hoc signing when no Developer ID identity exists and report notarization as blocked when credentials are unavailable.

---

### Task 1: Product Record, Package Targets, And Core TDD

**Files:**
- Create: `PRODUCT.md`
- Create: `docs/superpowers/specs/2026-09-03-batterywatt-public-release-design.md`
- Create: `Sources/Core/BatterySnapshot.swift`
- Create: `Sources/Core/BatteryPreferences.swift`
- Create: `Sources/Core/PowerSession.swift`
- Create: `Tests/BatteryWattCoreTests/BatterySnapshotTests.swift`
- Create: `Tests/BatteryWattCoreTests/BatteryPreferencesTests.swift`
- Create: `Tests/BatteryWattCoreTests/PowerSessionTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Produces `BatterySnapshot`, `BatteryState`, `MenuBarVisibility`, `DirectionStyle`, `IconStyle`, `BatteryWattPreferences`, `PowerSample`, and `PowerSessionAccumulator` for the AppKit target.

- [ ] **Step 1: Add failing tests for power math, state, visibility, and formatting.**

```swift
func testPowerUsesMillivoltsAndMilliamps() {
    let snapshot = BatterySnapshot(
        batteryPercentage: 74,
        instantAmperageMilliamps: -4775,
        voltageMillivolts: 11754,
        externalConnected: false,
        isCharging: false,
        fullyCharged: false,
        timestamp: Date()
    )

    XCTAssertEqual(snapshot.powerWatts, 56.12685, accuracy: 0.00001)
}

func testOnlyActivelyChargingSnapshotIsChargingVisibleByDefault() {
    let snapshot = BatterySnapshot(
        batteryPercentage: 37,
        instantAmperageMilliamps: 4775,
        voltageMillivolts: 11754,
        externalConnected: true,
        isCharging: true,
        fullyCharged: false,
        timestamp: Date()
    )

    XCTAssertTrue(snapshot.isVisible(using: .defaults))
}

func testUnavailableSnapshotDoesNotCrashOrBecomeVisible() {
    XCTAssertNil(BatterySnapshot.unavailable.powerWatts)
    XCTAssertFalse(BatterySnapshot.unavailable.isVisible(using: .defaults))
}

func testDisplayFormattingUsesRequestedDecimalPlaces() {
    XCTAssertEqual(PowerFormatter.powerText(4.18, preferences: .defaults), "4.2 W")
    XCTAssertEqual(PowerFormatter.powerText(19.84, preferences: .defaults), "19.8 W")
    XCTAssertEqual(PowerFormatter.powerText(56.13, preferences: .defaults), "56.1 W")
}
```

- [ ] **Step 2: Run the focused tests and verify they fail because the core target/API is absent.**

Run: `swift test --filter BatterySnapshotTests`

Expected: compilation failure naming the missing `BatteryWattCore` types, not a runtime test failure.

- [ ] **Step 3: Add a SwiftPM core library, executable target, and test target.**

```swift
targets: [
    .target(name: "BatteryWattCore", path: "Sources/Core"),
    .executableTarget(name: "BatteryWatt", dependencies: ["BatteryWattCore"], path: "Sources/App", linkerSettings: [.linkedLibrary("sqlite3")]),
    .testTarget(name: "BatteryWattCoreTests", dependencies: ["BatteryWattCore"], path: "Tests/BatteryWattCoreTests")
]
```

Use `.macOS(.v13)` so the manifest compiles with the repository's Swift 5.9 tools while the app can still run on current macOS.

- [ ] **Step 4: Implement the smallest Foundation-only core that satisfies the tests.**

`BatterySnapshot.powerWatts` returns `nil` when either raw value is missing and otherwise returns `abs(Double(voltage) * Double(current) / 1_000_000)`. `isVisible(using:)` combines state, visibility mode, threshold, and the full-battery preference. `PowerFormatter` uses a fixed POSIX locale and the configured decimals/spacing/direction style.

- [ ] **Step 5: Run the focused tests and then the full core suite.**

Run: `swift test --filter BatteryWattCoreTests`

Expected: all core tests pass with no warnings.

- [ ] **Step 6: Add preference and session edge-case tests, implement them, and re-run.**

Cover `Charging only`, `Always`, `On battery only`, `Adapter connected`, the default migration values, a sleep gap larger than two minutes, state transitions, and weighted energy accumulation without integrating across a gap.

- [ ] **Step 7: Commit the product record and core foundation.**

```bash
git add PRODUCT.md docs/superpowers Sources/Core Tests Package.swift
git commit -m "feat: add BatteryWatt core domain and release design"
```

### Task 2: Direct Telemetry And Refresh Lifecycle

**Files:**
- Create: `Sources/App/BatteryReader.swift`
- Create: `Sources/App/TelemetryController.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/Core/BatterySnapshot.swift`
- Test: `Tests/BatteryWattCoreTests/BatterySnapshotTests.swift`

**Interfaces:**
- Produces `AppleSmartBatteryReader.read() -> BatterySnapshot?` and `TelemetryController.start()`, `stop()`, `refreshNow()`, `updateInterval(_:)`.

- [ ] **Step 1: Add a reader-state fixture test that proves missing keys produce an unavailable result.**
- [ ] **Step 2: Run it red before moving the reader into the App target.**
- [ ] **Step 3: Move the existing direct IOKit reader into `Sources/App`, iterate safely over the matching service, release every IOKit object, and remove the normal `Process`/`ioreg` fallback.**
- [ ] **Step 4: Keep all reads on a utility queue, publish snapshots on the main queue, cancel the timer in `stop()`, and make repeated `start()`/`stop()` idempotent.**
- [ ] **Step 5: Run `swift test` and `swift build -c release`; inspect the process tree to confirm no shell helper is launched by a normal read.**
- [ ] **Step 6: Commit the telemetry lifecycle.**

```bash
git add Sources/App Sources/Core Tests
git commit -m "refactor: use direct battery telemetry lifecycle"
```

### Task 3: Preferences, Status Item, And Native Settings

**Files:**
- Create: `Sources/App/PreferencesController.swift`
- Create: `Sources/App/SettingsWindowController.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/App/StatusMenuController.swift`
- Modify: `Sources/App/LoginItemController.swift`
- Test: `Tests/BatteryWattCoreTests/BatteryPreferencesTests.swift`

**Interfaces:**
- Produces persistent `UserDefaults` preferences, status item display policy, and `SettingsWindowController.show()`.

- [ ] **Step 1: Add failing preference round-trip tests using an isolated `UserDefaults` suite.**
- [ ] **Step 2: Run the tests red.**
- [ ] **Step 3: Implement enum-backed preference storage with explicit defaults: Charging only, 1 second, Bolt only, one decimal, space before W, hide full, 0.5 W threshold, and history off.**
- [ ] **Step 4: Update the status item to use `bolt.fill`, `arrow.up`, or `arrow.down` as template images; remove the image for None; expose meaningful VoiceOver labels containing state, direction, and wattage.**
- [ ] **Step 5: Implement a compact native Settings window with General, Display, Behavior, and History groups using `NSButton` checkboxes, `NSPopUpButton`, and labeled fields.**
- [ ] **Step 6: Wire preference changes to the status item and refresh interval; keep Launch at Login on `SMAppService` with the existing reversible LaunchAgent fallback.**
- [ ] **Step 7: Run tests/build and manually verify light/dark semantic rendering and no Dock icon in the built app's `Info.plist`.**
- [ ] **Step 8: Commit the native preferences surface.**

```bash
git add Sources/App Tests
git commit -m "feat: add native display preferences and settings"
```

### Task 4: Opt-In Local History, Sessions, Graph, CSV, And Diagnostics

**Files:**
- Create: `Sources/App/SQLiteHistoryStore.swift`
- Create: `Sources/App/HistoryWindowController.swift`
- Create: `Sources/App/DiagnosticsFormatter.swift`
- Create: `Sources/App/CSVExporter.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `Sources/App/StatusMenuController.swift`
- Modify: `Sources/Core/PowerSession.swift`
- Test: `Tests/BatteryWattCoreTests/PowerSessionTests.swift`

**Interfaces:**
- Produces batched local sample persistence, `HistoryWindowController.show()`, CSV export, sanitized diagnostics, and `PowerSessionAccumulator` summaries.

- [ ] **Step 1: Add failing session tests for charging/discharging starts, ends, peak/average, Wh, and long-gap handling.**
- [ ] **Step 2: Run the session tests red.**
- [ ] **Step 3: Implement session accumulation with bounded time integration and no energy added across gaps longer than 120 seconds or when the clock moves backward.**
- [ ] **Step 4: Implement SQLite tables for raw samples, minute aggregates, and completed sessions; batch writes, roll raw data older than one hour into minute points, and prune by 1 hour/24 hours/7 days/30 days.**
- [ ] **Step 5: Add a compact native history window with range controls, current/average/peak summaries, a native-drawn graph, and a clear empty state when history is disabled or unavailable.**
- [ ] **Step 6: Add NSSavePanel CSV export with only timestamp, battery_percent, state, voltage_v, current_a, and power_w.**
- [ ] **Step 7: Add Copy Diagnostics with app version, macOS version, model identifier, sanitized state, raw voltage/current, calculated power, and telemetry source only.**
- [ ] **Step 8: Run tests, build, and inspect the history database size after a short recording session.**
- [ ] **Step 9: Commit the opt-in history feature.**

```bash
git add Sources/App Sources/Core Tests
git commit -m "feat: add opt-in local power history"
```

### Task 5: Metadata, Branding, Build, Package, And Verification Scripts

**Files:**
- Modify: `Resources/Info.plist`
- Create: `Resources/AppIcon.iconset/icon_16x16.png` and the remaining 32/64/128/256/512/1024 PNGs
- Create: `scripts/build.sh`
- Create: `scripts/check.sh`
- Create: `scripts/package-dmg.sh`
- Create: `scripts/release.sh`
- Create: `assets/batterywatt-social-preview.svg`
- Create: `assets/batterywatt-wordmark.svg`
- Modify: `.gitignore`
- Remove or replace: `Resources/BatteryWattIcon.png` only after the new icon is verified at all sizes

**Interfaces:**
- Produces `build/BatteryWatt.app`, `dist/BatteryWatt-<version>.dmg`, `dist/BatteryWatt-<version>.zip`, and `dist/SHA256SUMS.txt` from CLI-only commands.

- [ ] **Step 1: Add script checks that fail for missing source files, invalid plist metadata, or missing test commands.**
- [ ] **Step 2: Run `scripts/check.sh` red before adding the scripts and metadata.**
- [ ] **Step 3: Generate a flat, high-contrast battery/bolt icon with a monochrome-friendly silhouette and render all required icon sizes through `sips`/`iconutil`.**
- [ ] **Step 4: Set `CFBundleDisplayName`, `CFBundleName`, `CFBundleIdentifier=com.batterywatt.menu`, `CFBundleShortVersionString=1.0.0`, `CFBundleVersion=1`, `LSMinimumSystemVersion=13.0`, `LSUIElement=true`, and icon metadata.**
- [ ] **Step 5: Implement `scripts/build.sh` with `set -euo pipefail`, `xcrun swiftc`, arm64-first compilation, optional verified x86_64 compilation, `lipo` universal assembly, app bundling, and ad-hoc signing.**
- [ ] **Step 6: Implement DMG staging with an Applications alias, ZIP creation, and SHA-256 output.**
- [ ] **Step 7: Implement `scripts/release.sh` to build/package/check without contacting a remote, and document optional Developer ID/notarytool environment variables without printing them.**
- [ ] **Step 8: Run `scripts/check.sh`, `scripts/build.sh 1.0.0`, and `scripts/package-dmg.sh 1.0.0`; inspect `file`, `plutil`, `codesign`, `hdiutil`, and checksums.**
- [ ] **Step 9: Commit the packaging foundation.**

```bash
git add Resources scripts assets .gitignore
git commit -m "build: add reproducible macOS release packaging"
```

### Task 6: Public Documentation, Demo Assets, And Community Files

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `CHANGELOG.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `PRIVACY.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `docs/RELEASING.md`
- Create: `docs/assets/` captures only after installed-release QA
- Create: `docs/index.html` only if the static landing page stays smaller than the README value it adds

**Interfaces:**
- Produces first-screen install instructions, transparent battery-side wording, support workflow, release process, community governance, and real media paths.

- [ ] **Step 1: Write README structure and run link/path checks against all referenced files.**
- [ ] **Step 2: Add a real hero screenshot only after safe installed-app capture; include no Stats branding beyond neutral “alongside utilities like Stats” wording.**
- [ ] **Step 3: Add a short real demo video and an optimized preview only if the Mac can safely show the required live states; otherwise document the capture limitation rather than fabricate media.**
- [ ] **Step 4: Add MIT, Keep a Changelog, contribution, security, privacy, code-of-conduct, issue forms, PR template, and reproducible release docs.**
- [ ] **Step 5: Run local secret scans across tracked files and history, verify no private paths or identifiers are in public assets, and commit documentation/community files.**

```bash
git add README.md LICENSE CHANGELOG.md CONTRIBUTING.md SECURITY.md PRIVACY.md CODE_OF_CONDUCT.md .github docs
git commit -m "docs: prepare BatteryWatt for open source"
```

### Task 7: CI, Release Workflow, npm Helper, And Homebrew Tap

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`
- Create: `npm/package.json`
- Create: `npm/bin/batterywatt.js`
- Create: `npm/README.md`
- Create: `npm/LICENSE`
- Create: `homebrew/Casks/batterywatt.rb`

**Interfaces:**
- Produces CI on pushes/PRs, tagged release assets, a checksum-verifying explicit npm installer, and a tap cask that points at the official GitHub DMG.

- [ ] **Step 1: Add CI workflow for Swift tests, release build, plist checks, secret scan, and shell syntax.**
- [ ] **Step 2: Add tagged release workflow with optional signing/notarization lanes gated on secrets and artifact checksum generation.**
- [ ] **Step 3: Implement npm helper with `batterywatt install`, `batterywatt uninstall`, and `batterywatt help`; never add `postinstall`.**
- [ ] **Step 4: Use only official GitHub release metadata/assets, verify `SHA256SUMS.txt` before mounting/copying, reject non-macOS or unsupported architecture, and use explicit user commands for side effects.**
- [ ] **Step 5: Run `npm pack --dry-run`, inspect the tarball contents, run `node npm/bin/batterywatt.js help`, and record npm authentication status without exposing tokens.**
- [ ] **Step 6: Add the Homebrew cask with the release URL, exact SHA, app install/uninstall stanza, and tap instructions.**
- [ ] **Step 7: Commit CI and distribution helpers.**

```bash
git add .github npm homebrew
git commit -m "ci: automate releases and distribution helpers"
```

### Task 8: Installed Release QA, Public Publication, And Verification

**Files:**
- Modify: `docs/RELEASING.md` if QA reveals a documentation mismatch
- Modify: `README.md` if public links/media differ from the final release
- Modify: `homebrew/Casks/batterywatt.rb` with the final release SHA

- [ ] **Step 1: Run all local gates before publication.**

Run: `scripts/check.sh && swift test && scripts/release.sh 1.0.0`

Expected: exit 0, zero test failures, release app/DMG/ZIP/checksum present, and ad-hoc signature verifiable.

- [ ] **Step 2: Back up the existing installed app to a reversible path, install the DMG build into `~/Applications` or `/Applications`, and launch it.**
- [ ] **Step 3: Verify Info.plist, no Dock icon, one process, status item behavior, launch/relaunch, login-item enable/disable, and no per-second child process.**
- [ ] **Step 4: Compare raw `ioreg` telemetry to the app's direct-reader diagnostics when an active sample is available; record raw mA, raw mV, calculated W, and displayed W.**
- [ ] **Step 5: Test charging-only, Always, On battery only, Adapter connected, direction/icon/decimal settings, threshold/full behavior, history opt-in, CSV export, diagnostics, and empty/no-battery behavior.**
- [ ] **Step 6: Measure CPU/RAM/network descriptors and sample process behavior for at least 20 refresh cycles; record values without claiming a benchmark beyond this machine.**
- [ ] **Step 7: Run `gitleaks` if installed plus the repository regex scan, inspect tracked files, create `nkhaduy/BatteryWatt` with `gh`, push the meaningful commits, and set description/topics.**
- [ ] **Step 8: Push `v1.0.0`, create the GitHub Release with concise notes and assets, verify download URLs, then create/update `nkhaduy/homebrew-batterywatt` and test the cask if Homebrew permits.**
- [ ] **Step 9: Publish npm only if `npm whoami` succeeds; otherwise leave the package prepared and report `NPM PUBLISH: BLOCKED — authentication required`.**
- [ ] **Step 10: Perform the final stranger audit: README render, links, media size, release asset availability, install instructions, privacy story, source auditability, and no placeholder/TODO text.**
- [ ] **Step 11: Commit any final documentation-only corrections and push them without amending prior commits.**

