import Foundation

/// Metadata associated with a chat message
struct MessageMetadata: Codable, Equatable {
    let modelUsed: String?
    let inferenceTime: TimeInterval?
    let tokenCount: Int?
    let temperature: Float?
    let maxTokens: Int?
    let documentReferences: [String]?
    
    init(
        modelUsed: String? = nil,
        inferenceTime: TimeInterval? = nil,
        tokenCount: Int? = nil,
        temperature: Float? = nil,
        maxTokens: Int? = nil,
        documentReferences: [String]? = nil
    ) {
        self.modelUsed = modelUsed
        self.inferenceTime = inferenceTime
        self.tokenCount = tokenCount
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.documentReferences = documentReferences
    }
}

/// A single message in a chat conversation
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    let metadata: MessageMetadata?
    
    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Whether this message contains document references
    var hasDocumentReferences: Bool {
        return metadata?.documentReferences?.isEmpty == false
    }
    
    /// Count of referenced documents
    var documentReferenceCount: Int {
        return metadata?.documentReferences?.count ?? 0
    }
}