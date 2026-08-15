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

/// Wide JamesWare AI Meter wordmark (black in light, white in dark).
struct AppFullLogo: View {
    var height: CGFloat = 24

    var body: some View {
        Image("AppLogoFull")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
            .frame(height: height)
    }
}
