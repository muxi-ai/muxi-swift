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

    func testParseUiWidgetsDecodesUiFrame() {
        let event = SseEvent(
            event: "ui",
            data: #"{"ui":[{"type":"options","id":"w1","prompt":"Which?","options":[{"value":"us","label":"United States"}]},{"type":"action_link","id":"w2","label":"Dash","url":"https://x.io"}]}"#
        )

        let widgets = parseUiWidgets(event)

        XCTAssertEqual(widgets.count, 2)
        XCTAssertEqual(widgets[0]["type"] as? String, "options")
        let options = widgets[0]["options"] as? [[String: Any]]
        XCTAssertEqual(options?.first?["label"] as? String, "United States")
        XCTAssertEqual(widgets[1]["url"] as? String, "https://x.io")
    }

    func testParseUiWidgetsIgnoresOtherFrames() {
        XCTAssertTrue(parseUiWidgets(SseEvent(event: "message", data: "hi")).isEmpty)
        XCTAssertTrue(parseUiWidgets(SseEvent(event: "ui", data: "not json")).isEmpty)
        XCTAssertTrue(parseUiWidgets(SseEvent(event: "ui", data: #"{"ui":{}}"#)).isEmpty)
    }

    func testUnwrapEnvelopeSurfacesIdempotencyKey() {
        let transport = FormationTransport(baseUrl: "http://example.com", adminKey: "admin-key", clientKey: "client-key", timeout: 30, maxRetries: 0, debug: false)
        let env: [String: Any] = [
            "object": "api_response",
            "timestamp": 123,
            "request": ["id": "req-1", "idempotency_key": "idem-42"],
            "data": ["foo": "bar"],
            "success": true,
        ]

        let out = transport.unwrapEnvelope(env)

        XCTAssertEqual(out?["foo"] as? String, "bar")
        XCTAssertEqual(out?["request_id"] as? String, "req-1")
        XCTAssertEqual(out?["idempotency_key"] as? String, "idem-42")
    }

    func testUnwrapEnvelopeOmitsIdempotencyKeyWhenAbsent() {
        let transport = FormationTransport(baseUrl: "http://example.com", adminKey: "admin-key", clientKey: "client-key", timeout: 30, maxRetries: 0, debug: false)
        let env: [String: Any] = [
            "object": "api_response",
            "request": ["id": "req-1"],
            "data": ["foo": "bar"],
            "success": true,
        ]

        let out = transport.unwrapEnvelope(env)

        XCTAssertNil(out?["idempotency_key"])
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
