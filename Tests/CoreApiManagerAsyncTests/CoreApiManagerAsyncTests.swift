import XCTest
@testable import CoreApiManagerAsync

final class CoreApiManagerAsyncTests: XCTestCase {
    func testInit() {
        let api = CoreApiManagerAsync()
        XCTAssertNotNil(api)
    }
}
