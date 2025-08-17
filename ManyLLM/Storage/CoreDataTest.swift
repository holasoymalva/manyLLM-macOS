import Foundation
import CoreData

/// Simple test to verify Core Data implementation
class CoreDataTest {
    
    static func runBasicTest() {
        print("Starting Core Data basic test...")
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ManyLLM")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Failed to load store: \(error)")
                return
            }
            
            print("✅ Core Data store loaded successfully")
            
            // Test creating entities
            testEntityCreation(context: container.viewContext)
        }
    }
    
    private static func testEntityCreation(context: NSManagedObjectContext) {
        print("Testing entity creation...")
        
        // Create a workspace entity
        let workspace = WorkspaceEntity(context: context)
        workspace.id = UUID()
        workspace.name = "Test Workspace"
        workspace.createdAt = Date()
        workspace.lastModified = Date()
        workspace.autoSave = true
        
        // Create a session entity
        let session = ChatSessionEntity(context: context)
        session.id = UUID()
        session.title = "Test Session"
        session.createdAt = Date()
        session.lastModified = Date()
        session.workspace = workspace
        
        // Create a message entity
        let message = MessageEntity(context: context)
        message.id = UUID()
        message.content = "Hello, this is a test message"
        message.role = "user"
        message.timestamp = Date()
        message.session = session
        
        // Save the context
        do {
            try context.save()
            print("✅ Entities created and saved successfully")
            
            // Test fetching
            testEntityFetching(context: context)
        } catch {
            print("❌ Failed to save entities: \(error)")
        }
    }
    
    private static func testEntityFetching(context: NSManagedObjectContext) {
        print("Testing entity fetching...")
        
        // Fetch workspaces
        let workspaceFetch: NSFetchRequest<WorkspaceEntity> = WorkspaceEntity.fetchRequest()
        
        do {
            let workspaces = try context.fetch(workspaceFetch)
            print("✅ Fetched \(workspaces.count) workspace(s)")
            
            for workspace in workspaces {
                print("  - Workspace: \(workspace.name ?? "Unknown")")
                
                if let sessions = workspace.sessions {
                    print("    Sessions: \(sessions.count)")
                    
                    for session in sessions {
                        if let chatSession = session as? ChatSessionEntity {
                            print("      - Session: \(chatSession.title ?? "Unknown")")
                            
                            if let messages = chatSession.messages {
                                print("        Messages: \(messages.count)")
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to fetch workspaces: \(error)")
        }
    }
}

// Extension to make the test runnable
extension CoreDataTest {
    static func verifyImplementation() {
        print("=== Core Data Implementation Verification ===")
        runBasicTest()
        print("=== Test Complete ===")
    }
}