import SwiftUI
import CursorUsageCore

struct PhoneSettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    NavigationLink {
                        PhoneGeneralSettings()
                    } label: {
                        Label("General & alerts", systemImage: "bell.badge")
                    }
                    NavigationLink {
                        PhoneLayoutSettings()
                    } label: {
                        Label("Layout", systemImage: "rectangle.split.2x1")
                    }
                    NavigationLink {
                        PhoneIncludedSettings()
                    } label: {
                        Label("Included usage", systemImage: "chart.bar")
                    }
                    NavigationLink {
                        PhonePaidSettings()
                    } label: {
                        Label("Paid usage", systemImage: "creditcard")
                    }
                }

                Section("Look") {
                    NavigationLink {
                        PhoneThemeSettings()
                    } label: {
                        Label("Theme", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        PhoneAccessibilitySettings()
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                }

                Section("App") {
                    NavigationLink {
                        PhoneAboutSettings()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    LabeledContent("Watch") {
                        Text("Snapshot only")
                            .foregroundStyle(.secondary)
                    }
                    Text("The paired Apple Watch only receives a sanitized usage snapshot. Session tokens never leave this iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
