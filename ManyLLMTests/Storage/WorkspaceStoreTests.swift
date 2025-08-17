import XCTest
import CoreData
@testable import ManyLLM

class WorkspaceStoreTests: XCTestCase {
    var workspaceStore: WorkspaceStore!
    var coreDataStack: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory Core Data stack for testing
        coreDataStack = createInMemoryCoreDataStack()
        workspaceStore = WorkspaceStore(coreDataStack: coreDataStack)
    }
    
    override func tearDown() {
        workspaceStore = nil
        coreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryCoreDataStack() -> CoreDataStack {
        let container = NSPersistentContainer(name: "ManyLLM")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        // Create a mock CoreDataStack
        return CoreDataStack.shared // This would need to be modified for proper testing
    }
    
    private func createTestWorkspace(name: String = "Test Workspace") -> Workspace {
        return Workspace(
            name: name,
            sessions: [],
            documentIds: [],
            createdAt: Date(),
            lastModified: Date(),
            settings: WorkspaceSettings()
        )
    }
    
    private func createTestChatSession(title: String = "Test Session") -> ChatSession {
        return ChatSession(
            title: title,
            messages: [],
            createdAt: Date(),
            lastModified: Date(),
            modelUsed: "test-model"
        )
    }
    
    // MARK: - Workspace CRUD Tests
    
    func testCreateWorkspace() throws {
        let workspaceName = "New Test Workspace"
        
        let workspace = try workspaceStore.createWorkspace(name: workspaceName)
        
        XCTAssertEqual(workspace.name, workspaceName)
        XCTAssertNotNil(workspace.id)
        XCTAssertTrue(workspace.sessions.isEmpty)
        XCTAssertTrue(workspace.documentIds.isEmpty)
        XCTAssertNotNil(workspace.createdAt)
        XCTAssertNotNil(workspace.lastModified)
        
        // Check that it was added to the store
        XCTAssertTrue(workspaceStore.workspaces.contains { $0.id == workspace.id })
    }
    
    func testSaveWorkspace() throws {
        let workspace = createTestWorkspace()
        
        try workspaceStore.saveWorkspace(workspace)
        
        let savedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        XCTAssertNotNil(savedWorkspace)
        XCTAssertEqual(savedWorkspace?.name, workspace.name)
        XCTAssertEqual(savedWorkspace?.id, workspace.id)
    }
    
    func testUpdateWorkspace() throws {
        var workspace = createTestWorkspace()
        try workspaceStore.saveWorkspace(workspace)
        
        // Update the workspace
        workspace.name = "Updated Workspace Name"
        workspace.touch()
        
        try workspaceStore.saveWorkspace(workspace)
        
        let updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        XCTAssertEqual(updatedWorkspace?.name, "Updated Workspace Name")
    }
    
    func testDeleteWorkspace() throws {
        let workspace = createTestWorkspace()
        try workspaceStore.saveWorkspace(workspace)
        
        XCTAssertNotNil(workspaceStore.getWorkspace(id: workspace.id))
        
        try workspaceStore.deleteWorkspace(workspace)
        
        XCTAssertNil(workspaceStore.getWorkspace(id: workspace.id))
        XCTAssertFalse(workspaceStore.workspaces.contains { $0.id == workspace.id })
    }
    
    func testGetWorkspaceById() throws {
        let workspace = createTestWorkspace()
        try workspaceStore.saveWorkspace(workspace)
        
        let retrievedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        
        XCTAssertNotNil(retrievedWorkspace)
        XCTAssertEqual(retrievedWorkspace?.id, workspace.id)
        XCTAssertEqual(retrievedWorkspace?.name, workspace.name)
    }
    
    // MARK: - Current Workspace Tests
    
    func testSetCurrentWorkspace() throws {
        let workspace = createTestWorkspace()
        try workspaceStore.saveWorkspace(workspace)
        
        workspaceStore.setCurrentWorkspace(workspace)
        
        XCTAssertEqual(workspaceStore.currentWorkspace?.id, workspace.id)
    }
    
    func testCurrentWorkspaceSetOnFirstCreate() throws {
        XCTAssertNil(workspaceStore.currentWorkspace)
        
        let workspace = try workspaceStore.createWorkspace(name: "First Workspace")
        
        XCTAssertEqual(workspaceStore.currentWorkspace?.id, workspace.id)
    }
    
    func testCurrentWorkspaceNotChangedOnSubsequentCreate() throws {
        let firstWorkspace = try workspaceStore.createWorkspace(name: "First Workspace")
        let secondWorkspace = try workspaceStore.createWorkspace(name: "Second Workspace")
        
        XCTAssertEqual(workspaceStore.currentWorkspace?.id, firstWorkspace.id)
        XCTAssertNotEqual(workspaceStore.currentWorkspace?.id, secondWorkspace.id)
    }
    
    // MARK: - Session Management Tests
    
    func testAddSessionToWorkspace() throws {
        let workspace = createTestWorkspace()
        let session = createTestChatSession()
        
        try workspaceStore.addSession(session, to: workspace)
        
        let updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        XCTAssertEqual(updatedWorkspace?.sessions.count, 1)
        XCTAssertEqual(updatedWorkspace?.sessions.first?.id, session.id)
    }
    
    func testUpdateSessionInWorkspace() throws {
        let workspace = createTestWorkspace()
        var session = createTestChatSession()
        
        try workspaceStore.addSession(session, to: workspace)
        
        // Update the session
        session.title = "Updated Session Title"
        
        try workspaceStore.updateSession(session, in: workspace)
        
        let updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        let updatedSession = updatedWorkspace?.sessions.first { $0.id == session.id }
        XCTAssertEqual(updatedSession?.title, "Updated Session Title")
    }
    
    func testRemoveSessionFromWorkspace() throws {
        let workspace = createTestWorkspace()
        let session = createTestChatSession()
        
        try workspaceStore.addSession(session, to: workspace)
        
        var updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)!
        XCTAssertEqual(updatedWorkspace.sessions.count, 1)
        
        try workspaceStore.removeSession(session, from: updatedWorkspace)
        
        updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)!
        XCTAssertEqual(updatedWorkspace.sessions.count, 0)
    }
    
    func testUpdateNonExistentSession() throws {
        let workspace = createTestWorkspace()
        let session = createTestChatSession()
        
        XCTAssertThrowsError(try workspaceStore.updateSession(session, in: workspace)) { error in
            XCTAssertTrue(error is ManyLLMError)
            if case .storageError(let message) = error as? ManyLLMError {
                XCTAssertEqual(message, "Session not found in workspace")
            }
        }
    }
    
    // MARK: - Document Management Tests
    
    func testAddDocumentToWorkspace() throws {
        let workspace = createTestWorkspace()
        let documentId = UUID()
        
        try workspaceStore.addDocument(documentId, to: workspace)
        
        let updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        XCTAssertEqual(updatedWorkspace?.documentIds.count, 1)
        XCTAssertTrue(updatedWorkspace?.documentIds.contains(documentId) == true)
    }
    
    func testAddDuplicateDocumentToWorkspace() throws {
        let workspace = createTestWorkspace()
        let documentId = UUID()
        
        try workspaceStore.addDocument(documentId, to: workspace)
        try workspaceStore.addDocument(documentId, to: workspace) // Add same document again
        
        let updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)
        XCTAssertEqual(updatedWorkspace?.documentIds.count, 1) // Should still be 1
    }
    
    func testRemoveDocumentFromWorkspace() throws {
        let workspace = createTestWorkspace()
        let documentId = UUID()
        
        try workspaceStore.addDocument(documentId, to: workspace)
        
        var updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)!
        XCTAssertEqual(updatedWorkspace.documentIds.count, 1)
        
        try workspaceStore.removeDocument(documentId, from: updatedWorkspace)
        
        updatedWorkspace = workspaceStore.getWorkspace(id: workspace.id)!
        XCTAssertEqual(updatedWorkspace.documentIds.count, 0)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testCreateDefaultWorkspaceIfNeeded() {
        XCTAssertTrue(workspaceStore.workspaces.isEmpty)
        
        workspaceStore.createDefaultWorkspaceIfNeeded()
        
        XCTAssertEqual(workspaceStore.workspaces.count, 1)
        XCTAssertEqual(workspaceStore.workspaces.first?.name, "Default Workspace")
    }
    
    func testCreateDefaultWorkspaceIfNeededWhenWorkspacesExist() throws {
        let _ = try workspaceStore.createWorkspace(name: "Existing Workspace")
        let initialCount = workspaceStore.workspaces.count
        
        workspaceStore.createDefaultWorkspaceIfNeeded()
        
        XCTAssertEqual(workspaceStore.workspaces.count, initialCount) // Should not create another
    }
    
    func testGetCurrentOrDefaultWorkspace() throws {
        // When no workspaces exist
        XCTAssertNil(workspaceStore.currentWorkspace)
        
        let workspace = workspaceStore.getCurrentOrDefaultWorkspace()
        
        XCTAssertNotNil(workspace)
        XCTAssertEqual(workspace?.name, "Default Workspace")
        
        // When current workspace is set
        let customWorkspace = try workspaceStore.createWorkspace(name: "Custom Workspace")
        workspaceStore.setCurrentWorkspace(customWorkspace)
        
        let currentWorkspace = workspaceStore.getCurrentOrDefaultWorkspace()
        XCTAssertEqual(currentWorkspace?.id, customWorkspace.id)
    }
}

// MARK: - Performance Tests

extension WorkspaceStoreTests {
    func testCreateMultipleWorkspacesPerformance() {
        measure {
            for i in 0..<50 {
                do {
                    let _ = try workspaceStore.createWorkspace(name: "Workspace \(i)")
                } catch {
                    XCTFail("Failed to create workspace: \(error)")
                }
            }
        }
    }
    
    func testSaveWorkspacePerformance() throws {
        let workspace = createTestWorkspace()
        
        measure {
            do {
                try workspaceStore.saveWorkspace(workspace)
            } catch {
                XCTFail("Failed to save workspace: \(error)")
            }
        }
    }
}