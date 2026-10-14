// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import BarometryKit
import SwiftUI

/// The menu bar items as they look now, live, on a strip of menu bar over a desktop.
struct MenuBarPreview: View {
    let preferences: Preferences
    let statusItems: StatusItemController

    var body: some View {
        let style = preferences.menuBarStyle
        let visible = preferences.menuBarModules.visible
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                switch preferences.menuBarLayout {
                case .individual:
                    ForEach(statusItems.sortedByMenuBarPosition(visible)) { module in
                        item([module], style: style)
                    }
                case .combined:
                    item(visible, style: style)
                }
            }
            .fixedSize()
            // A crowded menu bar loses items on the left, so overflow clips there too.
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(.bar)
            Spacer(minLength: 18)
        }
        .background(
            LinearGradient(colors: [.indigo, .blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.7)
        )
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(.separator)
        }
        // Mirrors the real menu bar, which VoiceOver already reads.
        .accessibilityHidden(true)
    }

    /// One status item, outlined so separate items read apart from one combined item.
    private func item(_ modules: [MenuBarModule], style: MenuBarStyle) -> some View {
        MenuBarItemView(
            style: style,
            widgets: modules.map { (module: $0, content: statusItems.widgetContent(for: $0, style: style)) },
            foreground: .primary
        )
        .padding(.horizontal, 3)
        .background(.fill.tertiary, in: .rect(cornerRadius: 5))
    }
}
