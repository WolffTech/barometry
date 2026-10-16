// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

struct KeepAwakePane: View {
    @Bindable var preferences: Preferences

    @State private var canNudgeCursor = CursorNudge.isAllowed

    var body: some View {
        Form {
            Section {
                Toggle("Move cursor when idle", isOn: movesCursorWhenIdle)
                Picker("After", selection: $preferences.cursorNudgeInterval) {
                    ForEach(CursorNudgeInterval.allCases) { interval in
                        Text(interval.rawValue < 60 ? "\(interval.rawValue) s" : "\(interval.rawValue / 60) min").tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!preferences.movesCursorWhenIdle)
                if preferences.movesCursorWhenIdle, !canNudgeCursor {
                    LabeledContent("Allow Barometry in Accessibility to move the cursor.") {
                        Button("Open Accessibility") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                    .font(.callout)
                }
            } footer: {
                Text("Turn on Keep Awake with the cup in the dashboard, or ⌥-click any Barometry item in the menu bar. While it's on, Barometry moves the cursor a point and back after this long without input, so apps that check for activity still see some.")
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
        // Accessibility approval can change while the window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            canNudgeCursor = CursorNudge.isAllowed
        }
    }

    /// Turning it on asks for Accessibility permission, which macOS needs to post the movement.
    private var movesCursorWhenIdle: Binding<Bool> {
        Binding {
            preferences.movesCursorWhenIdle
        } set: { isOn in
            preferences.movesCursorWhenIdle = isOn
            if isOn {
                canNudgeCursor = CursorNudge.requestAccess()
            }
        }
    }
}
