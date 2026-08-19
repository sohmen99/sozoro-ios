import XCTest
@testable import SozoroCore

/// 印は全部取れるか。気分の数を変えたときに、条件だけ取り残されるのを防ぐ。
/// みどりを外したあと「三つの気分」が永久に埋まらない印として残っていた。
final class RewardTests: XCTestCase {
    func testEveryRewardIsReachable() {
        let kinds = Set(SozoroData.shared.spots.map(\.kind)).count
        var best = WalkStats([])
        best.count = 99; best.totalM = 9e9; best.maxM = 9e9
        best.maxDispersion = 99; best.totalDispersion = 9999
        best.outside = 9; best.noHint = 9; best.dawn = 9; best.dusk = 9
        best.areas = 9; best.kinds = kinds; best.days = 9
        let stuck = Reward.all.filter { !$0.test(best) }.map(\.id)
        XCTAssertTrue(stuck.isEmpty, "やり込んでも取れない印: \(stuck)（気分は\(kinds)種）")
    }
}
