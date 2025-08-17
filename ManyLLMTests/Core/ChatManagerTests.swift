import XCTest
@testable import ManyLLM

@MainActor
final class ChatManagerTests: XCTestCase {
    
    var chatManager: ChatManager!
    var mockEngine: MockInferenceEngine!
    
    override func setUp() {
        super.setUp()
        chatManager = ChatManager()
        mockEngine = MockInferenceEngine()
        chatManager.setInferenceEngine(mockEngine)
    }
    
    override func tearDown() {
        chatManager = nil
        mockEngine = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(chatManager.messages.isEmpty)
        XCTAssertFalse(chatManager.isProcessing)
        XCTAssertNotNil(chatManager.currentInferenceEngine)
        XCTAssertTrue(chatManager.activeDocuments.isEmpty)
    }
    
    // MARK: - Message Sending Tests
    
    func testSendMessage() async {
        let testMessage = "Hello, how are you?"
        
        await chatManager.sendMessage(testMessage)
        
        // Should have user message and assistant response
        XCTAssertEqual(chatManager.messages.count, 2)
        
        let userMessage = chatManager.messages[0]
        XCTAssertEqual(userMessage.content, testMessage)
        XCTAssertEqual(userMessage.role, .user)
        
        let assistantMessage = chatManager.messages[1]
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertFalse(assistantMessage.content.isEmpty)
        XCTAssertNotNil(assistantMessage.metadata?.modelUsed)
        XCTAssertNotNil(assistantMessage.metadata?.inferenceTime)
        XCTAssertNotNil(assistantMessage.metadata?.tokenCount)
    }
    
    func testSendEmptyMessage() async {
        await chatManager.sendMessage("")
        await chatManager.sendMessage("   ")
        
        XCTAssertTrue(chatManager.messages.isEmpty)
    }
    
    func testSendMessageWithDocumentContext() async {
        // Create mock document
        let document = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/test.txt"),
            filename: "test.txt",
            fileSize: 1000,
            mimeType: "text/plain",
            content: "Test content",
            metadata: DocumentMetadata(),
            isActive: true
        )
        
        chatManager.setActiveDocuments([document])
        
        await chatManager.sendMessage("What does the document say?")
        
        XCTAssertEqual(chatManager.messages.count, 2)
        
        let userMessage = chatManager.messages[0]
        XCTAssertEqual(userMessage.metadata?.documentReferences, ["test.txt"])
        
