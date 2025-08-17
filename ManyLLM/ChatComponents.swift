import SwiftUI

// MARK: - Main Chat View

/// Main chat interface view that displays messages and handles user input
struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var systemPrompt = "Default"
    
    // Mock active documents for testing
    @State private var mockActiveDocuments: [String] = ["document.pdf", "notes.txt"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Mock Engine Configuration (for testing)
            if let mockEngine = chatManager.currentInferenceEngine as? MockInferenceEngine {
                MockEngineConfigView(mockEngine: mockEngine)
            }
            
            // Chat Messages Area
            if chatManager.messages.isEmpty {
                // Welcome State
                WelcomeView()
            } else {
                // Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatManager.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // Processing indicator with streaming support
                            if chatManager.isProcessing {
                                StreamingIndicatorView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatManager.messages.count) { _ in
                        // Auto-scroll to bottom when new message is added
                        if let lastMessage = chatManager.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // File Context Indicators (when documents are active)
            if !mockActiveDocuments.isEmpty {
                FileContextBar(documents: mockActiveDocuments)
            }
            
            // Bottom Input Area
            ChatInputView(
                messageText: $messageText,
                systemPrompt: $systemPrompt,
                isProcessing: .constant(chatManager.isProcessing),
                onSendMessage: sendMessage
            )
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: systemPrompt) { newPrompt in
            // Update inference parameters when system prompt changes
            var parameters = chatManager.inferenceParameters
            parameters.systemPrompt = getSystemPromptText(for: newPrompt)
            chatManager.updateParameters(parameters)
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !chatManager.isProcessing else { return }
        
        messageText = ""
        
        Task {
            await chatManager.sendMessage(trimmedText)
        }
    }
    
    private func getSystemPromptText(for preset: String) -> String {
        switch preset {
        case "Creative Writing":
            return "You are a creative writing assistant. Help users with storytelling, character development, and creative expression."
        case "Code Assistant":
            return "You are a helpful programming assistant. Provide clear, well-commented code examples and explain programming concepts."
        case "Research Helper":
            return "You are a research assistant. Help users analyze information, find sources, and organize their research."
        case "Technical Writer":
            return "You are a technical writing assistant. Help users create clear, concise documentation and technical content."
        case "Data Analyst":
            return "You are a data analysis assistant. Help users understand data, create visualizations, and draw insights."
        default:
            return "You are a helpful AI assistant. Provide accurate, helpful, and friendly responses."
        }
    }
}

// MARK: - Welcome View

/// Welcome state view displayed when no messages are present
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // ManyLLM Cat-bee Logo (creative SF Symbol combination)
            VStack(spacing: 16) {
                ZStack {
                    // Base circle for the cat face
                    Circle()
                        .fill(.orange.gradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Cat face elements
                    VStack(spacing: 4) {
                        // Cat ears (using triangular shapes)
                        HStack(spacing: 20) {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(45))
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(-45))
                        }
                        .offset(y: -8)
                        
                        // Cat face
                        VStack(spacing: 2) {
                            // Eyes
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.black)
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(.black)
                                    .frame(width: 4, height: 4)
                            }
                            
                            // Nose and mouth
                            VStack(spacing: 1) {
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.black)
                                
                                // Simple smile
                                Path { path in
                                    path.move(to: CGPoint(x: -6, y: 0))
                                    path.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: 4))
                                }
                                .stroke(.black, lineWidth: 1)
                                .frame(width: 12, height: 4)
                            }
                        }
                        .offset(y: -2)
                    }
                    
                    // Bee wings (subtle)
                    HStack(spacing: 60) {
                        Image(systemName: "oval.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .rotationEffect(.degrees(-20))
                        Image(systemName: "oval.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .rotationEffect(.degrees(20))
                    }
                    .offset(y: 5)
                    
                    // Bee stripes
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(.black)
                            .frame(width: 50, height: 3)
                        Rectangle()
                            .fill(.black)
                            .frame(width: 50, height: 3)
                    }
                    .offset(y: 10)
                }
                
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

