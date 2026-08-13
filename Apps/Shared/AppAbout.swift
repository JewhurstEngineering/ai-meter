enum AppAbout {
    static let copyrightHolder = "James Jewhurst"
    static let organization = "Jewhurst Engineering"
    static let copyrightYear = "2026"
    static let licenseName = "MIT"

    static var copyrightLine: String {
        "Copyright © \(copyrightYear) \(copyrightHolder)"
    }
}
