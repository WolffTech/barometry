// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct UpdatesPane: View {
    @Bindable var updates: UpdateController

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: "\(updates.version) (\(updates.build))")
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecksForUpdates)
                Toggle("Download updates automatically", isOn: $updates.automaticallyDownloadsUpdates)
                    .disabled(!updates.automaticallyChecksForUpdates)
                HStack {
                    Link("View Releases on GitHub", destination: URL(string: "https://github.com/WolffTech/barometry/releases")!)
                    Spacer()
                    Button("Check for Updates…") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                }
            } footer: {
                Text("Updates are downloaded from GitHub Releases and verified before they're installed.")
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
        // Sparkle's first-launch prompt can change these behind the view.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updates.refresh()
        }
    }
}
