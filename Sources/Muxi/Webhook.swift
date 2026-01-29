import Foundation
import CryptoKit

public struct WebhookVerificationError: Error {
    public let message: String
    public init(_ message: String) { self.message = message }
}

public struct ContentItem {
    public let type: String
    public let text: String?
    public let file: [String: Any]?
    
    public init(type: String, text: String? = nil, file: [String: Any]? = nil) {
        self.type = type; self.text = text; self.file = file
    }
    
    public static func from(_ data: [String: Any]) -> ContentItem {
        ContentItem(type: data["type"] as? String ?? "text", text: data["text"] as? String, file: data["file"] as? [String: Any])
    }
}

public struct ErrorDetails {
    public let code: String
    public let message: String
    public let trace: String?
    
    public static func from(_ data: [String: Any]) -> ErrorDetails {
        ErrorDetails(code: data["code"] as? String ?? "unknown", message: data["message"] as? String ?? "Unknown error", trace: data["trace"] as? String)
    }
}

public struct Clarification {
    public let question: String
    public let clarificationRequestId: String?
    public let originalMessage: String?
    
    public static func from(_ data: [String: Any]) -> Clarification {
        Clarification(question: data["clarification_question"] as? String ?? "", clarificationRequestId: data["clarification_request_id"] as? String, originalMessage: data["original_message"] as? String)
    }
}

public struct WebhookEvent {
    public let requestId: String
    public let status: String
    public let timestamp: Int
    public let content: [ContentItem]
    public let error: ErrorDetails?
    public let clarification: Clarification?
    public let formationId: String?
    public let userId: String?
    public let processingTime: Double?
    public let processingMode: String
    public let webhookUrl: String?
    public let raw: [String: Any]
    
    public static func from(_ data: [String: Any]) -> WebhookEvent {
        let content = (data["response"] as? [[String: Any]] ?? []).map { ContentItem.from($0) }
        let error = (data["error"] as? [String: Any]).map { ErrorDetails.from($0) }
        let clarification = data["status"] as? String == "awaiting_clarification" ? Clarification.from(data) : nil
        
        return WebhookEvent(
            requestId: data["id"] as? String ?? "",
            status: data["status"] as? String ?? "unknown",
            timestamp: data["timestamp"] as? Int ?? 0,
            content: content,
            error: error,
            clarification: clarification,
            formationId: data["formation_id"] as? String,
            userId: data["user_id"] as? String,
            processingTime: data["processing_time"] as? Double,
            processingMode: data["processing_mode"] as? String ?? "async",
            webhookUrl: data["webhook_url"] as? String,
            raw: data
        )
    }
}

public enum Webhook {
    public static func verifySignature(payload: String, signatureHeader: String?, secret: String, toleranceSeconds: Int = 300) throws -> Bool {
        guard let signatureHeader = signatureHeader, !signatureHeader.isEmpty else { return false }
        guard !secret.isEmpty else { throw WebhookVerificationError("Webhook secret is required") }
        
        let parts = Dictionary(uniqueKeysWithValues: signatureHeader.split(separator: ",").compactMap { part -> (String, String)? in
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { return nil }
            return (String(kv[0]), String(kv[1]))
        })
        
        guard let timestampStr = parts["t"], let signature = parts["v1"], let timestamp = Int(timestampStr) else { return false }
        
        let currentTime = Int(Date().timeIntervalSince1970)
        guard abs(currentTime - timestamp) <= toleranceSeconds else { return false }
        
        let message = "\(timestamp).\(payload)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let expectedSignature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let expectedHex = Data(expectedSignature).map { String(format: "%02x", $0) }.joined()
        
        return expectedHex == signature
    }
    
    public static func parse(_ payload: String) throws -> WebhookEvent {
        guard let data = payload.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WebhookVerificationError("Invalid JSON payload")
        }
        return WebhookEvent.from(json)
    }
    
    public static func parse(_ data: [String: Any]) -> WebhookEvent {
        WebhookEvent.from(data)
    }
}
