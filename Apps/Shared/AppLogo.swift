import SwiftUI

/// Color square mark, menu-bar template silhouette, or full wordmark.
struct AppLogo: View {
    var size: CGFloat = 34
    var template: Bool = false

    var body: some View {
        let image = Image(template ? "AppLogoTemplate" : "AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
        return image
            .frame(width: size, height: size)
    }
}

/// Wide JamesWare AI Meter wordmark. Color, or black/white by appearance.
struct AppFullLogo: View {
    var height: CGFloat = 24
    var color: Bool = false

    var body: some View {
        Image(color ? "AppLogoFullColor" : "AppLogoFull")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
            .frame(height: height)
    }
}

/// Name-only “AI Meter” wordmark (black in light, white in dark).
struct AppNameLogo: View {
    var height: CGFloat = 18

    var body: some View {
        Image("AppLogoName")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
            .frame(maxHeight: height)
    }
}
