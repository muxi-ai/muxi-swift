import Foundation

public struct FormationConfig {
    public var formationId: String?
    public var url: String?
    public var serverUrl: String?
    public var baseUrl: String?
    public var adminKey: String?
    public var clientKey: String?
    public var maxRetries: Int = 0
    public var timeout: Int = 30
    public var debug: Bool = false
    
    public init(formationId: String? = nil, url: String? = nil, serverUrl: String? = nil, baseUrl: String? = nil, adminKey: String? = nil, clientKey: String? = nil, maxRetries: Int = 0, timeout: Int = 30, debug: Bool = false) {
        self.formationId = formationId
        self.url = url
        self.serverUrl = serverUrl
        self.baseUrl = baseUrl
        self.adminKey = adminKey
        self.clientKey = clientKey
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.debug = debug
    }
}

public actor FormationClient {
    private let transport: FormationTransport
    
    public init(config: FormationConfig) throws {
        let baseUrl = try Self.buildBaseUrl(config)
        self.transport = FormationTransport(
            baseUrl: baseUrl,
            adminKey: config.adminKey,
            clientKey: config.clientKey,
            timeout: config.timeout,
            maxRetries: config.maxRetries,
            debug: config.debug
        )
    }
    
    // Health / status
    public func health() async throws -> [String: Any]? { try await transport.request("GET", "/health", useAdmin: false) }
    public func getStatus() async throws -> [String: Any]? { try await transport.request("GET", "/status", useAdmin: true) }
    public func getConfig() async throws -> [String: Any]? { try await transport.request("GET", "/config", useAdmin: true) }
    public func getFormationInfo() async throws -> [String: Any]? { try await transport.request("GET", "/formation", useAdmin: true) }
    
    // Agents / MCP
    public func getAgents() async throws -> [String: Any]? { try await transport.request("GET", "/agents", useAdmin: true) }
    public func getAgent(_ agentId: String) async throws -> [String: Any]? { try await transport.request("GET", "/agents/\(agentId)", useAdmin: true) }
    public func getMcpServers() async throws -> [String: Any]? { try await transport.request("GET", "/mcp/servers", useAdmin: true) }
    public func getMcpServer(_ serverId: String) async throws -> [String: Any]? { try await transport.request("GET", "/mcp/servers/\(serverId)", useAdmin: true) }
    public func getMcpTools() async throws -> [String: Any]? { try await transport.request("GET", "/mcp/tools", useAdmin: true) }
    
    // Secrets
    public func getSecrets() async throws -> [String: Any]? { try await transport.request("GET", "/secrets", useAdmin: true) }
    public func getSecret(_ key: String) async throws -> [String: Any]? { try await transport.request("GET", "/secrets/\(key)", useAdmin: true) }
    public func setSecret(_ key: String, value: String) async throws { _ = try await transport.request("PUT", "/secrets/\(key)", body: ["value": value], useAdmin: true) }
    public func deleteSecret(_ key: String) async throws { _ = try await transport.request("DELETE", "/secrets/\(key)", useAdmin: true) }
    
    // Chat
    public func chat(_ payload: [String: Any], userId: String = "") async throws -> [String: Any]? {
        try await transport.request("POST", "/chat", body: payload, useAdmin: false, userId: userId)
    }
    
    public func chatStream(_ payload: [String: Any], userId: String = "") -> AsyncThrowingStream<SseEvent, Error> {
        var body = payload
        body["stream"] = true
        return transport.streamSse("POST", "/chat", body: body, useAdmin: false, userId: userId)
    }
    
    public func audioChat(_ payload: [String: Any], userId: String = "") async throws -> [String: Any]? {
        try await transport.request("POST", "/audiochat", body: payload, useAdmin: false, userId: userId)
    }
    
    public func audioChatStream(_ payload: [String: Any], userId: String = "") -> AsyncThrowingStream<SseEvent, Error> {
        var body = payload
        body["stream"] = true
        return transport.streamSse("POST", "/audiochat", body: body, useAdmin: false, userId: userId)
    }
    
    // Sessions
    public func getSessions(_ userId: String, limit: Int? = nil) async throws -> [String: Any]? {
        try await transport.request("GET", "/sessions", params: ["user_id": userId, "limit": limit], useAdmin: false, userId: userId)
    }
    public func getSession(_ sessionId: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/sessions/\(sessionId)", useAdmin: false, userId: userId)
    }
    public func getSessionMessages(_ sessionId: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/sessions/\(sessionId)/messages", useAdmin: false, userId: userId)
    }
    public func restoreSession(_ sessionId: String, userId: String, messages: [[String: Any]]) async throws {
        _ = try await transport.request("POST", "/sessions/\(sessionId)/restore", body: ["messages": messages], useAdmin: false, userId: userId)
    }
    
    // Requests
    public func getRequests(_ userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/requests", useAdmin: false, userId: userId)
    }
    public func getRequestStatus(_ requestId: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/requests/\(requestId)", useAdmin: false, userId: userId)
    }
    public func cancelRequest(_ requestId: String, userId: String) async throws {
        _ = try await transport.request("DELETE", "/requests/\(requestId)", useAdmin: false, userId: userId)
    }
    
    // Memory
    public func getMemoryConfig() async throws -> [String: Any]? { try await transport.request("GET", "/memory", useAdmin: true) }
    public func getMemories(_ userId: String, limit: Int? = nil) async throws -> [String: Any]? {
        try await transport.request("GET", "/memories", params: ["user_id": userId, "limit": limit], useAdmin: false, userId: userId)
    }
    public func addMemory(_ userId: String, type: String, detail: String) async throws -> [String: Any]? {
        try await transport.request("POST", "/memories", body: ["user_id": userId, "type": type, "detail": detail], useAdmin: false, userId: userId)
    }
    public func deleteMemory(_ userId: String, memoryId: String) async throws {
        _ = try await transport.request("DELETE", "/memories/\(memoryId)", params: ["user_id": userId], useAdmin: false, userId: userId)
    }
    public func getUserBuffer(_ userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/memory/buffer", params: ["user_id": userId], useAdmin: false, userId: userId)
    }
    public func clearUserBuffer(_ userId: String) async throws -> [String: Any]? {
        try await transport.request("DELETE", "/memory/buffer", params: ["user_id": userId], useAdmin: false, userId: userId)
    }
    public func clearSessionBuffer(_ userId: String, sessionId: String) async throws -> [String: Any]? {
        try await transport.request("DELETE", "/memory/buffer/\(sessionId)", params: ["user_id": userId], useAdmin: false, userId: userId)
    }
    public func clearAllBuffers() async throws -> [String: Any]? { try await transport.request("DELETE", "/memory/buffer", useAdmin: true) }
    public func getBufferStats() async throws -> [String: Any]? { try await transport.request("GET", "/memory/stats", useAdmin: true) }
    
    // Scheduler
    public func getSchedulerConfig() async throws -> [String: Any]? { try await transport.request("GET", "/scheduler", useAdmin: true) }
    public func getSchedulerJobs(_ userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/scheduler/jobs", params: ["user_id": userId], useAdmin: true)
    }
    public func getSchedulerJob(_ jobId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/scheduler/jobs/\(jobId)", useAdmin: true)
    }
    public func createSchedulerJob(type: String, schedule: String, message: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("POST", "/scheduler/jobs", body: ["type": type, "schedule": schedule, "message": message, "user_id": userId], useAdmin: true)
    }
    public func deleteSchedulerJob(_ jobId: String) async throws {
        _ = try await transport.request("DELETE", "/scheduler/jobs/\(jobId)", useAdmin: true)
    }
    
    // Config endpoints
    public func getAsyncConfig() async throws -> [String: Any]? { try await transport.request("GET", "/async", useAdmin: true) }
    public func getA2aConfig() async throws -> [String: Any]? { try await transport.request("GET", "/a2a", useAdmin: true) }
    public func getLoggingConfig() async throws -> [String: Any]? { try await transport.request("GET", "/logging", useAdmin: true) }
    public func getLoggingDestinations() async throws -> [String: Any]? { try await transport.request("GET", "/logging/destinations", useAdmin: true) }
    
    // Credentials
    public func listCredentialServices() async throws -> [String: Any]? { try await transport.request("GET", "/credentials/services", useAdmin: true) }
    public func listCredentials(_ userId: String) async throws -> [String: Any]? { try await transport.request("GET", "/credentials", useAdmin: false, userId: userId) }
    public func getCredential(_ credentialId: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/credentials/\(credentialId)", useAdmin: false, userId: userId)
    }
    public func createCredential(_ userId: String, payload: [String: Any]) async throws -> [String: Any]? {
        try await transport.request("POST", "/credentials", body: payload, useAdmin: false, userId: userId)
    }
    public func deleteCredential(_ credentialId: String, userId: String) async throws -> [String: Any]? {
        try await transport.request("DELETE", "/credentials/\(credentialId)", useAdmin: false, userId: userId)
    }
    
    // User identifiers
    public func getUserIdentifiersForUser(_ userId: String) async throws -> [String: Any]? {
        try await transport.request("GET", "/users/identifiers/\(userId)", useAdmin: true)
    }
    public func linkUserIdentifier(_ muxiUserId: String, identifiers: [Any]) async throws -> [String: Any]? {
        try await transport.request("POST", "/users/identifiers", body: ["muxi_user_id": muxiUserId, "identifiers": identifiers], useAdmin: true)
    }
    public func unlinkUserIdentifier(_ identifier: String) async throws {
        _ = try await transport.request("DELETE", "/users/identifiers/\(identifier)", useAdmin: true)
    }
    
    // Overlord / LLM
    public func getOverlordConfig() async throws -> [String: Any]? { try await transport.request("GET", "/overlord", useAdmin: true) }
    public func getOverlordPersona() async throws -> [String: Any]? { try await transport.request("GET", "/overlord/persona", useAdmin: true) }
    public func getLlmSettings() async throws -> [String: Any]? { try await transport.request("GET", "/llm/settings", useAdmin: true) }
    
    // Triggers / SOP / Audit
    public func getTriggers() async throws -> [String: Any]? { try await transport.request("GET", "/triggers", useAdmin: false) }
    public func getTrigger(_ name: String) async throws -> [String: Any]? { try await transport.request("GET", "/triggers/\(name)", useAdmin: false) }
    public func fireTrigger(_ name: String, data: Any, async: Bool = false, userId: String = "") async throws -> [String: Any]? {
        try await transport.request("POST", "/triggers/\(name)", params: ["async": async ? "true" : "false"], body: data as? [String: Any] ?? [:], useAdmin: false, userId: userId)
    }
    public func getSops() async throws -> [String: Any]? { try await transport.request("GET", "/sops", useAdmin: false) }
    public func getSop(_ name: String) async throws -> [String: Any]? { try await transport.request("GET", "/sops/\(name)", useAdmin: false) }
    public func getAuditLog() async throws -> [String: Any]? { try await transport.request("GET", "/audit", useAdmin: true) }
    public func clearAuditLog() async throws { _ = try await transport.request("DELETE", "/audit?confirm=clear-audit-log", useAdmin: true) }
    
    // Streaming
    public func streamEvents(_ userId: String) -> AsyncThrowingStream<SseEvent, Error> {
        transport.streamSse("GET", "/events", params: ["user_id": userId], useAdmin: false, userId: userId)
    }
    public func streamRequest(_ userId: String, sessionId: String, requestId: String) -> AsyncThrowingStream<SseEvent, Error> {
        transport.streamSse("GET", "/events/\(sessionId)/\(requestId)", useAdmin: false, userId: userId)
    }
    public func streamLogs(_ filters: [String: Any]? = nil) -> AsyncThrowingStream<SseEvent, Error> {
        transport.streamSse("GET", "/logs", params: filters, useAdmin: true)
    }
    
    // Resolve user
    public func resolveUser(_ identifier: String, createUser: Bool = false) async throws -> [String: Any]? {
        try await transport.request("POST", "/users/resolve", body: ["identifier": identifier, "create_user": createUser], useAdmin: false)
    }
    
    private static func buildBaseUrl(_ config: FormationConfig) throws -> String {
        if let baseUrl = config.baseUrl, !baseUrl.isEmpty {
            return baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if let url = config.url, !url.isEmpty {
            return url.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1"
        }
        if let serverUrl = config.serverUrl, let formationId = config.formationId, !serverUrl.isEmpty, !formationId.isEmpty {
            return "\(serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/\(formationId)/v1"
        }
        throw MuxiError.validation(code: "INVALID_CONFIG", message: "must set baseUrl, url, or serverUrl+formationId", statusCode: 0, details: nil)
    }
}

actor FormationTransport {
    private static let retryStatuses: Set<Int> = [429, 500, 502, 503, 504]
    
    private let baseUrl: String
    private let adminKey: String?
    private let clientKey: String?
    private let timeout: Int
    private let maxRetries: Int
    private let debug: Bool
    private let session: URLSession
    
    init(baseUrl: String, adminKey: String?, clientKey: String?, timeout: Int, maxRetries: Int, debug: Bool) {
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.adminKey = adminKey?.trimmingCharacters(in: .whitespaces)
        self.clientKey = clientKey?.trimmingCharacters(in: .whitespaces)
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.debug = debug || ProcessInfo.processInfo.environment["MUXI_DEBUG"] == "1"
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(timeout)
        self.session = URLSession(configuration: config)
    }
    
    func request(_ method: String, _ path: String, params: [String: Any?]? = nil, body: [String: Any]? = nil, useAdmin: Bool = true, userId: String = "") async throws -> [String: Any]? {
        let (url, _) = buildUrl(path, params)
        let headers = buildHeaders(useAdmin: useAdmin, userId: userId, contentType: body != nil ? "application/json" : nil)
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body = body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw MuxiError.connection(message: "Invalid response") }
        
        if httpResponse.statusCode >= 400 {
            var code: String?; var message = "Unknown error"
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                code = payload["code"] as? String ?? payload["error"] as? String
                message = payload["message"] as? String ?? message
            }
            throw MuxiError.map(status: httpResponse.statusCode, code: code, message: message, retryAfter: Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "0"))
        }
        
        guard !data.isEmpty else { return nil }
        let parsed = try JSONSerialization.jsonObject(with: data)
        return unwrapEnvelope(parsed)
    }
    
    nonisolated func streamSse(_ method: String, _ path: String, params: [String: Any?]? = nil, body: [String: Any]? = nil, useAdmin: Bool = true, userId: String = "") -> AsyncThrowingStream<SseEvent, Error> {
        let baseUrl = self.baseUrl
        let adminKey = self.adminKey
        let clientKey = self.clientKey
        let session = self.session
        
        return AsyncThrowingStream { continuation in
            Task {
                let (url, _) = Self.buildUrlStatic(baseUrl, path, params)
                var headers = Self.buildHeadersStatic(useAdmin: useAdmin, userId: userId, contentType: body != nil ? "application/json" : nil, adminKey: adminKey, clientKey: clientKey)
                headers["Accept"] = "text/event-stream"
                
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = method
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                if let body = body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
                
                var currentEvent: String?
                var dataParts: [String] = []
                
                do {
                    let (bytes, _) = try await session.bytes(for: request)
                    for try await line in bytes.lines {
                        if line.hasPrefix(":") { continue }
                        if line.isEmpty {
                            if !dataParts.isEmpty { continuation.yield(SseEvent(event: currentEvent ?? "message", data: dataParts.joined(separator: "\n"))) }
                            currentEvent = nil; dataParts = []; continue
                        }
                        if line.hasPrefix("event:") { currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
                        else if line.hasPrefix("data:") { dataParts.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
    
    private func buildUrl(_ path: String, _ params: [String: Any?]?) -> (String, String) {
        let relPath = path.hasPrefix("/") ? path : "/\(path)"
        var query = ""
        if let params = params {
            let filtered = params.compactMapValues { $0 }
            if !filtered.isEmpty { query = "?" + filtered.map { "\($0.key)=\(String(describing: $0.value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&") }
        }
        let fullPath = relPath + query
        return ("\(baseUrl)\(fullPath)", fullPath)
    }
    
    private func buildHeaders(useAdmin: Bool, userId: String, contentType: String?, accept: String = "application/json") -> [String: String] {
        var headers: [String: String] = ["X-Muxi-SDK": "swift/\(MuxiVersion.version)", "X-Muxi-Client": "swift/\(MuxiVersion.version)", "X-Muxi-Idempotency-Key": UUID().uuidString, "Accept": accept]
        if useAdmin { headers["X-MUXI-ADMIN-KEY"] = adminKey ?? "" } else { headers["X-MUXI-CLIENT-KEY"] = clientKey ?? "" }
        if !userId.isEmpty { headers["X-Muxi-User-ID"] = userId }
        if let ct = contentType { headers["Content-Type"] = ct }
        return headers
    }
    
    private func unwrapEnvelope(_ obj: Any) -> [String: Any]? {
        guard let dict = obj as? [String: Any], let data = dict["data"] as? [String: Any] else { return obj as? [String: Any] }
        var result = data
        if let req = dict["request"] as? [String: Any], let id = req["id"] { result["request_id"] = result["request_id"] ?? id }
        if let ts = dict["timestamp"] { result["timestamp"] = result["timestamp"] ?? ts }
        return result
    }
    
    private static func buildUrlStatic(_ baseUrl: String, _ path: String, _ params: [String: Any?]?) -> (String, String) {
        let relPath = path.hasPrefix("/") ? path : "/\(path)"
        var query = ""
        if let params = params {
            let filtered = params.compactMapValues { $0 }
            if !filtered.isEmpty { query = "?" + filtered.map { "\($0.key)=\(String(describing: $0.value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&") }
        }
        let fullPath = relPath + query
        return ("\(baseUrl)\(fullPath)", fullPath)
    }
    
    private static func buildHeadersStatic(useAdmin: Bool, userId: String, contentType: String?, adminKey: String?, clientKey: String?, accept: String = "application/json") -> [String: String] {
        var headers: [String: String] = ["X-Muxi-SDK": "swift/\(MuxiVersion.version)", "X-Muxi-Client": "swift/\(MuxiVersion.version)", "X-Muxi-Idempotency-Key": UUID().uuidString, "Accept": accept]
        if useAdmin { headers["X-MUXI-ADMIN-KEY"] = adminKey ?? "" } else { headers["X-MUXI-CLIENT-KEY"] = clientKey ?? "" }
        if !userId.isEmpty { headers["X-Muxi-User-ID"] = userId }
        if let ct = contentType { headers["Content-Type"] = ct }
        return headers
    }
}
