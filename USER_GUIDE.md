# MUXI Swift SDK User Guide

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muxi-ai/muxi-swift.git", from: "0.20260129.0")
]
```

## Requirements

- Swift 5.9+
- macOS 12+ / iOS 15+

## Quickstart

```swift
import Muxi

// Server client (management, HMAC auth)
let server = try ServerClient(config: ServerConfig(
    url: "https://server.example.com",
    keyId: "<key_id>",
    secretKey: "<secret_key>"
))
print(try await server.status())

// Formation client (runtime, key auth)
let formation = try FormationClient(config: FormationConfig(
    serverUrl: "https://server.example.com",
    formationId: "<formation_id>",
    clientKey: "<client_key>",
    adminKey: "<admin_key>"
))
print(try await formation.health())
```

## Clients

- **ServerClient** (management, HMAC): deploy/list/update formations, server health/status, server logs.
- **FormationClient** (runtime, client/admin keys): chat/audio (streaming), agents, secrets, MCP, memory, scheduler, sessions/requests, identifiers, credentials, triggers/SOPs/audit, async/A2A/logging config, overlord/LLM settings, events/logs streaming.

## Streaming

```swift
// Chat streaming with AsyncThrowingStream
for try await chunk in formation.chatStream(["message": "Tell me a story"], userId: "user-123") {
    print(chunk.data, terminator: "")
}

// Event streaming
for try await event in formation.streamEvents("user-123") {
    print(event)
}

// Log streaming (admin)
for try await log in formation.streamLogs(["level": "info"]) {
    print(log)
}
```

## Auth & Headers

- **ServerClient**: HMAC with `keyId`/`secretKey` on `/rpc` endpoints.
- **FormationClient**: `X-MUXI-CLIENT-KEY` or `X-MUXI-ADMIN-KEY` on `/api/{formation}/v1`. Override `baseUrl` for direct access (e.g., `http://localhost:9012/v1`).
- **Idempotency**: `X-Muxi-Idempotency-Key` auto-generated on every request.
- **SDK headers**: `X-Muxi-SDK`, `X-Muxi-Client` set automatically.

## Timeouts & Retries

- Default timeout: 30s (no timeout for streaming).
- Retries: `maxRetries` with exponential backoff on 429/5xx/connection errors; respects `Retry-After`.
- Debug logging: enabled when `debug: true` or `MUXI_DEBUG=1`.

## Error Handling

```swift
do {
    try await formation.chat(["message": "hello"])
} catch MuxiError.authentication(let code, let message, _, _) {
    print("Auth failed: \(message)")
} catch MuxiError.rateLimit(let message, _, let retryAfter, _) {
    print("Rate limited. Retry after: \(retryAfter ?? 0)s")
} catch MuxiError.notFound(let code, let message, _, _) {
    print("Not found: \(message)")
} catch let error as MuxiError {
    print("\(error)")
}
```

Error types: `authentication`, `authorization`, `notFound`, `validation`, `rateLimit`, `server`, `connection`.

## Notable Endpoints (FormationClient)

| Category | Methods |
|----------|---------|
| Chat/Audio | `chat`, `chatStream`, `audioChat`, `audioChatStream` |
| Memory | `getMemoryConfig`, `getMemories`, `addMemory`, `deleteMemory`, `getUserBuffer`, `clearUserBuffer`, `clearSessionBuffer`, `clearAllBuffers`, `getBufferStats` |
| Scheduler | `getSchedulerConfig`, `getSchedulerJobs`, `getSchedulerJob`, `createSchedulerJob`, `deleteSchedulerJob` |
| Sessions | `getSessions`, `getSession`, `getSessionMessages`, `restoreSession` |
| Requests | `getRequests`, `getRequestStatus`, `cancelRequest` |
| Agents/MCP | `getAgents`, `getAgent`, `getMcpServers`, `getMcpServer`, `getMcpTools` |
| Secrets | `getSecrets`, `getSecret`, `setSecret`, `deleteSecret` |
| Credentials | `listCredentialServices`, `listCredentials`, `getCredential`, `createCredential`, `deleteCredential` |
| Identifiers | `getUserIdentifiersForUser`, `linkUserIdentifier`, `unlinkUserIdentifier` |
| Triggers/SOP | `getTriggers`, `getTrigger`, `fireTrigger`, `getSops`, `getSop` |
| Audit | `getAuditLog`, `clearAuditLog` |
| Config | `getStatus`, `getConfig`, `getFormationInfo`, `getAsyncConfig`, `getA2aConfig`, `getLoggingConfig`, `getLoggingDestinations`, `getOverlordConfig`, `getOverlordSoul`, `getLlmSettings` |
| Streaming | `streamEvents`, `streamLogs`, `streamRequest` |
| User | `resolveUser` |

## Webhook Verification

```swift
import Muxi
import Vapor // or your web framework

app.post("webhooks", "muxi") { req -> Response in
    let payload = req.body.string ?? ""
    let signature = req.headers.first(name: "X-Muxi-Signature")
    
    guard Webhook.verifySignature(payload: payload, signature: signature, secret: Environment.get("WEBHOOK_SECRET")!) else {
        return Response(status: .unauthorized)
    }
    
    let event = try Webhook.parse(payload)
    
    switch event.status {
    case "completed":
        for item in event.content where item.type == "text" {
            print(item.text ?? "")
        }
    case "failed":
        print("Error: \(event.error?.message ?? "")")
    case "awaiting_clarification":
        print("Question: \(event.clarification?.question ?? "")")
    default:
        break
    }
    
    return Response(status: .ok)
}
```

## Testing Locally

```bash
cd swift
swift build
swift test
```
