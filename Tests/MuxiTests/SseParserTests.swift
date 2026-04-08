import XCTest
@testable import Muxi

final class SseParserTests: XCTestCase {
    func testFlushesEventOnlyDoneFrame() throws {
        var parser = SseEventParser()

        XCTAssertNil(try parser.process(line: ": keepalive"))
        XCTAssertNil(try parser.process(line: ""))
        XCTAssertNil(try parser.process(line: "event: done"))

        let event = try parser.process(line: "")
        XCTAssertEqual(event?.event, "done")
        XCTAssertEqual(event?.data, "")
    }

    func testPreservesMultilineData() throws {
        var parser = SseEventParser()

        XCTAssertNil(try parser.process(line: "event: planning"))
        XCTAssertNil(try parser.process(line: "data: one"))
        XCTAssertNil(try parser.process(line: "data: two"))

        let event = try parser.process(line: "")
        XCTAssertEqual(event?.event, "planning")
        XCTAssertEqual(event?.data, "one\ntwo")
    }

    func testRouteLevelErrorThrowsMuxiError() {
        var parser = SseEventParser()

        _ = try? parser.process(line: "event: error")
        _ = try? parser.process(line: #"data: {"error":"boom","type":"RUNTIME_ERROR"}"#)

        XCTAssertThrowsError(try parser.process(line: "")) { error in
            guard case let MuxiError.unknown(code, message, statusCode, _) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(code, "RUNTIME_ERROR")
            XCTAssertEqual(message, "boom")
            XCTAssertEqual(statusCode, 0)
        }
    }
}
