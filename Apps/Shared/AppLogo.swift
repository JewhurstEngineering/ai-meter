import SwiftUI

/// Color logo (light/dark variants) or the menu-bar template silhouette.
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
