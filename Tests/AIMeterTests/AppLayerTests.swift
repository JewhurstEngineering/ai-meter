import XCTest
@testable import AIMeter
import AIMeterCore

final class SparklePlistTests: XCTestCase {
    func testFeedURLPointsAtGitHubLatestAppcast() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        XCTAssertEqual(
            url,
            "https://github.com/JewhurstEngineering/ai-meter/releases/latest/download/appcast.xml"
        )
    }

    func testPublicKeyIsPresent() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        XCTAssertEqual(key, "qijKx335WMhnQRru81bLR+sN8uoaHJ0SjzwaFP1Lg7M=")
    }

    func testAutomaticUpdateChecksAreEnabled() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool, true)
    }
}

final class AppAboutTests: XCTestCase {
    func testProductCopy() {
        XCTAssertEqual(AppAbout.productName, "AI Meter")
        XCTAssertEqual(AppAbout.productLegalName, "JamesWare AI Meter")
        XCTAssertEqual(AppAbout.licenseName, "MIT")
        XCTAssertTrue(AppAbout.copyrightLine.contains(AppAbout.copyrightHolder))
    }

    func testPublicURLs() {
        XCTAssertEqual(AppAbout.dashboardURL.absoluteString, "https://cursor.com/dashboard")
        XCTAssertEqual(AppAbout.billingURL.absoluteString, "https://cursor.com/dashboard/billing")
        XCTAssertEqual(
            AppAbout.releasesURL.absoluteString,
            "https://github.com/JewhurstEngineering/ai-meter/releases/latest"
        )
    }

    func testAffiliationDisclaimerNamesVendors() {
        let text = AppAbout.affiliationDisclaimer
        XCTAssertTrue(text.contains("not affiliated"))
        XCTAssertTrue(text.contains("Anysphere"))
        XCTAssertTrue(text.contains("Cursor"))
        XCTAssertTrue(text.contains("Anthropic"))
        XCTAssertTrue(text.contains("OpenAI"))
    }
}

final class AppInstallTests: XCTestCase {
    func testApplicationsPathDetection() {
        XCTAssertTrue(AppInstall.isApplicationsPath("/Applications/AI Meter.app"))
        XCTAssertTrue(AppInstall.isApplicationsPath("/Applications/Utilities/Something.app"))
        XCTAssertFalse(AppInstall.isApplicationsPath("/Users/you/Downloads/AI Meter.app"))
        XCTAssertFalse(AppInstall.isApplicationsPath("/tmp/AI Meter.app"))
    }

    func testInstalledAppURLIsUnderApplications() {
        XCTAssertEqual(AppInstall.installedAppURL.lastPathComponent, "AI Meter.app")
        XCTAssertTrue(AppInstall.isApplicationsPath(AppInstall.installedAppURL.path))
    }
}

final class WidgetSnapshotFileTests: XCTestCase {
    func testStoreConstants() {
        XCTAssertEqual(WidgetSnapshotStore.filename, "widget-snapshot.json")
        XCTAssertEqual(WidgetSnapshotStore.appGroupID, "6998422DKP.com.jamesware.aimeter.shared")
        XCTAssertEqual(WidgetSnapshotStore.legacyAppGroupID, "group.com.jamesware.aimeter.shared")
        XCTAssertEqual(WidgetSnapshotStore.watchAppGroupID, "group.com.jamesware.aimeter.watch")
    }

    func testTempDirectoryRoundTrip() throws {
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            otherModelsPercentUsed: 22,
            planUsedCents: 900,
            planLimitCents: 2000
        )
        let widget = WidgetSnapshot(from: snap, warnings: .default)
        let data = try WidgetSnapshotStore.data(from: widget)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIMeter-tests-\(UUID().uuidString)")
            .appendingPathComponent(WidgetSnapshotStore.filename)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try data.write(to: url)
        let loaded = try Data(contentsOf: url)
        XCTAssertEqual(WidgetSnapshotStore.snapshot(from: loaded)?.planDisplayName, "Pro")
        XCTAssertEqual(WidgetSnapshotStore.snapshot(from: loaded)?.planUsedCents, 900)
    }
}
