import SwiftUI
import UIKit
import XCTest
import AIMeterCore
@testable import AIMeteriOS

@MainActor
final class RootTabSmokeTests: XCTestCase {
    func testBundleIdentity() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.jamesware.aimeter.ios")
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            "AI Meter"
        )
    }

    func testRootTabsAreOverviewAccountsSettings() {
        XCTAssertEqual(
            PhoneRootTab.allCases.map(\.rawValue),
            ["Overview", "Accounts", "Settings"]
        )
    }

    func testRootTabViewLoads() {
        let store = UsageStore()
        let host = UIHostingController(
            rootView: RootTabView()
                .environmentObject(store)
                .appThemed(store.preferences)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        XCTAssertNotNil(host.view)
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }
}
