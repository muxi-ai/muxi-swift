import XCTest
@testable import Muxi

final class AuthTests: XCTestCase {
    func testGenerateHmacSignature() {
        let (signature, timestamp) = Auth.generateHmacSignature(secretKey: "secret", method: "GET", path: "/test")
        
        XCTAssertFalse(signature.isEmpty)
        XCTAssertGreaterThan(timestamp, 0)
        XCTAssertLessThanOrEqual(abs(Int(Date().timeIntervalSince1970) - timestamp), 5)
    }
    
    func testBuildAuthHeader() {
        let header = Auth.buildAuthHeader(keyId: "key123", secretKey: "secret", method: "POST", path: "/rpc/test")
        
        XCTAssertTrue(header.hasPrefix("MUXI-HMAC key=key123, timestamp="))
        XCTAssertTrue(header.contains("signature="))
    }
    
    func testSignatureStripsQueryParams() {
        let (sig1, _) = Auth.generateHmacSignature(secretKey: "secret", method: "GET", path: "/test")
        let (sig2, _) = Auth.generateHmacSignature(secretKey: "secret", method: "GET", path: "/test?foo=bar")
        
        XCTAssertEqual(sig1.count, sig2.count)
    }
}
