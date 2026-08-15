import Foundation

enum AppAbout {
    static let productName = "AI Meter"
    static let productLegalName = "JamesWare AI Meter"
    static let copyrightHolder = "JAMESWARE.DEV"
    static let organization = "Made with care by JamesWare.dev"
    static var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
    static let licenseName = "MIT"
    static let dashboardURL = URL(string: "https://cursor.com/dashboard")!
    static let billingURL = URL(string: "https://cursor.com/dashboard/billing")!

    static var copyrightLine: String {
        "Copyright © \(copyrightYear) \(copyrightHolder)"
    }
}
