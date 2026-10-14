<!-- SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech> -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Privacy

Barometry is a macOS menu bar app that shows live system statistics. It is
made by Wolff.Tech.

## What the app reads

Barometry reads CPU, GPU, memory, disk, network, sensor, and battery
statistics from macOS, and the names and resource usage of running processes
for the dashboard's top-process lists. These readings stay in memory for the
graphs and history and are never written to disk or sent anywhere.

## What the app controls

If you turn on **Move cursor when idle**, Barometry asks for the Accessibility
permission and uses it only to move the cursor one point and back while Keep
Awake is on and you've been idle. It doesn't read your keystrokes, mouse
movements, or screen.

## What the app stores on your Mac

- Menu bar, dashboard, refresh, temperature unit, network interface, and
  cursor nudge settings, and Sparkle's update settings, in the
  `tech.wolff.barometry` preferences.
- The login item, if you turn on **Launch at login**, registered with macOS.

## What leaves your Mac

- Update checks. Barometry uses Sparkle to fetch its update feed and update
  downloads from the project's GitHub releases. Sparkle asks once whether to
  check automatically; change that answer or check now in **Settings →
  Updates**. GitHub sees your IP address and the app version in the request. No
  other system information is sent.

Barometry has no accounts, no analytics, no telemetry and no crash
reporting, and contacts no server of its own.

## Removing your data

Turn off **Launch at login**, remove Barometry from **Accessibility** if you
allowed it, quit Barometry, then delete the app, the
`~/Library/Caches/tech.wolff.barometry` and
`~/Library/HTTPStorages/tech.wolff.barometry` folders that Sparkle uses, and
the `tech.wolff.barometry` preferences:

```sh
defaults delete tech.wolff.barometry
```

## Contact

Questions about this policy: open an issue on the project's GitHub
repository.
