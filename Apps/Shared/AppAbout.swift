import Foundation

enum AppAbout {
    static let productName = "AI Meter"
    static let productLegalName = "JamesWare AI Meter"
    static let copyrightHolder = "JAMESWARE.DEV"
    static let organization = "JamesWare.dev"
    static var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
    static let licenseName = "MIT"
    static let dashboardURL = URL(string: "https://cursor.com/dashboard")!
    static let billingURL = URL(string: "https://cursor.com/dashboard/billing")!
    static let releasesURL = URL(string: "https://github.com/JewhurstEngineering/ai-meter/releases/latest")!
    static let affiliationDisclaimer =
        "JamesWare AI Meter is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Anysphere, Cursor, Anthropic, or OpenAI."

    static var copyrightLine: String {
        "Copyright © \(copyrightYear) \(copyrightHolder)"
    }
}
