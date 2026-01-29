import XCTest
import CryptoKit
@testable import Muxi

final class WebhookTests: XCTestCase {
    let secret = "test_webhook_secret"
    let payload = #"{"id":"req123","status":"completed","response":[{"type":"text","text":"Hello"}]}"#
    
    func createSignature(_ payload: String, _ secret: String, _ timestamp: Int? = nil) -> String {
        let ts = timestamp ?? Int(Date().timeIntervalSince1970)
        let message = "\(ts).\(payload)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let signatureHex = Data(signature).map { String(format: "%02x", $0) }.joined()
        return "t=\(ts),v1=\(signatureHex)"
    }
    
    func testVerifySignatureValid() throws {
        let sigHeader = createSignature(payload, secret)
        XCTAssertTrue(try Webhook.verifySignature(payload: payload, signatureHeader: sigHeader, secret: secret))
    }
    
    func testVerifySignatureInvalid() throws {
        let sigHeader = "t=\(Int(Date().timeIntervalSince1970)),v1=invalidsignature"
        XCTAssertFalse(try Webhook.verifySignature(payload: payload, signatureHeader: sigHeader, secret: secret))
    }
    
    func testVerifySignatureNilHeader() throws {
        XCTAssertFalse(try Webhook.verifySignature(payload: payload, signatureHeader: nil, secret: secret))
    }
    
    func testVerifySignatureExpired() throws {
        let oldTimestamp = Int(Date().timeIntervalSince1970) - 600
        let sigHeader = createSignature(payload, secret, oldTimestamp)
        XCTAssertFalse(try Webhook.verifySignature(payload: payload, signatureHeader: sigHeader, secret: secret))
    }
    
    func testVerifySignatureMissingSecret() {
        XCTAssertThrowsError(try Webhook.verifySignature(payload: payload, signatureHeader: "t=123,v1=abc", secret: ""))
    }
    
    func testParseCompletedPayload() throws {
        let event = try Webhook.parse(payload)
        
        XCTAssertEqual(event.requestId, "req123")
        XCTAssertEqual(event.status, "completed")
        XCTAssertEqual(event.content.count, 1)
        XCTAssertEqual(event.content[0].type, "text")
        XCTAssertEqual(event.content[0].text, "Hello")
    }
    
    func testParseFailedPayload() throws {
        let failedPayload = #"{"id":"req456","status":"failed","error":{"code":"TIMEOUT","message":"Request timed out"}}"#
        let event = try Webhook.parse(failedPayload)
        
        XCTAssertEqual(event.status, "failed")
        XCTAssertNotNil(event.error)
        XCTAssertEqual(event.error?.code, "TIMEOUT")
        XCTAssertEqual(event.error?.message, "Request timed out")
    }
    
    func testParseClarificationPayload() throws {
        let clarificationPayload = #"{"id":"req789","status":"awaiting_clarification","clarification_question":"Which file do you mean?"}"#
        let event = try Webhook.parse(clarificationPayload)
        
        XCTAssertEqual(event.status, "awaiting_clarification")
        XCTAssertNotNil(event.clarification)
        XCTAssertEqual(event.clarification?.question, "Which file do you mean?")
    }
    
    func testParseInvalidJson() {
        XCTAssertThrowsError(try Webhook.parse("not json"))
    }
}
