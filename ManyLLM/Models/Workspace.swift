import Foundation

/// A chat session within a workspace
struct ChatSession: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var lastModified: Date
    var modelUsed: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        modelUsed: String? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.modelUsed = modelUsed
    }
    
    /// The last message in the session
    var lastMessage: ChatMessage? {
        return messages.last
    }
    
    /// Number of messages in the session
    var messageCount: Int {
        return messages.count
    }
    
    /// Whether the session has any messages
    var isEmpty: Bool {
        return messages.isEmpty
    }
    
    /// Update the last modified timestamp
    mutating func touch() {
        lastModified = Date()
    }
}

/// A workspace containing chat sessions and documents
struct Workspace: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var sessions: [ChatSession]
    var documentIds: [UUID]
    let createdAt: Date
    var lastModified: Date
    var settings: WorkspaceSettings?
    
    init(
        id: UUID = UUID(),
        name: String,
        sessions: [ChatSession] = [],
        documentIds: [UUID] = [],
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        settings: WorkspaceSettings? = nil
    ) {
        self.id = id
        self.name = name
        self.sessions = sessions
        self.documentIds = documentIds
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.settings = settings
    }
    
    /// The current active session (most recently modified)
    var currentSession: ChatSession? {
        return sessions.max(by: { $0.lastModified < $1.lastModified })
    }
    
    /// Total number of messages across all sessions
    var totalMessageCount: Int {
        return sessions.reduce(0) { $0 + $1.messageCount }
    }
    
    /// Number of documents in the workspace
    var documentCount: Int {
        return documentIds.count
    }
    
    /// Whether the workspace has any content
    var isEmpty: Bool {
        return sessions.isEmpty && documentIds.isEmpty
    }
    
    /// Update the last modified timestamp
    mutating func touch() {
        lastModified = Date()
    }
}

/// Settings specific to a workspace
struct WorkspaceSettings: Codable, Equatable {
    var defaultModel: String?
    var defaultSystemPrompt: String?
    var defaultTemperature: Float?
    var defaultMaxTokens: Int?
    var autoSave: Bool
    
    init(
        defaultModel: String? = nil,
        defaultSystemPrompt: String? = nil,
        defaultTemperature: Float? = nil,
        defaultMaxTokens: Int? = nil,
        autoSave: Bool = true
    ) {
        self.defaultModel = defaultModel
        self.defaultSystemPrompt = defaultSystemPrompt
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.autoSave = autoSave
    }
}