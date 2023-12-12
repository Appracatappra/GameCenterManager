import XCTest
@testable import GameCenterManager

final class GameCenterManagerTests: XCTestCase {
    func testGameCenterManager() throws {
        XCTAssert(GameCenterManager.shared.isGameCenterEnabled == false)
    }
}
