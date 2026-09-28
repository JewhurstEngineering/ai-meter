import SwiftUI

/// Color square mark, or the menu-bar template silhouette.
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
