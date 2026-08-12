import SwiftUI
import CursorUsageCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        let presentation = store.menuBarPresentation
        HStack(spacing: 4) {
            Image(systemName: "circle.hexagongrid.fill")
            if store.preferences.showInMenuBar {
                Text(presentation.title)
            }
            if presentation.showWarningDot {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }
        }
        .task {
            await store.bootstrap()
        }
    }
}
