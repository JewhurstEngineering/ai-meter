import SwiftUI

/// Opens the Settings scene the SwiftUI-approved way, then brings it forward
/// (needed for LSUIElement / menu bar apps).
struct SettingsOpenLink<Label: View>: View {
    @ViewBuilder var label: () -> Label

    var body: some View {
        SettingsLink(label: label)
            .simultaneousGesture(
                TapGesture().onEnded {
                    AppActivation.scheduleSettingsFocus()
                }
            )
    }
}
