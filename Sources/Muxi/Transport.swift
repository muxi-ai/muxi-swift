import Foundation

public actor Transport {
    private static let retryStatuses: Set<Int> = [429, 500, 502, 503, 504]
    
    private let baseUrl: String
    private let keyId: String
    private let secretKey: String
    private let timeout: TimeInterval
    private let maxRetries: Int
    private let debug: Bool
    private let app: String?
    private let session: URLSession
    
    public init(baseUrl: String, keyId: String, secretKey: String, timeout: Int = 30, maxRetries: Int = 0, debug: Bool = false, app: String? = nil) {
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.keyId = keyId.trimmingCharacters(in: .whitespaces)
        self.secretKey = secretKey.trimmingCharacters(in: .whitespaces)
        self.timeout = TimeInterval(timeout)
        self.maxRetries = maxRetries
        self.debug = debug || ProcessInfo.processInfo.environment["MUXI_DEBUG"] == "1"
        self.app = app
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(timeout)
        self.session = URLSession(configuration: config)
    }
    
    public func requestJson(method: String, path: String, params: [String: Any?]? = nil, body: Any? = nil) async throws -> Any? {
        let (url, fullPath) = buildUrl(path: path, params: params)
        let headers = buildHeaders(method: method, path: fullPath)
        
        var attempt = 0
        var backoff = 0.5
        
        while true {
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = method
            headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
            
            if let body = body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            
            do {
                let startTime = Date()
                let (data, response) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startTime)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw MuxiError.connection(message: "Invalid response type")
                }
                
                log("\(method) \(fullPath) -> \(httpResponse.statusCode) (\(String(format: "%.3f", elapsed))s)")
                
                // Check for SDK updates (non-blocking, once per process)
                var responseHeaders: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    if let k = key as? String, let v = value as? String { responseHeaders[k] = v }
                }
                VersionCheck.checkForUpdates(responseHeaders)
                
                if httpResponse.statusCode >= 400 {
                    let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "0")
                    
                    if Self.retryStatuses.contains(httpResponse.statusCode) && attempt < maxRetries {
                        let sleepFor = min(backoff, 30)
                        log("retry \(method) \(fullPath) after \(sleepFor)s due to \(httpResponse.statusCode)")
                        try await Task.sleep(nanoseconds: UInt64(sleepFor * 1_000_000_000))
                        backoff *= 2
                        attempt += 1
                        continue
                    }
                    
                    throw parseError(data: data, statusCode: httpResponse.statusCode, retryAfter: retryAfter)
                }
                
                guard !data.isEmpty else { return nil }
                
                let parsed = try JSONSerialization.jsonObject(with: data)
                return unwrapEnvelope(parsed)
            } catch let error as MuxiError {
                throw error
            } catch {
                if attempt < maxRetries {
                    let sleepFor = min(backoff, 30)
                    log("retry \(method) \(fullPath) after \(sleepFor)s due to connection error: \(error)")
                    try await Task.sleep(nanoseconds: UInt64(sleepFor * 1_000_000_000))
                    backoff *= 2
                    attempt += 1
                    continue
                }
                throw MuxiError.connection(message: error.localizedDescription)
            }
        }
    }
    
    public func streamLines(method: String, path: String, params: [String: Any?]? = nil, body: Any? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let (url, fullPath) = buildUrl(path: path, params: params)
                var headers = buildHeaders(method: method, path: fullPath)
                headers["Accept"] = "text/event-stream"
                
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = method
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                
                if let body = body {
                    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                }
                
                do {
                    let (bytes, _) = try await session.bytes(for: request)
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildUrl(path: String, params: [String: Any?]?) -> (String, String) {
        let relPath = path.hasPrefix("/") ? path : "/\(path)"
        var query = ""
        if let params = params {
            let filtered = params.compactMapValues { $0 }
            if !filtered.isEmpty {
                query = "?" + filtered.map { "\($0.key)=\(String(describing: $0.value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
            }
        }
        let fullPath = relPath + query
        return ("\(baseUrl)\(fullPath)", fullPath)
    }
    
    private func buildHeaders(method: String, path: String, accept: String = "application/json") -> [String: String] {
        var headers = [
            "Authorization": Auth.buildAuthHeader(keyId: keyId, secretKey: secretKey, method: method, path: path),
            "Content-Type": "application/json",
            "Accept": accept,
            "X-Muxi-SDK": "swift/\(MuxiVersion.version)",
            "X-Muxi-Client": "swift/\(MuxiVersion.version)",
            "X-Muxi-Idempotency-Key": UUID().uuidString
        ]
        if let app = app, !app.isEmpty { headers["X-Muxi-App"] = app }
        return headers
    }
    
    private func unwrapEnvelope(_ obj: Any) -> Any {
        guard let dict = obj as? [String: Any], let data = dict["data"] else { return obj }
        
        var result = data
        if var resultDict = data as? [String: Any] {
            if let req = dict["request"] as? [String: Any], let id = req["id"] {
                resultDict["request_id"] = resultDict["request_id"] ?? id
            } else if let id = dict["request_id"] {
                resultDict["request_id"] = resultDict["request_id"] ?? id
            }
            if let ts = dict["timestamp"] {
                resultDict["timestamp"] = resultDict["timestamp"] ?? ts
            }
            result = resultDict
        }
        
        return result
    }
    
    private func parseError(data: Data, statusCode: Int, retryAfter: Int?) -> MuxiError {
        var code: String? = nil
        var message = "Unknown error"
        var details: [String: Any]? = nil
        
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            code = payload["code"] as? String ?? payload["error"] as? String
            message = payload["message"] as? String ?? message
            details = payload
        }
        
        return MuxiError.map(status: statusCode, code: code, message: message, details: details, retryAfter: retryAfter)
    }
    
    private func log(_ message: String) {
        if debug {
            print("[MUXI] \(message)")
        }
    }
}
