import Foundation
import SwiftUI

/// Manages chat sessions and coordinates with inference engines
@MainActor
class ChatManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var activeDocuments: [ProcessedDocument] = []
    @Published var inferenceParameters = InferenceParameters()
    
    // MARK: - Private Properties
    
    private var streamingTask: Task<Void, Never>?
    private let engineManager: InferenceEngineManager
    
    // MARK: - Computed Properties
    
    var currentInferenceEngine: InferenceEngine? {
        return engineManager.currentEngine
    }
    
    var loadedModel: LoadedModel? {
        return engineManager.loadedModel
    }
    
    // MARK: - Initialization
    
    init(engineManager: InferenceEngineManager? = nil) {
        self.engineManager = engineManager ?? InferenceEngineManager()
    }
    
    // MARK: - Public Methods
    
    /// Send a message and get a response from the current inference engine
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isProcessing else { return }
        guard let engine = currentInferenceEngine else {
            await addSystemMessage("No inference engine available. Please load a model first.")
            return
        }
        
        // Create and add user message
        let userMessage = ChatMessage(
            content: content,
            role: .user,
            metadata: activeDocuments.isEmpty ? nil : MessageMetadata(
                documentReferences: activeDocuments.map { $0.filename }
            )
        )
        
        messages.append(userMessage)
        isProcessing = true
        
        do {
            // Use streaming response for better UX
            let stream = try await engine.generateStreamingChatResponse(
                messages: messages,
                parameters: inferenceParameters,
                context: activeDocuments.isEmpty ? nil : activeDocuments
            )
            
            await handleStreamingResponse(stream)
            
        } catch {
            await handleInferenceError(error)
        }
    }
    
    /// Send a message with streaming response
    func sendMessageWithStreaming(_ content: String) async {
        await sendMessage(content)
    }
    
    /// Clear all messages in the current chat
    func clearMessages() {
        messages.removeAll()
        cancelCurrentInference()
    }
    
    /// Cancel the current inference operation
    func cancelCurrentInference() {
        streamingTask?.cancel()
        streamingTask = nil
        
        Task {
            try? await currentInferenceEngine?.cancelInference()
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    /// Switch to a specific inference engine
    func switchToEngine(_ engineType: EngineType) async throws {
        try await engineManager.switchToEngine(engineType)
    }
    
    /// Load a model
    func loadModel(_ model: ModelInfo) async throws {
        try await engineManager.loadModel(model)
    }
    
    /// Unload the current model
    func unloadModel() async throws {
        try await engineManager.unloadModel()
    }
    
    /// Get available engines
    var availableEngines: [EngineInfo] {
        return engineManager.availableEngines
    }
    
    /// Check if engine manager is loading
    var isEngineLoading: Bool {
        return engineManager.isLoading
    }
    
    /// Update inference parameters
    func updateParameters(_ parameters: InferenceParameters) {
        self.inferenceParameters = parameters
    }
    
    /// Add or remove a document from the active context
    func toggleDocumentContext(_ document: ProcessedDocument) {
        if let index = activeDocuments.firstIndex(where: { $0.id == document.id }) {
            activeDocuments.remove(at: index)
        } else {
            activeDocuments.append(document)
        }
    }
    
    /// Set active documents
    func setActiveDocuments(_ documents: [ProcessedDocument]) {
        activeDocuments = documents
    }
    
    /// Export chat session as JSON
    func exportSession() -> Data? {
        let session = ChatSession(
            id: UUID(),
            messages: messages,
            createdAt: Date(),
            lastModified: Date(),
            parameters: inferenceParameters,
            activeDocuments: activeDocuments
        )
        
        return try? JSONEncoder().encode(session)
    }
    
    /// Import chat session from JSON
    func importSession(from data: Data) throws {
        let session = try JSONDecoder().decode(ChatSession.self, from: data)
        messages = session.messages
        inferenceParameters = session.parameters
        activeDocuments = session.activeDocuments
    }
    
    // MARK: - Private Methods
    
    private func handleStreamingResponse(_ stream: AsyncThrowingStream<String, Error>) async {
        // Create assistant message placeholder
        let assistantMessage = ChatMessage(
            content: "",
            role: .assistant,
            metadata: MessageMetadata(
                modelUsed: currentInferenceEngine?.loadedModel?.displayName ?? "Unknown Model",
                documentReferences: activeDocuments.isEmpty ? nil : activeDocuments.map { $0.filename }
            )
        )
        
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1
        
        streamingTask = Task {
            var accumulatedContent = ""
            let startTime = Date()
            
            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    
                    accumulatedContent += token
                    
                    // Update the message content
                    await MainActor.run {
                        if messageIndex < messages.count {
                            messages[messageIndex] = ChatMessage(
                                id: messages[messageIndex].id,
                                content: accumulatedContent,
                                role: .assistant,
                                timestamp: messages[messageIndex].timestamp,
                                metadata: messages[messageIndex].metadata
                            )
                        }
                    }
                }
                
                // Finalize the message with complete metadata
                let inferenceTime = Date().timeIntervalSince(startTime)
                let tokenCount = estimateTokenCount(accumulatedContent)
                
                await MainActor.run {
                    if messageIndex < messages.count {
                        let finalMetadata = MessageMetadata(
                            modelUsed: currentInferenceEngine?.loadedModel?.displayName ?? "Unknown Model",
                            inferenceTime: inferenceTime,
                            tokenCount: tokenCount,
                            temperature: inferenceParameters.temperature,
                            maxTokens: inferenceParameters.maxTokens,
                            documentReferences: activeDocuments.isEmpty ? nil : activeDocuments.map { $0.filename }
                        )
                        
                        messages[messageIndex] = ChatMessage(
                            id: messages[messageIndex].id,
                            content: accumulatedContent,
                            role: .assistant,
                            timestamp: messages[messageIndex].timestamp,
                            metadata: finalMetadata
                        )
                    }
                    isProcessing = false
                }
                
            } catch {
                await handleInferenceError(error)
            }
        }
    }
    
    private func handleInferenceError(_ error: Error) async {
        isProcessing = false
        
        let errorMessage = if let manyLLMError = error as? ManyLLMError {
            manyLLMError.localizedDescription
        } else {
            "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        await addSystemMessage("Error: \(errorMessage)")
    }
    
    private func addSystemMessage(_ content: String) async {
        let systemMessage = ChatMessage(
            content: content,
            role: .system,
            metadata: MessageMetadata(
                modelUsed: "System"
            )
        )
        
        messages.append(systemMessage)
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: 1 token ≈ 4 characters for English text
        return max(1, text.count / 4)
    }
}

/// Represents a complete chat session
struct ChatSession: Codable, Identifiable {
    let id: UUID
    let messages: [ChatMessage]
    let createdAt: Date
    let lastModified: Date
    let parameters: InferenceParameters
    let activeDocuments: [ProcessedDocument]
    
    init(
        id: UUID = UUID(),
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        parameters: InferenceParameters = InferenceParameters(),
        activeDocuments: [ProcessedDocument] = []
    ) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.parameters = parameters
        self.activeDocuments = activeDocuments
    }
    
    /// Display name for the session
    var displayName: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let preview = String(firstUserMessage.content.prefix(50))
            return preview.count < firstUserMessage.content.count ? preview + "..." : preview
        }
        return "New Chat"
    }
    
    /// Duration of the chat session
    var duration: TimeInterval {
        return lastModified.timeIntervalSince(createdAt)
    }
    
    /// Number of messages in the session
    var messageCount: Int {
        return messages.count
    }
}