// MARK: - Message Bubble View

/// Message bubble view that displays individual chat messages
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message content bubble
                MessageContentView(message: message)
                
                // Message metadata (timestamp, model info, etc.)
                MessageMetadataView(message: message)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

/// The main content bubble for a message
struct MessageContentView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Document references (if any)
            if message.hasDocumentReferences {
                DocumentReferencesView(references: message.metadata?.documentReferences ?? [])
            }
            
            // Message text
            Text(message.content)
                .font(.system(size: 14, design: .default))
                .foregroundColor(message.role == .user ? .white : .primary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleBackground)
        .cornerRadius(16, corners: bubbleCorners)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                Color.accentColor
            } else {
                Color(NSColor.controlBackgroundColor)
            }
        }
    }
    
    private var bubbleCorners: RectCorner {
        switch message.role {
        case .user:
            return [.topLeft, .topRight, .bottomLeft]
        case .assistant:
            return [.topLeft, .topRight, .bottomRight]
        case .system:
            return .allCorners
        }
    }
}

/// View showing document references within a message
struct DocumentReferencesView: View {
    let references: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("Referenced documents:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(references, id: \.self) { reference in
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        
                        Text(reference)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Metadata view showing timestamp and other message info
struct MessageMetadataView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(spacing: 8) {
            // Role indicator
            Text(message.role.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            // Timestamp
            Text(message.formattedTimestamp)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Model info (for assistant messages)
            if message.role == .assistant, let modelUsed = message.metadata?.modelUsed {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(modelUsed)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Inference time (for assistant messages)
            if message.role == .assistant, let inferenceTime = message.metadata?.inferenceTime {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1fs", inferenceTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Token count (for assistant messages)
            if message.role == .assistant, let tokenCount = message.metadata?.tokenCount {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("\(tokenCount) tokens")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Chat Input View

/// Bottom input area for typing messages and configuring system prompts
struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var systemPrompt: String
    @Binding var isProcessing: Bool
    
    let onSendMessage: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // System Prompt Dropdown
            HStack {
                Text("System Prompt:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Menu {
                    Button("Default") { systemPrompt = "Default" }
                    Button("Creative Writing") { systemPrompt = "Creative Writing" }
                    Button("Code Assistant") { systemPrompt = "Code Assistant" }
                    Button("Research Helper") { systemPrompt = "Research Helper" }
                    Button("Technical Writer") { systemPrompt = "Technical Writer" }
                    Button("Data Analyst") { systemPrompt = "Data Analyst" }
                } label: {
                    HStack {
                        Text(systemPrompt)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Message Input Field with Send Button
            HStack(alignment: .bottom, spacing: 8) {
                // Text input field
                ZStack(alignment: .topLeading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isTextFieldFocused ? Color.accentColor : Color(NSColor.separatorColor),
                                    lineWidth: isTextFieldFocused ? 2 : 1
                                )
                        )
                    
                    // Text editor
                    TextEditor(text: $messageText)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSendMessage()
                            }
                        }
                    
                    // Placeholder text
                    if messageText.isEmpty {
                        Text("Type your message here...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 44, maxHeight: 120)
                
                // Send button
                Button(action: onSendMessage) {
                    Image(systemName: isProcessing ? "stop.circle.fill" : "paperplane.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(sendButtonBackground)
                .cornerRadius(12)
                .disabled(shouldDisableSendButton)
                .animation(.easeInOut(duration: 0.2), value: isProcessing)
            }
            
            // Input hints
            if messageText.isEmpty && !isProcessing {
                HStack(spacing: 16) {
                    InputHint(icon: "command", text: "⌘ + Enter to send")
                    InputHint(icon: "doc.text", text: "Drag files to add context")
                    InputHint(icon: "gear", text: "Adjust parameters above")
                }
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
        .onAppear {
            // Focus the text field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var sendButtonBackground: some View {
        Group {
            if isProcessing {
                Color.red
            } else if shouldDisableSendButton {
                Color.secondary.opacity(0.3)
            } else {
                Color.accentColor
            }
        }
    }
    
    private var shouldDisableSendButton: Bool {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }
}

// MARK: - Supporting Views

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

/// Enhanced streaming indicator for mock engine demonstration
struct StreamingIndicatorView: View {
    @State private var animationPhase = 0
    @State private var showTyping = true
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                // Typing animation
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.accentColor)
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
                
                Text("AI is thinking...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .opacity(showTyping ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showTyping)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(16)
            
            Spacer()
        }
        .onAppear {
            withAnimation {
                animationPhase = 2
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                showTyping.toggle()
            }
        }
    }
}

/// Small hint text with icon
struct InputHint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Custom Corner Support

/// Custom corner specification for SwiftUI
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// Extension to support custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Custom shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        
        // Top edge and top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight,
                       startAngle: Angle(degrees: -90),
                       endAngle: Angle(degrees: 0),
                       clockwise: false)
        }
        
        // Right edge and bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight,
                       startAngle: Angle(degrees: 0),
                       endAngle: Angle(degrees: 90),
                       clockwise: false)
        }
        
        // Bottom edge and bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft,
                       startAngle: Angle(degrees: 90),
                       endAngle: Angle(degrees: 180),
                       clockwise: false)
        }
        
        // Left edge and top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft,
                       startAngle: Angle(degrees: 180),
                       endAngle: Angle(degrees: 270),
                       clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}
/// Co
nfiguration panel for MockInferenceEngine (development/testing only)
struct MockEngineConfigView: View {
    let mockEngine: MockInferenceEngine
    @State private var isExpanded = false
    @State private var responseDelay: Double
    @State private var streamingDelay: Double
    @State private var shouldSimulateErrors: Bool
    @State private var errorProbability: Double
    
    init(mockEngine: MockInferenceEngine) {
        self.mockEngine = mockEngine
        self._responseDelay = State(initialValue: mockEngine.responseDelay)
        self._streamingDelay = State(initialValue: mockEngine.streamingTokenDelay)
        self._shouldSimulateErrors = State(initialValue: mockEngine.shouldSimulateErrors)
        self._errorProbability = State(initialValue: mockEngine.errorProbability)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Mock Engine Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(Color.orange.opacity(0.1))
            
            // Configuration Panel
            if isExpanded {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Response Delay")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Slider(value: $responseDelay, in: 0.1...5.0, step: 0.1)
                                    .frame(width: 100)
                                
                                Text("\(responseDelay, specifier: "%.1f")s")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Streaming Delay")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Slider(value: $streamingDelay, in: 0.01...0.5, step: 0.01)
                                    .frame(width: 100)
                                
                                Text("\(streamingDelay, specifier: "%.2f")s")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    
                    HStack {
                        Toggle("Simulate Errors", isOn: $shouldSimulateErrors)
                            .font(.system(size: 11))
                        
                        Spacer()
                        
                        if shouldSimulateErrors {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Error Rate")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Slider(value: $errorProbability, in: 0.0...1.0, step: 0.1)
                                        .frame(width: 80)
                                    
                                    Text("\(Int(errorProbability * 100))%")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                        }
                    }
                    
                    // Quick Actions
                    HStack(spacing: 8) {
                        Button("Fast Mode") {
                            responseDelay = 0.2
                            streamingDelay = 0.01
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button("Realistic Mode") {
                            responseDelay = 1.0
                            streamingDelay = 0.05
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button("Slow Mode") {
                            responseDelay = 3.0
                            streamingDelay = 0.2
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Spacer()
                        
                        Button("Apply Settings") {
                            applySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    private func applySettings() {
        mockEngine.responseDelay = responseDelay
        mockEngine.streamingTokenDelay = streamingDelay
        mockEngine.shouldSimulateErrors = shouldSimulateErrors
        mockEngine.errorProbability = errorProbability
    }
}