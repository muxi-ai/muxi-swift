import Foundation

public enum MuxiError: Error {
    case authentication(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case authorization(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case notFound(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case conflict(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case validation(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case rateLimit(message: String, statusCode: Int, retryAfter: Int?, details: [String: Any]?)
    case server(code: String, message: String, statusCode: Int, details: [String: Any]?)
    case connection(message: String)
    case unknown(code: String, message: String, statusCode: Int, details: [String: Any]?)
    
    public static func map(status: Int, code: String?, message: String, details: [String: Any]? = nil, retryAfter: Int? = nil) -> MuxiError {
        switch status {
        case 401:
            return .authentication(code: code ?? "UNAUTHORIZED", message: message, statusCode: status, details: details)
        case 403:
            return .authorization(code: code ?? "FORBIDDEN", message: message, statusCode: status, details: details)
        case 404:
            return .notFound(code: code ?? "NOT_FOUND", message: message, statusCode: status, details: details)
        case 409:
            return .conflict(code: code ?? "CONFLICT", message: message, statusCode: status, details: details)
        case 422:
            return .validation(code: code ?? "VALIDATION_ERROR", message: message, statusCode: status, details: details)
        case 429:
            return .rateLimit(message: message.isEmpty ? "Too Many Requests" : message, statusCode: status, retryAfter: retryAfter, details: details)
        case 500...599:
            return .server(code: code ?? "SERVER_ERROR", message: message, statusCode: status, details: details)
        default:
            return .unknown(code: code ?? "ERROR", message: message, statusCode: status, details: details)
        }
    }
}

extension MuxiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .authentication(code, message, _, _),
             let .authorization(code, message, _, _),
             let .notFound(code, message, _, _),
             let .conflict(code, message, _, _),
             let .validation(code, message, _, _),
             let .server(code, message, _, _),
             let .unknown(code, message, _, _):
            return "\(code): \(message)"
        case let .rateLimit(message, _, _, _):
            return "RATE_LIMITED: \(message)"
        case let .connection(message):
            return "CONNECTION_ERROR: \(message)"
        }
    }
}
