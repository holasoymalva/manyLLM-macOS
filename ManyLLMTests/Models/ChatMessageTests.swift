import XCTest
@testable import ManyLLM

final class ChatMessageTests: XCTestCase {
    
    func testChatMessageInitialization() {
        let message = ChatMessage(
            content: "Hello, world!",
            role: .user
        )
        
        XCTAssertEqual(message.content, "Hello, world!")
        XCTAssertEqual(message.role, .user)
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
        XCTAssertNil(message.metadata)
    }
    
    func testChatMessageWithMetadata() {
        let metadata = MessageMetadata(
            modelUsed: "test-model",
            inferenceTime: 1.5,
            tokenCount: 10,
            temperature: 0.7,
            maxTokens: 100,
            documentReferences: ["doc1", "doc2"]
        )
        
        let message = ChatMessage(
            content: "Response with context",
            role: .assistant,
            metadata: metadata
        )
        
        XCTAssertEqual(message.metadata?.modelUsed, "test-model")
        XCTAssertEqual(message.metadata?.inferenceTime, 1.5)
        XCTAssertEqual(message.metadata?.tokenCount, 10)
        XCTAssertEqual(message.metadata?.documentReferences?.count, 2)
        XCTAssertTrue(message.hasDocumentReferences)
        XCTAssertEqual(message.documentReferenceCount, 2)
    }
    
    func testChatMessageSerialization() throws {
        let metadata = MessageMetadata(
            modelUsed: "test-model",
            inferenceTime: 1.5,
            tokenCount: 10
        )
        
        let originalMessage = ChatMessage(
            id: UUID(),
            content: "Test message",
            role: .assistant,
            timestamp: Date(),
            metadata: metadata
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMessage)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(ChatMessage.self, from: data)
        
        XCTAssertEqual(originalMessage, decodedMessage)
    }
    
    func testMessageRoleDisplayNames() {
        XCTAssertEqual(MessageRole.user.displayName, "User")
        XCTAssertEqual(MessageRole.assistant.displayName, "Assistant")
        XCTAssertEqual(MessageRole.system.displayName, "System")
    }
    
    func testMessageFormattedTimestamp() {
        let message = ChatMessage(
            content: "Test",
            role: .user,
            timestamp: Date()
        )
        
        let formattedTime = message.formattedTimestamp
        XCTAssertFalse(formattedTime.isEmpty)
        // Should contain time format (AM/PM or 24-hour)
        XCTAssertTrue(formattedTime.contains(":"))
    }
    
    func testMessageWithoutDocumentReferences() {
        let message = ChatMessage(
            content: "Simple message",
            role: .user
        )
        
        XCTAssertFalse(message.hasDocumentReferences)
        XCTAssertEqual(message.documentReferenceCount, 0)
    }
}