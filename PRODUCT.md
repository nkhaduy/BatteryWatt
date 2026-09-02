# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS (native AppKit)

## Users

MacBook users who want a quick, trustworthy view of battery-side charging or discharging power, plus developers and power users who want a small auditable utility.

## Product Purpose

BatteryWatt shows real-time power flowing into or out of a MacBook battery in the menu bar. It should be useful every day, disappear when it has no meaningful reading, and remain small enough to trust and leave running.

## Positioning

BatteryWatt focuses on battery power rather than becoming a general system monitor. It uses on-device AppleSmartBattery telemetry, native AppKit controls, and no network service or account.

## Operating Context

BatteryWatt runs as a menu-bar-only utility beside other native macOS status items. Users may keep it in charging-only mode, enable unplugged readings, inspect optional local history, export CSV data, or copy sanitized diagnostics for support.

## Capabilities and Constraints

- Four menu-bar visibility modes: Charging only, Always, On battery only, and Adapter connected.
- Charging and discharging power are calculated from voltage and instantaneous battery current.
- Direction, icon, decimal, spacing, refresh, full-battery, and low-reading preferences are native and persistent.
- Optional history is local-only, bounded, batched, and disabled by default for conservative resource and privacy behavior.
- The app has no analytics, accounts, cloud sync, telemetry upload, ads, or server dependency.
- The primary telemetry path is public IOKit access to the AppleSmartBattery registry; missing battery telemetry is a normal unsupported state.
- The app must not become a CPU, GPU, RAM, disk, network, fan, or general system monitor.
- Apple Silicon is the primary target. Intel support is included only if the same direct telemetry path verifies cleanly.

## Brand Commitments

BatteryWatt is native, minimal, technical, calm, and transparent. It uses template SF Symbols in the menu bar, semantic macOS colors, and a simple battery/bolt visual mark. It must feel at home beside native utilities without implying affiliation with them.

## Evidence on Hand

- Existing native Swift/AppKit/IOKit implementation in `Sources/`.
- Existing direct AppleSmartBattery read path and working ad-hoc arm64 app.
- Current machine reports no active charge at audit time, so live charging screenshots require a safe active charging state.
- No user-supplied testimonials, performance claims, or external product metrics are available; public materials must not invent them.

## Product Principles

1. Show battery-side truth, and explain its limits.
2. Stay focused on one useful number and its context.
3. Keep all data on the Mac and make that easy to verify.
4. Prefer native affordances and small auditable dependencies.
5. Make installation, removal, and release verification straightforward.

## Accessibility & Inclusion

Status items, menus, settings controls, history views, and diagnostics actions use native AppKit semantics, useful VoiceOver labels, keyboard-accessible controls where AppKit permits, and semantic colors that work in both light and dark appearances.
