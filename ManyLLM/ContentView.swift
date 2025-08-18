import SwiftUI

struct ContentView: View {
    @State private var sidebarCollapsed = false
    @State private var workspacesExpanded = true
    @State private var filesExpanded = true
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Double = 600
    
    // Model management state
    @State private var currentModel: String = "No Model"
    @State private var modelStatus: ModelStatus = .unloaded
    @State private var isLoadingModel = false
    @State private var loadingProgress: Double = 0.0
    @State private var showingModelBrowser = false
    @State private var availableModels: [MockModelInfo] = []
    @State private var errorMessage: String?
    @State private var showingError = false

    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            if !sidebarCollapsed {
                VStack(spacing: 0) {
                    // Workspaces Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: { workspacesExpanded.toggle() }) {
                                Image(systemName: workspacesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("Workspaces")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        
                        if workspacesExpanded {
                            VStack(alignment: .leading, spacing: 4) {
                                WorkspaceItem(name: "Current Chat", isSelected: true)
                                WorkspaceItem(name: "Research Project", isSelected: false)
                                WorkspaceItem(name: "Code Review", isSelected: false)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Files Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: { filesExpanded.toggle() }) {
                                Image(systemName: filesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("Files")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("2 of 3 files in context")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        
                        if filesExpanded {
                            VStack(alignment: .leading, spacing: 4) {
                                FileItem(name: "document.pdf", size: "2.3 MB", hasContext: true)
                                FileItem(name: "notes.txt", size: "45 KB", hasContext: true)
                                FileItem(name: "data.csv", size: "1.1 MB", hasContext: false)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Toolbar
                HStack(spacing: 16) {
                    // ManyLLM Logo/Brand
                    HStack(spacing: 8) {
                        // Cat-bee logo (compact version)
                        ZStack {
                            Circle()
                                .fill(.orange.gradient)
                                .frame(width: 20, height: 20)
                            
                            // Simple cat face
                            VStack(spacing: 1) {
                                // Ears
                                HStack(spacing: 4) {
                                    Circle().fill(.white).frame(width: 2, height: 2)
                                    Circle().fill(.white).frame(width: 2, height: 2)
                                }
                                .offset(y: -2)
                                
                                // Eyes and nose
                                VStack(spacing: 0.5) {
                                    HStack(spacing: 2) {
                                        Circle().fill(.black).frame(width: 1.5, height: 1.5)
                                        Circle().fill(.black).frame(width: 1.5, height: 1.5)
                                    }
                                    Circle().fill(.black).frame(width: 1, height: 1)
                                }
                                .offset(y: -1)
                            }
                            
                            // Bee stripes
                            VStack(spacing: 2) {
                                Rectangle().fill(.black).frame(width: 12, height: 1)
                                Rectangle().fill(.black).frame(width: 12, height: 1)
                            }
                            .offset(y: 2)
                        }
                        
                        Text("ManyLLM")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Model Dropdown
                    ModelDropdownView(
                        currentModel: $currentModel,
                        modelStatus: $modelStatus,
                        isLoadingModel: $isLoadingModel,
                        loadingProgress: $loadingProgress,
                        showingModelBrowser: $showingModelBrowser,
                        onModelAction: handleModelAction
                    )
                    
                    // Temperature Slider
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temperature")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $temperature, in: 0...2.0, step: 0.1)
                                .frame(width: 80)
                            Text(String(format: "%.1f", temperature))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    
                    // Max Tokens Slider
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Tokens")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $maxTokens, in: 1...2048, step: 1)
                                .frame(width: 80)
                            Text("\(Int(maxTokens))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    // Settings Gear
                    Menu {
                        Button("Preferences") { }
                        Divider()
                        Button("About MLX Integration") { 
                            print("🧪 MLX Integration Status:")
                            if #available(macOS 13.0, *) {
                                print("✓ macOS 13.0+ available for MLX")
                                print("✓ MLX inference engine implemented")
                                print("✓ Engine manager created for switching between engines")
                                print("✓ Integration tests created")
                                print("ℹ️ MLX integration is ready for testing with real models")
                            } else {
                                print("⚠️ macOS 13.0+ required for MLX")
                            }
                        }
                        Button("About ManyLLM") { }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Start Button
                    Button("Start") {
                        // TODO: Implement start functionality
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor)),
                    alignment: .bottom
                )
                
                // Chat Interface
                ChatView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { sidebarCollapsed.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
            }
        }

    }
    
    // MARK: - Model Management Methods
    
    private func handleModelAction(_ action: ModelAction) {
        Task {
            switch action {
            case .loadModel(let modelName):
                await loadModel(modelName)
            case .unloadModel:
                await unloadModel()
            case .showBrowser:
                showingModelBrowser = true
            case .refreshModels:
                await refreshAvailableModels()
            }
        }
    }
    
    private func loadModel(_ modelName: String) async {
        await MainActor.run {
            isLoadingModel = true
            loadingProgress = 0.0
            modelStatus = .loading
        }
        
        // Simulate model loading with progress
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            await MainActor.run {
                loadingProgress = Double(i) / 10.0
            }
        }
        
        await MainActor.run {
            currentModel = modelName
            modelStatus = .loaded
            isLoadingModel = false
            loadingProgress = 0.0
        }
    }
    
    private func unloadModel() async {
        await MainActor.run {
            currentModel = "No Model"
            modelStatus = .unloaded
            isLoadingModel = false
            loadingProgress = 0.0
        }
    }
    
    private func refreshAvailableModels() async {
        // Simulate fetching models
        await MainActor.run {
            availableModels = createMockModels()
        }
    }
    
    private func createMockModels() -> [MockModelInfo] {
        return [
            MockModelInfo(name: "Llama 3 8B", size: "4.6 GB", status: .available),
            MockModelInfo(name: "Mistral 7B", size: "3.8 GB", status: .available),
            MockModelInfo(name: "CodeLlama 7B", size: "3.8 GB", status: .downloaded),
            MockModelInfo(name: "Llama 3 70B", size: "38 GB", status: .available)
        ]
    }
}

// MARK: - Model Management Components

/// Model dropdown component for the top toolbar
struct ModelDropdownView: View {
    @Binding var currentModel: String
    @Binding var modelStatus: ModelStatus
    @Binding var isLoadingModel: Bool
    @Binding var loadingProgress: Double
    @Binding var showingModelBrowser: Bool
    let onModelAction: (ModelAction) -> Void
    
    var body: some View {
        Menu {
            // Current model section
            if modelStatus == .loaded {
                Section("Current Model") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(currentModel)
                        Spacer()
                        Text("Loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                Button("Unload Model") {
                    onModelAction(.unloadModel)
                }
            } else {
                Section("No Model Loaded") {
                    Text("Select a model to get started")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Quick model selection
            Section("Available Models") {
                Button("Llama 3 8B") {
                    onModelAction(.loadModel("Llama 3 8B"))
                }
                
                Button("Mistral 7B") {
                    onModelAction(.loadModel("Mistral 7B"))
                }
                
                Button("CodeLlama 7B") {
                    onModelAction(.loadModel("CodeLlama 7B"))
                }
            }
            
            Divider()
            
            // Model browser and actions
            Button("Browse Models...") {
                onModelAction(.showBrowser)
            }
            
            Button("Refresh Models") {
                onModelAction(.refreshModels)
            }
            
        } label: {
            HStack(spacing: 8) {
                // Model status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Model name or loading state
                if isLoadingModel {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading...")
                            .font(.system(size: 13))
                    }
                } else {
                    Text(currentModel)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                // Loading progress bar
                loadingProgressOverlay,
                alignment: .bottom
            )
        }
        .sheet(isPresented: $showingModelBrowser) {
            ModelBrowserSheet(
                availableModels: createMockModels(),
                onModelSelected: { modelName in
                    onModelAction(.loadModel(modelName))
                    showingModelBrowser = false
                }
            )
        }
    }
    
    private var statusColor: Color {
        switch modelStatus {
        case .unloaded:
            return .secondary
        case .loading:
            return .orange
        case .loaded:
            return .green
        case .error:
            return .red
        }
    }
    
    @ViewBuilder
    private var loadingProgressOverlay: some View {
        if isLoadingModel && loadingProgress > 0 {
            GeometryReader { geometry in
                Rectangle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: geometry.size.width * loadingProgress, height: 2)
                    .animation(.easeInOut(duration: 0.2), value: loadingProgress)
            }
            .frame(height: 2)
        }
    }
    
    private func createMockModels() -> [MockModelInfo] {
        return [
            MockModelInfo(name: "Llama 3 8B", size: "4.6 GB", status: .available),
            MockModelInfo(name: "Mistral 7B", size: "3.8 GB", status: .available),
            MockModelInfo(name: "CodeLlama 7B", size: "3.8 GB", status: .downloaded),
            MockModelInfo(name: "Llama 3 70B", size: "38 GB", status: .available)
        ]
    }
}

/// Simple model browser sheet
struct ModelBrowserSheet: View {
    let availableModels: [MockModelInfo]
    let onModelSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableModels, id: \.name) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                        
                        Text(model.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(model.status == .downloaded ? "Load" : "Download") {
                        if model.status == .downloaded {
                            onModelSelected(model.name)
                        } else {
                            // TODO: Implement download
                            onModelSelected(model.name)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Model Browser")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Supporting Types

enum ModelStatus {
    case unloaded
    case loading
    case loaded
    case error
}

enum ModelAction {
    case loadModel(String)
    case unloadModel
    case showBrowser
    case refreshModels
}

struct MockModelInfo {
    let name: String
    let size: String
    let status: MockModelStatus
}

enum MockModelStatus {
    case available
    case downloaded
    case loading
}

#Preview {
    ContentView()
}
// MARK: - Supporting Views

struct WorkspaceItem: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Handle workspace selection
        }
    }
}

struct FileItem: View {
    let name: String
    let size: String
    let hasContext: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: name))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(size)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasContext {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Handle file selection
        }
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

// MARK: - Chat Interface Components

// Simple message structure for demo purposes
struct SimpleChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

/// Main chat interface view that displays messages and handles user input
struct ChatView: View {
    @State private var messages: [SimpleChatMessage] = []
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
                                SimpleMessageBubbleView(message: message)
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
        let userMessage = SimpleChatMessage(
            content: trimmedText,
            isUser: true
        )
        
        messages.append(userMessage)
        messageText = ""
        isProcessing = true
        
        // Simulate assistant response (will be replaced with actual inference)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let assistantMessage = SimpleChatMessage(
                content: generateMockResponse(for: trimmedText),
                isUser: false
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

/// Processing indicator view shown while generating responses
struct ProcessingIndicatorView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Assistant avatar space
            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                )
            
            // Typing indicator
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationPhase == Double(index) ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: animationPhase
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
                
                Text("Assistant is thinking...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animationPhase = 0.0
        }
    }
}

/// Simplified message bubble view for demo
struct SimpleMessageBubbleView: View {
    let message: SimpleChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Message content bubble
                Text(message.content)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(16, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Simple timestamp
                HStack(spacing: 8) {
                    Text(message.isUser ? "You" : "Assistant")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}



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