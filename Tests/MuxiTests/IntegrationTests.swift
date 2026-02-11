import XCTest
@testable import Muxi

final class IntegrationTests: XCTestCase {
    
    static func env(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }
    
    static func requireEnv(_ name: String) throws -> String {
        guard let value = env(name), !value.isEmpty else {
            throw XCTSkip("\(name) not set")
        }
        return value
    }
    
    static var serverClient: ServerClient?
    static var formationClient: FormationClient?
    
    override class func setUp() {
        super.setUp()
        do {
            let serverUrl = try requireEnv("MUXI_SDK_E2E_SERVER_URL")
            let keyId = try requireEnv("MUXI_SDK_E2E_KEY_ID")
            let secretKey = try requireEnv("MUXI_SDK_E2E_SECRET_KEY")
            let formationId = try requireEnv("MUXI_SDK_E2E_FORMATION_ID")
            let clientKey = try requireEnv("MUXI_SDK_E2E_CLIENT_KEY")
            let adminKey = try requireEnv("MUXI_SDK_E2E_ADMIN_KEY")
            
            serverClient = ServerClient(config: ServerConfig(
                url: serverUrl,
                keyId: keyId,
                secretKey: secretKey
            ))
            
            var formationConfig = FormationConfig()
            formationConfig.serverUrl = serverUrl
            formationConfig.formationId = formationId
            formationConfig.clientKey = clientKey
            formationConfig.adminKey = adminKey
            formationClient = try FormationClient(config: formationConfig)
        } catch {
            // Will skip tests
        }
    }
    
    func testServerPing() async throws {
        guard let client = Self.serverClient else { throw XCTSkip("Server client not configured") }
        let result = try await client.ping()
        XCTAssertGreaterThanOrEqual(result, 0)
    }
    
    func testServerHealth() async throws {
        guard let client = Self.serverClient else { throw XCTSkip("Server client not configured") }
        let result = try await client.health()
        XCTAssertNotNil(result)
    }
    
    func testServerStatus() async throws {
        guard let client = Self.serverClient else { throw XCTSkip("Server client not configured") }
        let result = try await client.status()
        XCTAssertNotNil(result)
    }
    
    func testServerListFormations() async throws {
        guard let client = Self.serverClient else { throw XCTSkip("Server client not configured") }
        let result = try await client.listFormations()
        XCTAssertNotNil(result)
    }
    
    func testFormationHealth() async throws {
        guard let client = Self.formationClient else { throw XCTSkip("Formation client not configured") }
        let result = try await client.health()
        XCTAssertNotNil(result)
    }
    
    func testFormationGetStatus() async throws {
        guard let client = Self.formationClient else { throw XCTSkip("Formation client not configured") }
        let result = try await client.getStatus()
        XCTAssertNotNil(result)
    }
    
    func testFormationGetConfig() async throws {
        guard let client = Self.formationClient else { throw XCTSkip("Formation client not configured") }
        let result = try await client.getConfig()
        XCTAssertNotNil(result)
    }
    
    func testFormationGetAgents() async throws {
        guard let client = Self.formationClient else { throw XCTSkip("Formation client not configured") }
        let result = try await client.getAgents()
        XCTAssertNotNil(result)
    }
}
