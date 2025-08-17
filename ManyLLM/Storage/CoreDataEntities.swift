import Foundation
import CoreData

// MARK: - WorkspaceEntity Extensions

extension WorkspaceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkspaceEntity> {
        return NSFetchRequest<WorkspaceEntity>(entityName: "WorkspaceEntity")
    }
}

// MARK: - ChatSessionEntity Extensions

extension ChatSessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatSessionEntity> {
        return NSFetchRequest<ChatSessionEntity>(entityName: "ChatSessionEntity")
    }
}

// MARK: - MessageEntity Extensions

extension MessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
}

// MARK: - DocumentEntity Extensions

extension DocumentEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DocumentEntity> {
        return NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
    }
}

// MARK: - DocumentChunkEntity Extensions

extension DocumentChunkEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DocumentChunkEntity> {
        return NSFetchRequest<DocumentChunkEntity>(entityName: "DocumentChunkEntity")
    }
}