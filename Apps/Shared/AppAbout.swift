import Foundation

enum AppAbout {
    static let copyrightHolder = "jamesware.dev"
    static let organization = "Made with care, by JamesWare"
    static var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
    static let licenseName = "MIT"
    static let dashboardURL = URL(string: "https://cursor.com/dashboard")!

    static var copyrightLine: String {
        "Copyright © \(copyrightYear) \(copyrightHolder)"
    }
}
