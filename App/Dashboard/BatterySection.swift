import BarometryKit
import SwiftUI

struct BatterySection: View {
    let battery: BatterySample

    var body: some View {
        DashboardCard {
            CardHeader(title: "Battery", detail: "\(battery.charge.formatted()) · \(state)")
            ProgressBar(fraction: battery.charge.fraction)
        }
    }

    private var state: String {
        switch battery.state {
        case .charging(let timeToFull):
            timeToFull.map { "Full in \($0.formatted(.time(pattern: .hourMinute)))" } ?? "Charging"
        case .charged:
            "Charged"
        case .notCharging:
            "Not charging"
        case .discharging(let timeRemaining):
            timeRemaining.map { "\($0.formatted(.time(pattern: .hourMinute))) left" } ?? "On battery"
        }
    }
}
