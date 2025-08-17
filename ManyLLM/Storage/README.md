# Core Data Persistence Implementation

This module implements the Core Data persistence layer for ManyLLM, providing data storage and management for workspaces, chat sessions, messages, and documents.

## Components

### Core Data Model (`ManyLLM.xcdatamodeld`)
- **WorkspaceEntity**: Stores workspace information and settings
- **ChatSessionEntity**: Stores individual chat sessions within workspaces  
- **MessageEntity**: Stores individual messages with metadata
- **DocumentEntity**: Stores processed document information
- **DocumentChunkEntity**: Stores document chunks with embeddings

### Core Data Stack (`CoreDataStack.swift`)
- Manages the persistent container and contexts
- Provides background task execution
- Handles automatic migration and error recovery
- Includes privacy-focused file protection

### Data Stores
- **WorkspaceStore**: CRUD operations for workspaces and sessions
- **DocumentStore**: CRUD operations for documents and chunks
- Both stores provide reactive updates via `@Published` properties

### Migration Support (`CoreDataMigration.swift`)
- Handles Core Data model migrations
- Provides backup and recovery functionality
- Supports progressive migration strategies

### Entity Extensions (`CoreDataEntities.swift`)
- Provides fetch request methods for all entities
- Ensures proper Core Data integration

## Key Features

### Privacy & Security
- File protection using `FileProtectionType.complete`
- Local-only data storage
- No network transmission of user data
- Encrypted storage at rest (via FileVault integration)

### Performance
- Background context operations for heavy tasks
- Lazy loading of relationships
- Efficient batch operations
- Memory-mapped vector storage for embeddings

### Error Handling
- Comprehensive error types with recovery suggestions
- Automatic retry mechanisms for transient failures
- Graceful degradation when components fail
- Detailed logging for debugging

### Migration Support
- Automatic lightweight migration
- Progressive migration for complex changes
- Backup creation before migration
- Validation after migration completion

## Usage

### Initialization
```swift
// Initialize Core Data stack
let coreDataStack = CoreDataStack.shared

// Create stores
let workspaceStore = WorkspaceStore(coreDataStack: coreDataStack)
let documentStore = DocumentStore(coreDataStack: coreDataStack)
```

### Workspace Operations
```swift
// Create workspace
let workspace = try workspaceStore.createWorkspace(name: "My Workspace")

// Add session to workspace
let session = ChatSession(title: "Chat 1")
try workspaceStore.addSession(session, to: workspace)

// Save workspace
try workspaceStore.saveWorkspace(workspace)
```

### Document Operations
```swift
// Save document
let document = ProcessedDocument(...)
try documentStore.saveDocument(document)

// Get active documents
let activeDocuments = documentStore.getActiveDocuments()

// Search documents
let results = documentStore.searchDocuments(query: "search term")
```

## Testing

The implementation includes comprehensive unit tests covering:
- Core Data stack initialization and configuration
- CRUD operations for all entities
- Error handling and recovery scenarios
- Performance benchmarks
- Migration testing

Run tests using:
```bash
xcodebuild test -scheme ManyLLM -destination 'platform=macOS'
```

## Requirements Satisfied

This implementation satisfies the following requirements from the specification:

- **7.2**: Workspace organization with persistent storage
- **7.4**: Data persistence with Core Data integration
- **Privacy**: Local-only processing with encrypted storage
- **Error Handling**: Comprehensive error management with recovery
- **Migration**: Automatic data migration support

## Future Enhancements

- CloudKit integration for cross-device sync (optional)
- Advanced search with full-text indexing
- Automatic backup and restore functionality
- Performance monitoring and optimization
- Advanced migration strategies for complex schema changes