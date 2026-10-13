import XCTest
@testable import CHANGEME

final class AppTests: XCTestCase {
    // Replace with real tests for the app's core logic (TDD: write these first).

    func testVersionTextShowsPublicVersionAndBuild() {
        let info = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "42"]
        XCTAssertEqual(versionText(info), "Version 1.2.0 (42)")
    }
}
