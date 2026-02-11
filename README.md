# MUXI Swift SDK

Official Swift SDK for [MUXI](https://muxi.org) — infrastructure for AI agents.

**Highlights**
- Async/await with `URLSession` transport
- Built-in retries, idempotency, and typed errors
- Streaming helpers for chat/audio and deploy/log tails

> Need deeper usage notes? See the [User Guide](https://github.com/muxi-ai/muxi-swift/blob/main/USER_GUIDE.md) for streaming, retries, and auth details.

## Requirements

- Swift 5.9+
- macOS 12+ / iOS 15+ / tvOS 15+ / watchOS 8+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muxi-ai/muxi-swift.git", from: "0.20260129.0")
]
```

## Quick Start

### Server Management (Control Plane)

```swift
import Muxi

let server = ServerClient(config: ServerConfig(
    url: ProcessInfo.processInfo.environment["MUXI_SERVER_URL"]!,
    keyId: ProcessInfo.processInfo.environment["MUXI_KEY_ID"]!,
    secretKey: ProcessInfo.processInfo.environment["MUXI_SECRET_KEY"]!
))

// List formations
let formations = try await server.listFormations()
print(formations)

// Get server status
let status = try await server.status()
print("Uptime: \(status?["uptime"] ?? 0)s")
```

### Formation Usage (Runtime API)

```swift
import Muxi

// Connect via server proxy
let client = try FormationClient(config: FormationConfig(
    formationId: "my-bot",
    serverUrl: ProcessInfo.processInfo.environment["MUXI_SERVER_URL"],
    adminKey: ProcessInfo.processInfo.environment["MUXI_ADMIN_KEY"],
    clientKey: ProcessInfo.processInfo.environment["MUXI_CLIENT_KEY"]
))

// Chat (non-streaming)
let response = try await client.chat(["message": "Hello!"], userId: "user123")
print(response?["message"] ?? "")

// Chat (streaming)
for try await event in client.chatStream(["message": "Tell me a story"], userId: "user123") {
    print(event.data, terminator: "")
}

// Health check
let health = try await client.health()
print("Status: \(health?["status"] ?? "")")
```

## Webhook Verification

```swift
import Muxi

func handleWebhook(payload: String, signature: String?) throws {
    let secret = ProcessInfo.processInfo.environment["WEBHOOK_SECRET"]!
    
    guard try Webhook.verifySignature(payload: payload, signatureHeader: signature, secret: secret) else {
        throw NSError(domain: "Webhook", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid signature"])
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
}
```

## Error Handling

```swift
do {
    try await server.getFormation("nonexistent")
} catch MuxiError.notFound(let code, let message, _, _) {
    print("Not found: \(message)")
} catch MuxiError.authentication(let code, let message, _, _) {
    print("Auth failed: \(message)")
} catch MuxiError.rateLimit(let message, _, let retryAfter, _) {
    print("Rate limited. Retry after: \(retryAfter ?? 0)s")
} catch {
    print("Error: \(error)")
}
```

## License

MIT
