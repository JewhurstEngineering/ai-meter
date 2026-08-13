import SwiftUI

/// Color logo (light/dark variants) or the menu-bar template silhouette.
struct AppLogo: View {
    var size: CGFloat = 34
    var template: Bool = false
    /// Square logo that matches the height of neighboring content.
    var fillHeight: Bool = false

    var body: some View {
        let image = Image(template ? "AppLogoTemplate" : "AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
        if fillHeight {
            image
                .frame(maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
        } else {
            image
                .frame(width: size, height: size)
        }
    }
}
