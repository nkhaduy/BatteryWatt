# Releasing BatteryWatt

BatteryWatt releases are built from the command line and published from a version tag.

## Local release checklist

1. Update `CFBundleShortVersionString` only through the release command's version argument and update `CHANGELOG.md`.
2. Run the full checks and package the artifacts:

   ```sh
   ./scripts/check.sh
   ./scripts/release.sh 1.0.0
   ```

3. Inspect `build/BatteryWatt.app` with `plutil`, `file`, and `codesign --verify --deep --strict`.
4. Mount the DMG, install the app into a disposable Applications location, and test the installed Release build.
5. Confirm `dist/SHA256SUMS.txt` matches the published DMG and ZIP.
6. Tag and push:

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

The tagged GitHub Actions workflow runs the same build, uploads the DMG/ZIP/checksum assets, and generates release notes.

## Signing and notarization

If a Developer ID Application identity is available in the environment, set `CODESIGN_IDENTITY` to its name before building. The script enables hardened runtime and a secure timestamp for that lane. Never put certificates, private keys, or credentials in the repository.

Notarization is intentionally separate from the default build. With a secure `notarytool` keychain profile, submit the final DMG, wait for approval, staple the ticket, and run `spctl --assess --type open --context context:primary-signature`. If no identity or profile is available, label the release ad-hoc signed and not notarized; do not imply otherwise.

## Homebrew tap

After a GitHub release exists, update `nkhaduy/homebrew-batterywatt/Casks/batterywatt.rb` with the release URL and exact SHA-256. Test with:

```sh
brew tap nkhaduy/batterywatt
brew install --cask batterywatt
brew uninstall --cask batterywatt
```

Do not update a cask to an artifact whose checksum has not been verified.

## npm helper

The optional package under `npm/` is published independently only after `npm pack --dry-run`, a package-content review, and `npm whoami` succeed. It must never gain an automatic install or postinstall side effect. Release assets are fetched only from the official GitHub repository and verified against `SHA256SUMS.txt` before installation.

