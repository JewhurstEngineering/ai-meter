import SwiftUI
import AIMeterCore

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        let presentation = store.menuBarPresentation
        // MenuBarExtra clips multi-item HStacks unless the label requests its intrinsic width.
        HStack(spacing: 3) {
            AppLogo(size: 13, template: true)
            if store.preferences.showInMenuBar {
                ForEach(Array(presentation.segments.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text("·")
                            .opacity(0.7)
                    }
                    HStack(spacing: 1) {
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
                    .accessibilityLabel("Warning")
            }
        }
        .fixedSize()
        .help(presentation.accessibilityTitle)
        .accessibilityLabel(presentation.accessibilityTitle)
        .task {
            await store.bootstrap()
        }
    }
}
