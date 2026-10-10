# Barometry

A macOS menu bar app that shows live system stats, with a detailed dashboard on click. Apple Silicon, macOS 26+.

## Requirements

- Xcode 27 (selected with `xcode-select`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

The Xcode project is generated from `project.yml` and isn't checked in. Regenerate it after pulling or after adding, removing, or renaming files.

```zsh
xcodegen generate
open Barometry.xcodeproj
```

From the command line:

```zsh
xcodebuild -project Barometry.xcodeproj -scheme Barometry -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Barometry.app
```

Barometry has no Dock icon. Quit it from the dashboard or with ⌘Q while the dashboard is open.

## Test

Logic lives in the `BarometryKit` package and is tested with Swift Testing:

```zsh
swift test --package-path Packages/BarometryKit
```

The `Barometry` scheme also runs these tests (⌘U in Xcode).

## Layout

- `App/`: the app target: status item, dashboard panel, SwiftUI views.
- `Packages/BarometryKit/`: samplers, models, and other logic with no UI dependency.
- `project.yml`: XcodeGen project spec.
