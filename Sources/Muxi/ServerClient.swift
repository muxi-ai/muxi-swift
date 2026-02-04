import Foundation

public struct ServerConfig {
    public let url: String
    public let keyId: String
    public let secretKey: String
    public var maxRetries: Int = 0
    public var timeout: Int = 30
    public var debug: Bool = false
    var app: String?  // Internal: for Console telemetry
    
    public init(url: String, keyId: String, secretKey: String, maxRetries: Int = 0, timeout: Int = 30, debug: Bool = false, app: String? = nil) {
        self.url = url
        self.keyId = keyId
        self.secretKey = secretKey
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.debug = debug
        self.app = app
    }
}

public actor ServerClient {
    private let transport: Transport
    
    public init(config: ServerConfig) {
        self.transport = Transport(
            baseUrl: config.url,
            keyId: config.keyId,
            secretKey: config.secretKey,
            timeout: config.timeout,
            maxRetries: config.maxRetries,
            debug: config.debug,
            app: config.app
        )
    }
    
    // Unauthenticated
    public func ping() async throws -> Int {
        let resp = try await transport.requestJson(method: "GET", path: "/ping")
        return (resp as? [String: Any])?.count ?? 0
    }
    
    public func health() async throws -> [String: Any]? {
        try await transport.requestJson(method: "GET", path: "/health") as? [String: Any]
    }
    
    // Authenticated
    public func status() async throws -> [String: Any]? {
        try await rpcGet("/rpc/server/status")
    }
    
    public func listFormations() async throws -> [String: Any]? {
        try await rpcGet("/rpc/formations")
    }
    
    public func getFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcGet("/rpc/formations/\(formationId)")
    }
    
    public func stopFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/stop", body: [:])
    }
    
    public func startFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/start", body: [:])
    }
    
    public func restartFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/restart", body: [:])
    }
    
    public func rollbackFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/rollback", body: [:])
    }
    
    public func deleteFormation(_ formationId: String) async throws -> [String: Any]? {
        try await rpcDelete("/rpc/formations/\(formationId)")
    }
    
    public func cancelUpdate(_ formationId: String) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/cancel-update", body: [:])
    }
    
    public func deployFormation(_ formationId: String, payload: [String: Any]) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/deploy", body: payload)
    }
    
    public func updateFormation(_ formationId: String, payload: [String: Any]) async throws -> [String: Any]? {
        try await rpcPost("/rpc/formations/\(formationId)/update", body: payload)
    }
    
    public func getFormationLogs(_ formationId: String, limit: Int? = nil) async throws -> [String: Any]? {
        let params = limit.map { ["limit": $0] }
        return try await rpcGet("/rpc/formations/\(formationId)/logs", params: params)
    }
    
    public func getServerLogs(limit: Int? = nil) async throws -> [String: Any]? {
        let params = limit.map { ["limit": $0] }
        return try await rpcGet("/rpc/server/logs", params: params)
    }
    
    // Streaming
    public func deployFormationStream(_ formationId: String, payload: [String: Any]) -> AsyncThrowingStream<SseEvent, Error> {
        streamSse("/rpc/formations/\(formationId)/deploy/stream", body: payload)
    }
    
    public func updateFormationStream(_ formationId: String, payload: [String: Any]) -> AsyncThrowingStream<SseEvent, Error> {
        streamSse("/rpc/formations/\(formationId)/update/stream", body: payload)
    }
    
    public func startFormationStream(_ formationId: String) -> AsyncThrowingStream<SseEvent, Error> {
        streamSse("/rpc/formations/\(formationId)/start/stream", body: [:])
    }
    
    public func restartFormationStream(_ formationId: String) -> AsyncThrowingStream<SseEvent, Error> {
        streamSse("/rpc/formations/\(formationId)/restart/stream", body: [:])
    }
    
    public func rollbackFormationStream(_ formationId: String) -> AsyncThrowingStream<SseEvent, Error> {
        streamSse("/rpc/formations/\(formationId)/rollback/stream", body: [:])
    }
    
    public func streamFormationLogs(_ formationId: String) -> AsyncThrowingStream<SseEvent, Error> {
        streamSseGet("/rpc/formations/\(formationId)/logs/stream")
    }
    
    private func rpcGet(_ path: String, params: [String: Any]? = nil) async throws -> [String: Any]? {
        try await transport.requestJson(method: "GET", path: path, params: params) as? [String: Any]
    }
    
    private func rpcPost(_ path: String, body: [String: Any]) async throws -> [String: Any]? {
        try await transport.requestJson(method: "POST", path: path, body: body) as? [String: Any]
    }
    
    private func rpcDelete(_ path: String) async throws -> [String: Any]? {
        try await transport.requestJson(method: "DELETE", path: path) as? [String: Any]
    }
    
    private func streamSse(_ path: String, body: [String: Any]) -> AsyncThrowingStream<SseEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var currentEvent: String?
                var dataParts: [String] = []
                
                for try await line in await transport.streamLines(method: "POST", path: path, body: body) {
                    if line.hasPrefix(":") { continue }
                    
                    if line.isEmpty {
                        if !dataParts.isEmpty {
                            continuation.yield(SseEvent(event: currentEvent ?? "message", data: dataParts.joined(separator: "\n")))
                        }
                        currentEvent = nil
                        dataParts = []
                        continue
                    }
                    
                    if line.hasPrefix("event:") {
                        currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        dataParts.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                }
                continuation.finish()
            }
        }
    }
    
    private func streamSseGet(_ path: String) -> AsyncThrowingStream<SseEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var currentEvent: String?
                var dataParts: [String] = []
                
                for try await line in await transport.streamLines(method: "GET", path: path) {
                    if line.hasPrefix(":") { continue }
                    
                    if line.isEmpty {
                        if !dataParts.isEmpty {
                            continuation.yield(SseEvent(event: currentEvent ?? "message", data: dataParts.joined(separator: "\n")))
                        }
                        currentEvent = nil
                        dataParts = []
                        continue
                    }
                    
                    if line.hasPrefix("event:") {
                        currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        dataParts.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                }
                continuation.finish()
            }
        }
    }
}

public struct SseEvent {
    public let event: String
    public let data: String
}
