import Foundation

/// Represents the role of a message in a chat conversation
enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user:
            return "User"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        }
    }
}