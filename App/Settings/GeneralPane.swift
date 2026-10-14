// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import ServiceManagement
import SwiftUI

struct GeneralPane: View {
    @Bindable var preferences: Preferences

    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var loginItemError: String?
    @State private var interfaces = NetworkInterfaces.available()

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLogin)
                if loginItemStatus == .requiresApproval {
                    LabeledContent("Allow Barometry in Login Items to finish.") {
                        Button("Open Login Items") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                    .font(.callout)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Picker("Refresh every", selection: $preferences.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text("\(interval.rawValue) s").tag(interval)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Temperature", selection: $preferences.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Network interface", selection: $preferences.networkInterface) {
                    Text("Automatic").tag(NetworkInterfaceChoice.automatic)
                    Divider()
                    ForEach(interfaceOptions, id: \.choice) { option in
                        Text(option.label).tag(option.choice)
                    }
                }
            } header: {
                Text("Readings")
            } footer: {
                Text("Barometry refreshes every second while the dashboard is open. Automatic follows the interface your Mac uses for internet traffic.")
                    .foregroundStyle(.secondary)
            }
        }
        .settingsPane()
        // Login item approval and network hardware can change while the window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItemStatus = SMAppService.mainApp.status
            interfaces = NetworkInterfaces.available()
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding {
            loginItemStatus == .enabled || loginItemStatus == .requiresApproval
        } set: { isEnabled in
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                loginItemError = nil
            } catch {
                loginItemError = error.localizedDescription
            }
            loginItemStatus = SMAppService.mainApp.status
        }
    }

    /// Available interfaces, plus the chosen one if it's currently missing, such as an
    /// unplugged dock.
    private var interfaceOptions: [(choice: NetworkInterfaceChoice, label: String)] {
        var options = interfaces.map { (choice: NetworkInterfaceChoice.named($0.bsdName), label: "\($0.displayName) (\($0.bsdName))") }
        if case .named(let name) = preferences.networkInterface, !interfaces.contains(where: { $0.bsdName == name }) {
            options.append((choice: .named(name), label: "\(name) (unavailable)"))
        }
        return options
    }
}
