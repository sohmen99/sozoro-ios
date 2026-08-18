import XCTest
@testable import SozoroCore

/// 基準地点のアイコンが束の中にあるか。名前を変えたときに白丸になるのを防ぐ。
final class IconTests: XCTestCase {
    func testEveryLandmarkIconExists() {
        let have = Set(IconShape.all.keys)
        let missing = Set(Landmark.all.map(\.icon)).subtracting(have).sorted()
        XCTAssertTrue(missing.isEmpty, "アイコンが無い: \(missing)")
    }
}
