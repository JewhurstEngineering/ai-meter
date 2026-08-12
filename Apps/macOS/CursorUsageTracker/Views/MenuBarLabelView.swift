import SwiftUI
import CursorUsageCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        let presentation = store.menuBarPresentation
        HStack(spacing: 5) {
            Image(systemName: "circle.hexagongrid.fill")
            if store.preferences.showInMenuBar {
                ForEach(Array(presentation.segments.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 2) {
                        if let icon = segment.systemImage {
                            Image(systemName: icon)
                        }
                        Text(segment.text)
                    }
                }
            }
            if presentation.showWarningDot {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel(presentation.accessibilityTitle)
        .task {
            await store.bootstrap()
        }
    }
}
