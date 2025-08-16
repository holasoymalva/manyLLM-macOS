import XCTest
import SwiftUI
@testable import ManyLLM

/// UI tests for the chat interface components
final class ChatInterfaceTests: XCTestCase {
    
    func testSimpleChatMessageCreation() {
        // Test creating a user message
        let userMessage = SimpleChatMessage(content: "Hello, world!", isUser: true)
        
        XCTAssertEqual(userMessage.content, "Hello, world!")
        XCTAssertTrue(userMessage.isUser)
        XCTAssertNotNil(userMessage.id)
        XCTAssertNotNil(userMessage.timestamp)
    }
    
    func testSimpleChatMessageAssistantCreation() {
        // Test creating an assistant message
        let assistantMessage = SimpleChatMessage(content: "Hello! How can I help you?", isUser: false)
        
        XCTAssertEqual(assistantMessage.content, "Hello! How can I help you?")
        XCTAssertFalse(assistantMessage.isUser)
        XCTAssertNotNil(assistantMessage.id)
        XCTAssertNotNil(assistantMessage.timestamp)
    }
    
    func testChatViewInitialState() {
        // Test that ChatView initializes with empty state
        let chatView = ChatView()
        
        // Since we can't directly access @State variables in tests,
        // we'll test the view creation doesn't crash
        XCTAssertNotNil(chatView)
    }
    
    func testWelcomeViewCreation() {
        // Test that WelcomeView can be created
        let welcomeView = WelcomeView()
        XCTAssertNotNil(welcomeView)
    }
    
    func testSimpleMessageBubbleViewCreation() {
        // Test that SimpleMessageBubbleView can be created with a message
        let message = SimpleChatMessage(content: "Test message", isUser: true)
        let bubbleView = SimpleMessageBubbleView(message: message)
        
        XCTAssertNotNil(bubbleView)
    }
    
    func testChatInputViewCreation() {
        // Test that ChatInputView can be created with bindings
        let chatInputView = ChatInputView(
            messageText: .constant(""),
            systemPrompt: .constant("Default"),
            isProcessing: .constant(false),
            onSendMessage: {}
        )
        
        XCTAssertNotNil(chatInputView)
    }
    
    func testFileContextBarCreation() {
        // Test that FileContextBar can be created with documents
        let documents = ["test.pdf", "notes.txt"]
        let contextBar = FileContextBar(documents: documents)
        
        XCTAssertNotNil(contextBar)
    }
    
    func testDocumentChipCreation() {
        // Test that DocumentChip can be created
        let chip = DocumentChip(name: "test.pdf")
        
        XCTAssertNotNil(chip)
    }
    
    func testProcessingIndicatorCreation() {
        // Test that ProcessingIndicatorView can be created
        let indicator = ProcessingIndicatorView()
        
        XCTAssertNotNil(indicator)
    }
    
    func testInputHintCreation() {
        // Test that InputHint can be created
        let hint = InputHint(icon: "command", text: "Test hint")
        
        XCTAssertNotNil(hint)
    }
    
    func testRectCornerOptionSet() {
        // Test the custom RectCorner option set
        let topCorners: RectCorner = [.topLeft, .topRight]
        let allCorners = RectCorner.allCorners
        
        XCTAssertTrue(topCorners.contains(.topLeft))
        XCTAssertTrue(topCorners.contains(.topRight))
        XCTAssertFalse(topCorners.contains(.bottomLeft))
        
        XCTAssertTrue(allCorners.contains(.topLeft))
        XCTAssertTrue(allCorners.contains(.topRight))
        XCTAssertTrue(allCorners.contains(.bottomLeft))
        XCTAssertTrue(allCorners.contains(.bottomRight))
    }
    
    func testRoundedCornerShape() {
        // Test that RoundedCorner shape can be created
        let shape = RoundedCorner(radius: 10, corners: [.topLeft, .topRight])
        
        XCTAssertEqual(shape.radius, 10)
        XCTAssertEqual(shape.corners, [.topLeft, .topRight])
    }
}