# Contributing to BatteryWatt

Thanks for helping keep BatteryWatt small, native, and trustworthy.

## Before opening a pull request

- Search existing issues before filing a duplicate.
- Keep changes focused on battery power and the native macOS experience.
- Do not add analytics, tracking, cloud sync, accounts, or a network dependency for normal operation.
- Do not include battery logs, screenshots, paths, serial numbers, or diagnostics containing personal data.
- Add or update tests for core behavior changes.

## Local checks

```sh
swift test
./scripts/check.sh
```

For packaging work:

```sh
./scripts/build.sh 1.0.0
./scripts/package-dmg.sh 1.0.0
```

## Pull requests

Explain the user-visible behavior, the telemetry assumptions, and how you tested it. If a change affects power calculation or state detection, include a small sanitized fixture or a focused core test.

Please do not commit `build/`, `dist/`, `.build/`, credentials, signing identities, or generated personal data.

