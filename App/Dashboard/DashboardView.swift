import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Barometry")
                .font(.headline)
            Text("System stats will appear here.")
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Spacer()
                Button("Quit Barometry") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    DashboardView()
}
