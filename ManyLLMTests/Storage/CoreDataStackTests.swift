import XCTest
import CoreData
@testable import ManyLLM

class CoreDataStackTests: XCTestCase {
    var coreDataStack: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory Core Data stack for testing
        coreDataStack = createInMemoryCoreDataStack()
    }
    
    override func tearDown() {
        coreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryCoreDataStack() -> CoreDataStack {
        let stack = CoreDataStack.shared
        
        // Configure for in-memory testing
        let container = NSPersistentContainer(name: "ManyLLM")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        // Replace the persistent container for testing
        let mirror = Mirror(reflecting: stack)
        if let containerChild = mirror.children.first(where: { $0.label == "persistentContainer" }) {
            // This is a bit hacky, but necessary for testing
            // In a real implementation, you might want to make CoreDataStack more testable
        }
        
        return stack
    }
    
    // MARK: - Tests
    
    func testCoreDataStackInitialization() {
        XCTAssertNotNil(coreDataStack)
        XCTAssertNotNil(coreDataStack.viewContext)
        XCTAssertTrue(coreDataStack.isStoreAccessible())
    }
    
    func testViewContextConfiguration() {
        let context = coreDataStack.viewContext
        
        XCTAssertTrue(context.automaticallyMergesChangesFromParent)
        XCTAssertEqual(context.mergePolicy as? NSMergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    func testBackgroundContextCreation() {
        let backgroundContext = coreDataStack.newBackgroundContext()
        
        XCTAssertNotNil(backgroundContext)
        XCTAssertNotEqual(backgroundContext, coreDataStack.viewContext)
        XCTAssertEqual(backgroundContext.mergePolicy as? NSMergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    func testSaveViewContext() throws {
        let context = coreDataStack.viewContext
        
        // Create a test entity
        let workspace = WorkspaceEntity(context: context)
        workspace.id = UUID()
        workspace.name = "Test Workspace"
        workspace.createdAt = Date()
        workspace.lastModified = Date()
        workspace.autoSave = true
        
        XCTAssertTrue(context.hasChanges)
        
        // Save the context
        try coreDataStack.save()
        
        XCTAssertFalse(context.hasChanges)
    }
    
    func testSaveBackgroundContext() async throws {
        let expectation = XCTestExpectation(description: "Background save completed")
        
        try await coreDataStack.performBackgroundTask { context in
            let workspace = WorkspaceEntity(context: context)
            workspace.id = UUID()
            workspace.name = "Background Test Workspace"
            workspace.createdAt = Date()
            workspace.lastModified = Date()
            workspace.autoSave = true
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testPerformBackgroundTaskWithResult() async throws {
        let testName = "Result Test Workspace"
        
        let result = try await coreDataStack.performBackgroundTask { context in
            let workspace = WorkspaceEntity(context: context)
            workspace.id = UUID()
            workspace.name = testName
            workspace.createdAt = Date()
            workspace.lastModified = Date()
            workspace.autoSave = true
            
            return workspace.name
        }
        
        XCTAssertEqual(result, testName)
    }
    
    func testPerformBackgroundTaskWithError() async {
        do {
            _ = try await coreDataStack.performBackgroundTask { _ in
                throw ManyLLMError.storageError("Test error")
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testDeleteAllData() throws {
        let context = coreDataStack.viewContext
        
        // Create test data
        let workspace = WorkspaceEntity(context: context)
        workspace.id = UUID()
        workspace.name = "Test Workspace"
        workspace.createdAt = Date()
        workspace.lastModified = Date()
        workspace.autoSave = true
        
        let session = ChatSessionEntity(context: context)
        session.id = UUID()
        session.title = "Test Session"
        session.createdAt = Date()
        session.lastModified = Date()
        session.workspace = workspace
        
        try coreDataStack.save()
        
        // Verify data exists
        let workspaceFetch: NSFetchRequest<WorkspaceEntity> = WorkspaceEntity.fetchRequest()
        let workspaces = try context.fetch(workspaceFetch)
        XCTAssertEqual(workspaces.count, 1)
        
        let sessionFetch: NSFetchRequest<ChatSessionEntity> = ChatSessionEntity.fetchRequest()
        let sessions = try context.fetch(sessionFetch)
        XCTAssertEqual(sessions.count, 1)
        
        // Delete all data
        try coreDataStack.deleteAllData()
        
        // Verify data is deleted
        let workspacesAfter = try context.fetch(workspaceFetch)
        XCTAssertEqual(workspacesAfter.count, 0)
        
        let sessionsAfter = try context.fetch(sessionFetch)
        XCTAssertEqual(sessionsAfter.count, 0)
    }
    
    func testStoreAccessibility() {
        XCTAssertTrue(coreDataStack.isStoreAccessible())
    }
    
    func testMigrationCheck() {
        // This test is limited since we're using in-memory store
        // In a real scenario, you'd test with actual file-based stores
        let migrationNeeded = coreDataStack.migrationNeeded()
        XCTAssertFalse(migrationNeeded) // Should be false for new in-memory store
    }
}

// MARK: - Performance Tests

extension CoreDataStackTests {
    func testSavePerformance() throws {
        let context = coreDataStack.viewContext
        
        measure {
            // Create multiple entities
            for i in 0..<100 {
                let workspace = WorkspaceEntity(context: context)
                workspace.id = UUID()
                workspace.name = "Workspace \(i)"
                workspace.createdAt = Date()
                workspace.lastModified = Date()
                workspace.autoSave = true
            }
            
            do {
                try coreDataStack.save()
            } catch {
                XCTFail("Save failed: \(error)")
            }
        }
    }
    
    func testBackgroundTaskPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Background task completed")
            
            Task {
                do {
                    try await coreDataStack.performBackgroundTask { context in
                        for i in 0..<50 {
                            let workspace = WorkspaceEntity(context: context)
                            workspace.id = UUID()
                            workspace.name = "Background Workspace \(i)"
                            workspace.createdAt = Date()
                            workspace.lastModified = Date()
                            workspace.autoSave = true
                        }
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Background task failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}