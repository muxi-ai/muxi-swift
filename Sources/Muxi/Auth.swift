import Foundation
import CryptoKit

public enum Auth {
    public static func generateHmacSignature(secretKey: String, method: String, path: String) -> (signature: String, timestamp: Int) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let signPath = path.split(separator: "?").first.map(String.init) ?? path
        let message = "\(timestamp);\(method);\(signPath)"
        
        let key = SymmetricKey(data: Data(secretKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let signatureBase64 = Data(signature).base64EncodedString()
        
        return (signatureBase64, timestamp)
    }
    
    public static func buildAuthHeader(keyId: String, secretKey: String, method: String, path: String) -> String {
        let (signature, timestamp) = generateHmacSignature(secretKey: secretKey, method: method, path: path)
        return "MUXI-HMAC key=\(keyId), timestamp=\(timestamp), signature=\(signature)"
    }
}
