# BatteryWatt Public Presentation Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the public BatteryWatt release surface around a real installed-app demo while preserving truthful telemetry, installation, privacy, and signing disclosures.

**Architecture:** Keep the native app and v1.0.0 binary unchanged unless verification finds a material runtime defect. Update only public-facing Markdown, launch copy, derived branding media, and distribution metadata that can be verified from the current release.

**Tech Stack:** SwiftPM/macOS CLI, Markdown, GitHub CLI/API, Homebrew Cask, npm, native image/video tools when available, and shell-based verification.

**Spec:** `docs/superpowers/specs/2026-09-03-batterywatt-public-release-design.md` plus the user's public-release QA brief.

## Global Constraints

- Do not inject fake telemetry, mock a wattage number, or publish an unverified hardware claim.
- Keep battery-side power clearly distinct from wall-adapter or total-system power.
- Keep Homebrew and the official DMG ahead of the optional npm helper.
- Do not publish private desktop content, credentials, absolute local paths, or temporary QA output.
- Keep v1.0.0 when changes are documentation/media/repository presentation only.
- Keep `CODESIGN: AD-HOC` and `NOTARIZATION: BLOCKED` when no Developer ID identity is available.
- Do not claim Intel telemetry is verified without physical Intel evidence.

---

### Task 1: Audit Current Public State And Distribution

**Files:**
- Inspect: `README.md`, `npm/package.json`, `npm/cli.js`, `docs/RELEASING.md`, `assets/batterywatt-social-preview.svg`
- Inspect: `.github/workflows/ci.yml`, `scripts/check.sh`, `scripts/release.sh`
- Modify: `README.md` only where the audit identifies redundant or misplaced user-facing copy

- [x] **Step 1: Record repository, release, Homebrew, npm, signing, and hardware evidence with read-only commands.**
- [x] **Step 2: Test both Homebrew command forms without changing the cask metadata until one resolves to the public v1.0.0 artifact.**
- [x] **Step 3: Run `npm pack --dry-run`, inspect the whitelist, run the packed helper's `help` command, and record `npm whoami` without exposing credentials.**
- [x] **Step 4: Run the local path/secret scan and identify any tracked build artifacts, private paths, or stale public wording.**
- [ ] **Step 5: Write the final evidence into the release report only after commands complete.**

### Task 2: Public README And Launch Copy

**Files:**
- Modify: `README.md`
- Create: `docs/LAUNCH.md`
- Modify: `.github/ISSUE_TEMPLATE/bug_report.yml` only if a sanitized telemetry compatibility path is missing

- [x] **Step 1: Reorder the README first screen to product value, real media when available, install, then technical detail.**
- [x] **Step 2: Keep the charging/discharging battery-side explanation visible in the user section and preserve privacy/signing/Intel honesty.**
- [x] **Step 3: Add only reliable badges and keep the install command near the hero.**
- [x] **Step 4: Add factual launch variants for GitHub, r/macapps, r/mac, Show HN, and one concise social post without auto-posting.**
- [x] **Step 5: Add a contribution path for sanitized hardware compatibility reports without requesting serial numbers.**
- [x] **Step 6: Run Markdown link/path checks and inspect the rendered raw README before committing.**

### Task 3: Derived Branding And Real Demo Media

**Files:**
- Create: `assets/batterywatt-social-preview.png`
- Create: `docs/assets/demo.mp4` only after an installed-app capture with real telemetry
- Create: `docs/assets/demo.gif` or `docs/assets/demo.webp` only after the same real capture
- Create: `docs/assets/hero.png` only from a privacy-reviewed real frame

- [x] **Step 1: Rasterize the existing SVG at exactly 1280x640 and inspect the result for legibility.**
- [x] **Step 2: Attempt a short installed-app capture only when the desktop can be operated without exposing unrelated private content.**
- [x] **Step 3: Verify the capture shows real discharge or charging telemetry and record its raw state, displayed state, and power calculation.**
- [ ] **Step 4: Crop and encode MP4 plus a GitHub-compatible preview under 5 MB without making menu-bar text illegible.**
- [x] **Step 5: If capture is unavailable or interrupted, do not create substitute media; keep the README honest and report the exact gap.**

### Task 4: Verification And Public Handoff

**Files:**
- Modify: `README.md` or `docs/RELEASING.md` only for verified corrections
- Inspect: public GitHub README, release, cask, and package metadata

- [x] **Step 1: Run `scripts/check.sh`, `swift test`, and the complete release/build gate appropriate to the changed files.**
- [x] **Step 2: Verify `Info.plist`, universal binary, ad-hoc signature, checksums, and no Developer ID identity.**
- [x] **Step 3: Verify tracked-file privacy scans, media dimensions/sizes, README references, and package contents.**
- [ ] **Step 4: Push meaningful commits only after fresh verification evidence; never force-push or rewrite v1.0.0.**
- [ ] **Step 5: Inspect the actual public GitHub page after push when public changes were made; report PASS only if the public render and links are verified.**
