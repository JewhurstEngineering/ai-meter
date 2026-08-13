import SwiftUI
import CursorUsageCore

struct SettingsRootView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            LayoutSettingsView()
                .tabItem { Label("Layout", systemImage: "rectangle.split.2x1") }
            ThemeSettingsView()
                .tabItem { Label("Theme", systemImage: "paintpalette") }
            AccessibilitySettingsView()
                .tabItem { Label("Accessibility", systemImage: "accessibility") }
            AuthenticationSettingsView()
                .tabItem { Label("Authentication", systemImage: "lock") }
            IncludedUsageSettingsView()
                .tabItem { Label("Included Usage", systemImage: "chart.bar") }
            PaidUsageSettingsView()
                .tabItem { Label("Paid Usage", systemImage: "creditcard") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appLayoutScale(store.preferences.interfaceSize.scale)
        .frame(
            minWidth: 800,
            idealWidth: 960 * store.preferences.interfaceSize.scale,
            maxWidth: .infinity,
            minHeight: 520,
            idealHeight: 680 * store.preferences.interfaceSize.scale,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(SettingsResizeUnlock())
        .environmentObject(store)
        .appThemed(store.preferences)
        .onAppear {
            AppActivation.scheduleSettingsFocus()
            WindowAppearanceApplier.apply(store.preferences.appearanceMode.nsAppearance)
            WindowAppearanceApplier.configureChrome(scale: store.preferences.interfaceSize.scale)
        }
        .onChange(of: store.preferences.appearanceMode) { _, mode in
            WindowAppearanceApplier.apply(mode.nsAppearance)
        }
        .onChange(of: store.preferences.interfaceSize) { _, size in
            WindowAppearanceApplier.configureChrome(scale: size.scale)
        }
    }
}