        let assistantMessage = chatManager.messages[1]
        XCTAssertEqual(assistantMessage.metadata?.documentReferences, ["test.txt"])
    }
    
    func testPreventMultipleSimultaneousMessages() async {
        // Start first message
        let task1 = Task {
            await chatManager.sendMessage("First message")
        }
        
        // Try to send second message while first is processing
        let task2 = Task {
            await chatManager.sendMessage("Second message")
        }
        
        await task1.value
        await task2.value
        
        // Should only have processed the first message
        XCTAssertEqual(chatManager.messages.count, 2) // User + Assistant for first message only
        XCTAssertEqual(chatManager.messages[0].content, "First message")
    }
    
    // MARK: - Parameter Management Tests
    
    func testUpdateParameters() {
        let newParameters = InferenceParameters(
            temperature: 1.0,
            maxTokens: 500,
            systemPrompt: "You are a creative assistant"
        )
        
        chatManager.updateParameters(newParameters)
        
        XCTAssertEqual(chatManager.inferenceParameters.temperature, 1.0)
        XCTAssertEqual(chatManager.inferenceParameters.maxTokens, 500)
        XCTAssertEqual(chatManager.inferenceParameters.systemPrompt, "You are a creative assistant")
    }
    
    // MARK: - Document Management Tests
    
    func testToggleDocumentContext() {
        let document1 = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/test1.txt"),
            filename: "test1.txt",
            fileSize: 1000,
            mimeType: "text/plain",
            content: "Test content 1",
            metadata: DocumentMetadata()
        )
        
        let document2 = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/test2.txt"),
            filename: "test2.txt",
            fileSize: 2000,
            mimeType: "text/plain",
            content: "Test content 2",
            metadata: DocumentMetadata()
        )
        
        // Add first document
        chatManager.toggleDocumentContext(document1)
        XCTAssertEqual(chatManager.activeDocuments.count, 1)
        XCTAssertEqual(chatManager.activeDocuments[0].id, document1.id)
        
        // Add second document
        chatManager.toggleDocumentContext(document2)
        XCTAssertEqual(chatManager.activeDocuments.count, 2)
        
        // Remove first document
        chatManager.toggleDocumentContext(document1)
        XCTAssertEqual(chatManager.activeDocuments.count, 1)
        XCTAssertEqual(chatManager.activeDocuments[0].id, document2.id)
    }
    
    func testSetActiveDocuments() {
        let documents = [
            ProcessedDocument(
                originalURL: URL(fileURLWithPath: "/test1.txt"),
                filename: "test1.txt",
                fileSize: 1000,
                mimeType: "text/plain",
                content: "Test content 1",
                metadata: DocumentMetadata()
            ),
            ProcessedDocument(
                originalURL: URL(fileURLWithPath: "/test2.txt"),
                filename: "test2.txt",
                fileSize: 2000,
                mimeType: "text/plain",
                content: "Test content 2",
                metadata: DocumentMetadata()
            )
        ]
        
        chatManager.setActiveDocuments(documents)
        
        XCTAssertEqual(chatManager.activeDocuments.count, 2)
        XCTAssertEqual(chatManager.activeDocuments[0].filename, "test1.txt")
        XCTAssertEqual(chatManager.activeDocuments[1].filename, "test2.txt")
    }
    
    // MARK: - Session Management Tests
    
    func testClearMessages() {
        // Add some messages first
        chatManager.messages = [
            ChatMessage(content: "Test 1", role: .user),
            ChatMessage(content: "Response 1", role: .assistant)
        ]
        
        XCTAssertEqual(chatManager.messages.count, 2)
        
        chatManager.clearMessages()
        
        XCTAssertTrue(chatManager.messages.isEmpty)
    }
    
    func testExportSession() async {
        await chatManager.sendMessage("Test message")
        
        let exportData = chatManager.exportSession()
        
        XCTAssertNotNil(exportData)
        
        // Verify we can decode it back
        let decoder = JSONDecoder()
        XCTAssertNoThrow(try decoder.decode(ChatSession.self, from: exportData!))
    }
    
    func testImportSession() throws {
        let originalSession = ChatSession(
            messages: [
                ChatMessage(content: "Hello", role: .user),
                ChatMessage(content: "Hi there!", role: .assistant)
            ],
            parameters: InferenceParameters(temperature: 0.8, maxTokens: 1000),
            activeDocuments: []
        )
        
        let encoder = JSONEncoder()
        let sessionData = try encoder.encode(originalSession)
        
        try chatManager.importSession(from: sessionData)
        
        XCTAssertEqual(chatManager.messages.count, 2)
        XCTAssertEqual(chatManager.messages[0].content, "Hello")
        XCTAssertEqual(chatManager.messages[1].content, "Hi there!")
        XCTAssertEqual(chatManager.inferenceParameters.temperature, 0.8)
        XCTAssertEqual(chatManager.inferenceParameters.maxTokens, 1000)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleInferenceError() async {
        // Configure mock engine to always error
        mockEngine.shouldSimulateErrors = true
        mockEngine.errorProbability = 1.0
        
        await chatManager.sendMessage("This should cause an error")
        
        // Should have user message and system error message
        XCTAssertEqual(chatManager.messages.count, 2)
        XCTAssertEqual(chatManager.messages[0].role, .user)
        XCTAssertEqual(chatManager.messages[1].role, .system)
        XCTAssertTrue(chatManager.messages[1].content.contains("Error"))
        XCTAssertFalse(chatManager.isProcessing)
    }
    
    func testSendMessageWithoutEngine() async {
        chatManager.setInferenceEngine(nil as InferenceEngine?)
        
        await chatManager.sendMessage("Test message")
        
        // Should have user message and system error message
        XCTAssertEqual(chatManager.messages.count, 2)
        XCTAssertEqual(chatManager.messages[0].role, .user)
        XCTAssertEqual(chatManager.messages[1].role, .system)
        XCTAssertTrue(chatManager.messages[1].content.contains("No inference engine"))
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelInference() async {
        // Configure longer delay to allow cancellation
        mockEngine.responseDelay = 2.0
        
        // Start message processing
        let task = Task {
            await chatManager.sendMessage("Long processing message")
        }
        
        // Cancel after short delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        chatManager.cancelCurrentInference()
        
        await task.value
        
        XCTAssertFalse(chatManager.isProcessing)
    }
    
    // MARK: - Engine Management Tests
    
    func testSetInferenceEngine() {
        let newMockEngine = MockInferenceEngine()
        
        chatManager.setInferenceEngine(newMockEngine)
        
        XCTAssertTrue(chatManager.currentInferenceEngine === newMockEngine)
    }
}