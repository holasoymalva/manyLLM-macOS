import XCTest
@testable import ManyLLM

final class WorkspaceTests: XCTestCase {
    
    func testWorkspaceInitialization() {
        let workspace = Workspace(name: "Test Workspace")
        
        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertTrue(workspace.sessions.isEmpty)
        XCTAssertTrue(workspace.documentIds.isEmpty)
        XCTAssertNotNil(workspace.id)
        XCTAssertNotNil(workspace.createdAt)
        XCTAssertNotNil(workspace.lastModified)
        XCTAssertTrue(workspace.isEmpty)
    }
    
    func testWorkspaceWithSessions() {
        let session1 = ChatSession(title: "Session 1")
        let session2 = ChatSession(title: "Session 2")
        
        let workspace = Workspace(
            name: "Test Workspace",
            sessions: [session1, session2]
        )
        
        XCTAssertEqual(workspace.sessions.count, 2)
        XCTAssertFalse(workspace.isEmpty)
        XCTAssertEqual(workspace.totalMessageCount, 0)
    }
    
    func testWorkspaceSerialization() throws {
        let session = ChatSession(title: "Test Session")
        let originalWorkspace = Workspace(
            name: "Test Workspace",
            sessions: [session],
            documentIds: [UUID(), UUID()]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalWorkspace)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedWorkspace = try decoder.decode(Workspace.self, from: data)
        
        XCTAssertEqual(originalWorkspace, decodedWorkspace)
    }
    
    func testChatSessionInitialization() {
        let session = ChatSession(title: "Test Session")
        
        XCTAssertEqual(session.title, "Test Session")
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.createdAt)
        XCTAssertNotNil(session.lastModified)
        XCTAssertTrue(session.isEmpty)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertNil(session.lastMessage)
    }
    
    func testChatSessionWithMessages() {
        let message1 = ChatMessage(content: "Hello", role: .user)
        let message2 = ChatMessage(content: "Hi there!", role: .assistant)
        
        let session = ChatSession(
            title: "Test Session",
            messages: [message1, message2]
        )
        
        XCTAssertEqual(session.messageCount, 2)
        XCTAssertFalse(session.isEmpty)
        XCTAssertEqual(session.lastMessage?.content, "Hi there!")
        XCTAssertEqual(session.lastMessage?.role, .assistant)
    }
    
    func testWorkspaceCurrentSession() {
        let session1 = ChatSession(
            title: "Session 1",
            lastModified: Date().addingTimeInterval(-100)
        )
        let session2 = ChatSession(
            title: "Session 2",
            lastModified: Date()
        )
        
        let workspace = Workspace(
            name: "Test Workspace",
            sessions: [session1, session2]
        )
        
        XCTAssertEqual(workspace.currentSession?.title, "Session 2")
    }
    
    func testWorkspaceTouch() {
        var workspace = Workspace(name: "Test Workspace")
        let originalTime = workspace.lastModified
        
        // Wait a small amount to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)
        workspace.touch()
        
        XCTAssertGreaterThan(workspace.lastModified, originalTime)
    }
    
    func testWorkspaceSettings() {
        let settings = WorkspaceSettings(
            defaultModel: "test-model",
            defaultSystemPrompt: "You are a helpful assistant",
            defaultTemperature: 0.8,
            defaultMaxTokens: 1000,
            autoSave: false
        )
        
        let workspace = Workspace(
            name: "Test Workspace",
            settings: settings
        )
        
        XCTAssertEqual(workspace.settings?.defaultModel, "test-model")
        XCTAssertEqual(workspace.settings?.defaultTemperature, 0.8)
        XCTAssertEqual(workspace.settings?.autoSave, false)
    }
}