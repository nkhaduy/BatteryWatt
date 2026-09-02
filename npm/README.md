# batterywatt

An explicit CLI installer for the native [BatteryWatt](https://github.com/nkhaduy/BatteryWatt) macOS app.

```sh
npx batterywatt install
npx batterywatt uninstall
```

The helper supports Apple Silicon and Intel macOS, downloads only official GitHub Release DMGs, verifies the release checksum before copying anything, and installs to `~/Applications`. It has no dependencies, no analytics, no network use after installation, and no `postinstall` script.

Homebrew and the official DMG remain the recommended installation paths.

