import SwiftUI

/// Main chat interface view that displays messages and handles user input
struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isProcessing = false
    @State private var systemPrompt = "Default"
    
    // File context state
    @State private var activeDocuments: [String] = ["document.pdf", "notes.txt"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages Area
            if messages.isEmpty {
                // Welcome State
                WelcomeView()
            } else {
                // Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // Processing indicator
                            if isProcessing {
                                ProcessingIndicatorView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _ in
                        // Auto-scroll to bottom when new message is added
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // File Context Indicators (when documents are active)
            if !activeDocuments.isEmpty {
                FileContextBar(documents: activeDocuments)
            }
            
            // Bottom Input Area
            ChatInputView(
                messageText: $messageText,
                systemPrompt: $systemPrompt,
                isProcessing: $isProcessing,
                onSendMessage: sendMessage
            )
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !isProcessing else { return }
        
        // Create user message
        let userMessage = ChatMessage(
            content: trimmedText,
            role: .user,
            metadata: activeDocuments.isEmpty ? nil : MessageMetadata(
                documentReferences: activeDocuments
            )
        )
        
        messages.append(userMessage)
        messageText = ""
        isProcessing = true
        
        // Simulate assistant response (will be replaced with actual inference)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let assistantMessage = ChatMessage(
                content: generateMockResponse(for: trimmedText),
                role: .assistant,
                metadata: MessageMetadata(
                    modelUsed: "Mock Model",
                    inferenceTime: 1.2,
                    tokenCount: 45,
                    documentReferences: activeDocuments.isEmpty ? nil : activeDocuments
                )
            )
            
            messages.append(assistantMessage)
            isProcessing = false
        }
    }
    
    private func generateMockResponse(for input: String) -> String {
        let responses = [
            "I understand your question about \"\(input)\". This is a mock response that will be replaced with actual AI inference in a future implementation.",
            "Thank you for your message. I'm currently running in preview mode, so this is a simulated response to demonstrate the chat interface.",
            "Based on your input \"\(input)\", I would provide a helpful response here. This interface is ready for integration with the actual inference engine."
        ]
        return responses.randomElement() ?? "Mock response"
    }
}

/// Welcome state view displayed when no messages are present
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // ManyLLM Cat-bee Logo (placeholder with SF Symbol)
            VStack(spacing: 16) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 8) {
                    Text("Welcome to ManyLLM Preview")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Your private, local AI assistant")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Getting started hints
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    
                    Text("Start a conversation by typing a message below")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    
                    Text("Upload documents to chat with your files")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    
                    Text("All processing happens locally on your Mac")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// File context indicator bar showing active documents
struct FileContextBar: View {
    let documents: [String]
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                
                Text("Context:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(documents, id: \.self) { document in
                        DocumentChip(name: document)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
            
            Text("\(documents.count) file\(documents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.05))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

/// Small chip showing a document name
struct DocumentChip: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: fileIcon(for: name))
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "txt":
            return "doc.text"
        case "csv":
            return "tablecells"
        case "docx", "doc":
            return "doc"
        default:
            return "doc"
        }
    }
}

/// Processing indicator shown while waiting for response
struct ProcessingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
            
            Spacer()
        }
        .onAppear {
            withAnimation {
                animationPhase = 2
            }
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 600, height: 400)
}