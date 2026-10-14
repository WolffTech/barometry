<!-- SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech> -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

<p align="center">
  <img src="Assets/AppIcon.png" width="160" alt="Barometry logo">
</p>

<h1 align="center">Barometry</h1>

<p align="center">
  Live system stats in your Mac's menu bar, with a detailed dashboard a click away.
</p>

Barometry shows CPU, GPU, memory, network, sensor, and battery readings as compact menu bar graphs and gauges. Click any of them to open a dashboard with per-core load, temperatures, power, clocks, and disk usage.

## Features

- Menu bar modules for CPU, GPU, memory, network, sensors, and battery
- One menu bar item per module, or a single combined item in the order you choose
- A dashboard in two styles, an instrument cluster of dials or a list of rows with live trends, with sections you can hide and reorder
- Details beside the dashboard: hover a section to see its history, breakdown, and top processes, or click it to keep them open
- Temperatures in °C or °F, and a choice of network interface
- A refresh interval of 1, 2, or 5 seconds, with 1-second updates while the dashboard is open
- Keep Awake, which stops idle sleep and keeps the display on, marked with a cup on the battery in the menu bar
- Optionally, while Keep Awake is on, an imperceptible cursor nudge after 30 seconds to 4 minutes without input, so apps that check for activity still see some
- Launch at login
- Under 1% CPU while idle

## Installation

Barometry requires an Apple silicon Mac running macOS 26 or later.

### Homebrew

Install Barometry from the [Wolff.Tech Homebrew tap](https://github.com/WolffTech/homebrew-tap):

```sh
brew install --cask wolfftech/tap/barometry
```

### Manual download

1. Download the signed `.dmg` from [GitHub Releases](https://github.com/WolffTech/barometry/releases), or [build from source](#build-from-source).
2. Open the disk image and drag Barometry to `/Applications`.
3. Launch Barometry from `/Applications`. It appears in the menu bar.

### Updates

Barometry uses [Sparkle](https://sparkle-project.org) to check GitHub Releases for updates. Choose **Check for Updates…** in **Settings → Updates**, or turn on automatic checks there.

In-app updates work only after you copy Barometry to `/Applications`. macOS translocates apps launched from a disk image or `~/Downloads`, so Sparkle can't update them in place. Homebrew installs update the same way.

### Getting started

Barometry lives in the menu bar and has no Dock icon. Click a menu bar item to open the dashboard, and hover or click a section to see its details. Choose **Settings…** (⌘,) to pick modules, the layout, and the refresh interval. Quit from the dashboard or with ⌘Q.

Turn on Keep Awake with the cup button in the dashboard's footer, or ⌥-click the battery item. It stays on until you turn it off or quit Barometry.

To have Keep Awake also nudge the cursor when you're idle, turn on **Move cursor when idle** in **Settings → Keep Awake** and allow Barometry in **System Settings → Privacy & Security → Accessibility**, which macOS requires to move the cursor.

In the individual layout, hold ⌘ and drag menu bar items to rearrange them.

## Build from source

Install Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
brew install xcodegen
git clone https://github.com/WolffTech/barometry.git
cd barometry
xcodegen generate
open Barometry.xcodeproj
```

The Xcode project is generated from `project.yml` and isn't checked in. Regenerate it after pulling or after adding, removing, or renaming files.

To build from the command line:

```sh
xcodebuild -project Barometry.xcodeproj -scheme Barometry -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Barometry.app
```

Logic lives in the `BarometryKit` package and is tested with Swift Testing. Run the tests with ⌘U in Xcode, or:

```sh
swift test --package-path Packages/BarometryKit
```

Forks that distribute their own builds must replace `SUFeedURL` and `SUPublicEDKey` in `App/Info.plist`. Otherwise, those builds will check Barometry's official update feed and trust its release signatures.

## Releasing

Push a `vX.Y.Z` tag. The [Release workflow](.github/workflows/release.yml) runs the tests, then `Scripts/release.sh` archives Barometry, signs it with Developer ID, notarizes and staples both the app and the disk image, and publishes the DMG, its checksum, and a signed Sparkle `appcast.xml` to a GitHub release. The build number is the commit count at the tag. Publish every tag as a full release, not a pre-release, because the app's update feed reads the latest release.

The workflow needs these repository secrets: `MACOS_CERT_P12` and `MACOS_CERT_PASSWORD` (Developer ID Application certificate), `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID` (App Store Connect API key), and `SPARKLE_ED_PRIVATE_KEY` (exported with Sparkle's `generate_keys --account barometry -x`).

To check signing locally without submitting to Apple:

```sh
SKIP_NOTARIZE=1 Scripts/release.sh 1.0.0
```

## License

Barometry is free software licensed under [GPL-3.0-only](LICENSE). Third-party attributions are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and details about the corresponding source for each release are in [SOURCE.md](SOURCE.md). [PRIVACY.md](PRIVACY.md) describes what Barometry stores and sends, and [SECURITY.md](SECURITY.md) explains how to report a vulnerability.
