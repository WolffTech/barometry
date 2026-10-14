<!-- SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech> -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Security

## Reporting a vulnerability

Use GitHub's private vulnerability reporting on this repository ("Security"
→ "Report a vulnerability"). Do not open a public issue for anything that
could let another user or a network attacker run code or replace the app.
Expect an acknowledgement within a week.

## What the app trusts

Barometry runs outside the App Sandbox, because reading sensors through the
SMC and IOKit isn't allowed inside it, with the hardened runtime enabled. It
reads system statistics through public macOS APIs, the private
`libIOReport`, and the SMC, and only reads from them. It accepts no network
input apart from Sparkle's update feed.

| Component | Pinned at | Used for | Watch |
| --- | --- | --- | --- |
| Sparkle (prebuilt framework, Swift package) | exact `2.10.0` | in-app updates | https://github.com/sparkle-project/Sparkle/releases, https://github.com/sparkle-project/Sparkle/security |
| dmgbuild (Python package, release builds only) | versions and hashes in `Scripts/dmg/requirements.txt` | building the release disk image | https://github.com/dmgbuild/dmgbuild/releases |

Updates are fetched from the appcast attached to the latest GitHub release and
installed only when the archive's EdDSA signature verifies against the
`SUPublicEDKey` baked into the app, and macOS additionally checks that the new
bundle carries the same Developer ID team. The private key exists in two
places: the release maintainer's login Keychain and the `SPARKLE_ED_PRIVATE_KEY`
repository secret. A compromised key means rotating it (`generate_keys`),
shipping a release with the new public key, and treating every earlier build
as unable to update.

## Updating Sparkle

1. Check the release notes and advisories for the range being crossed.
2. Move `exactVersion` in `project.yml` and `SPARKLE_VERSION`/`SPARKLE_SHA256`
   in `.github/workflows/release.yml`, regenerate the project, and commit the
   refreshed `Package.resolved`.
3. Build and run the tests, then check for updates from an installed copy of
   the previous release once the new one ships.
4. Commit the bump on its own (`build(sparkle): …`) so the history shows
   exactly which version shipped, then cut a release.

If an advisory affects the pinned Sparkle version, ship a release with the
fix before adding anything else, and record the assessment in the release
notes, including "not affected" outcomes so they are not re-investigated.
