import BarometryKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences

    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var loginItemError: String?
    @State private var interfaces = NetworkInterfaces.available()

    var body: some View {
        Form {
            general
            menuBar
            Section("Network") {
                Picker("Interface", selection: $preferences.networkInterface) {
                    Text("Automatic").tag(NetworkInterfaceChoice.automatic)
                    Divider()
                    ForEach(interfaceOptions, id: \.choice) { option in
                        Text(option.label).tag(option.choice)
                    }
                }
            }
            Section("Dashboard") {
                Picker("Style", selection: $preferences.dashboardStyle) {
                    Text("Instrument Cluster").tag(DashboardStyle.cluster)
                    Text("Glance").tag(DashboardStyle.glance)
                }
                .pickerStyle(.segmented)
                ForEach(DashboardSection.allCases) { section in
                    Toggle(section.name, isOn: dashboardSectionBinding(section))
                }
            }
        }
        .formStyle(.grouped)
        // Taller than this scrolls, so the window fits a 14" screen.
        .frame(width: 440, height: 640)
        // Login item approval and network hardware can change while the window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItemStatus = SMAppService.mainApp.status
            interfaces = NetworkInterfaces.available()
        }
    }

    private var general: some View {
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
        } header: {
            Text("General")
        } footer: {
            Text("Barometry refreshes every second while the dashboard is open.")
                .foregroundStyle(.secondary)
        }
    }

    private var menuBar: some View {
        Section {
            Picker("Layout", selection: $preferences.menuBarLayout) {
                Text("Individual").tag(MenuBarLayout.individual)
                Text("Combined").tag(MenuBarLayout.combined)
            }
            .pickerStyle(.segmented)
            Picker("Style", selection: $preferences.menuBarStyle) {
                Text("Graphs").tag(MenuBarStyle.graphical)
                Text("Text").tag(MenuBarStyle.text)
            }
            .pickerStyle(.segmented)
            ForEach(preferences.menuBarModules.order) { module in
                moduleRow(module)
            }
        } header: {
            Text("Menu Bar")
        } footer: {
            Group {
                switch preferences.menuBarLayout {
                case .individual: Text("Each module gets its own item. Hold ⌘ and drag items to rearrange them.")
                case .combined: Text("One item shows the modules in this order.")
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func moduleRow(_ module: MenuBarModule) -> some View {
        let selection = preferences.menuBarModules
        return LabeledContent {
            HStack(spacing: 12) {
                // Order only applies to the combined item; individual items are ⌘-dragged.
                if preferences.menuBarLayout == .combined {
                    Button("Move Up", systemImage: "chevron.up") {
                        preferences.menuBarModules.move(module, by: -1)
                    }
                    .disabled(selection.order.first == module)
                    Button("Move Down", systemImage: "chevron.down") {
                        preferences.menuBarModules.move(module, by: 1)
                    }
                    .disabled(selection.order.last == module)
                }
                Toggle(module.name, isOn: Binding {
                    selection.isVisible(module)
                } set: { isVisible in
                    preferences.menuBarModules.setVisible(isVisible, for: module)
                })
                // The last visible module stays so there's always an item to click.
                .disabled(selection.visible == [module])
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
        } label: {
            Text(module.name)
            if !selection.isAvailable(module) {
                Text("Not available on this Mac")
            }
        }
        .disabled(!selection.isAvailable(module))
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

    private func dashboardSectionBinding(_ section: DashboardSection) -> Binding<Bool> {
        Binding {
            !preferences.hiddenDashboardSections.contains(section)
        } set: { isVisible in
            if isVisible {
                preferences.hiddenDashboardSections.remove(section)
            } else {
                preferences.hiddenDashboardSections.insert(section)
            }
        }
    }
}
