import SwiftUI
import Foundation
import PDFKit
import UniformTypeIdentifiers
import NaturalLanguage

// MARK: - Document Processing Classes

/// A chunk of text from a processed document
struct DocumentChunk: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let startIndex: Int
    let endIndex: Int
    let pageNumber: Int?
    let embeddings: [Float]?
    
    init(
        id: UUID = UUID(),
        content: String,
        startIndex: Int,
        endIndex: Int,
        pageNumber: Int? = nil,
        embeddings: [Float]? = nil
    ) {
        self.id = id
        self.content = content
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.pageNumber = pageNumber
        self.embeddings = embeddings
    }
    
    /// Length of the chunk content
    var length: Int {
        return content.count
    }
    
    /// Whether this chunk has embeddings
    var hasEmbeddings: Bool {
        return embeddings != nil && !embeddings!.isEmpty
    }
}

/// Metadata associated with a processed document
struct DocumentMetadata: Codable, Equatable {
    let title: String?
    let author: String?
    let subject: String?
    let keywords: [String]?
    let creationDate: Date?
    let modificationDate: Date?
    let pageCount: Int?
    let language: String?
    let processingDuration: TimeInterval?
    let extractionMethod: String?
    
    init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String]? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        pageCount: Int? = nil,
        language: String? = nil,
        processingDuration: TimeInterval? = nil,
        extractionMethod: String? = nil
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.pageCount = pageCount
        self.language = language
        self.processingDuration = processingDuration
        self.extractionMethod = extractionMethod
    }
}

/// A document that has been processed for text extraction and embedding
struct ProcessedDocument: Codable, Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    let filename: String
    let fileSize: Int64
    let mimeType: String
    let content: String
    let chunks: [DocumentChunk]
    let metadata: DocumentMetadata
    let processedAt: Date
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        filename: String,
        fileSize: Int64,
        mimeType: String,
        content: String,
        chunks: [DocumentChunk] = [],
        metadata: DocumentMetadata,
        processedAt: Date = Date(),
        isActive: Bool = false
    ) {
        self.id = id
        self.originalURL = originalURL
        self.filename = filename
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.content = content
        self.chunks = chunks
        self.metadata = metadata
        self.processedAt = processedAt
        self.isActive = isActive
    }
    
    /// Human-readable file size
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// File extension from filename
    var fileExtension: String {
        return (filename as NSString).pathExtension.lowercased()
    }
    
    /// Number of chunks in the document
    var chunkCount: Int {
        return chunks.count
    }
    
    /// Whether the document has been chunked
    var isChunked: Bool {
        return !chunks.isEmpty
    }
    
    /// Whether all chunks have embeddings
    var hasEmbeddings: Bool {
        return !chunks.isEmpty && chunks.allSatisfy { $0.hasEmbeddings }
    }
    
    /// Total character count
    var characterCount: Int {
        return content.count
    }
    
    /// Estimated word count
    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

/// Manages document upload, processing, and state for the application
@MainActor
class DocumentManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var documents: [ProcessedDocument] = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus: String = ""
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    // MARK: - Computed Properties
    
    var activeDocuments: [ProcessedDocument] {
        return documents.filter { $0.isActive }
    }
    
    var activeDocumentCount: Int {
        return activeDocuments.count
    }
    
    var totalDocumentCount: Int {
        return documents.count
    }
    
    var contextSummary: String {
        if totalDocumentCount == 0 {
            return "No files"
        } else if activeDocumentCount == totalDocumentCount {
            return "\(totalDocumentCount) file\(totalDocumentCount == 1 ? "" : "s") in context"
        } else {
            return "\(activeDocumentCount) of \(totalDocumentCount) file\(totalDocumentCount == 1 ? "" : "s") in context"
        }
    }
    
    // MARK: - Document Management
    
    /// Toggle document active state for context inclusion
    func toggleDocumentActive(_ document: ProcessedDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].isActive.toggle()
        }
    }
    
    /// Remove a document from the collection
    func removeDocument(_ document: ProcessedDocument) {
        documents.removeAll { $0.id == document.id }
    }
    
    /// Remove all documents
    func removeAllDocuments() {
        documents.removeAll()
    }
    
    /// Get active document content for context
    func getActiveDocumentContext() -> String {
        let activeContent = activeDocuments.map { document in
            "Document: \(document.filename)\n\(document.content)\n"
        }.joined(separator: "\n---\n\n")
        
        return activeContent
    }
    
    /// Add mock documents for testing
    func addMockDocuments() {
        let mockDocuments = [
            ProcessedDocument(
                originalURL: URL(fileURLWithPath: "/tmp/document.pdf"),
                filename: "document.pdf",
                fileSize: 2_400_000,
                mimeType: "application/pdf",
                content: "This is a sample PDF document content for testing purposes.",
                chunks: [],
                metadata: DocumentMetadata(
                    title: "Sample Document",
                    pageCount: 5
                ),
                isActive: true
            ),
            ProcessedDocument(
                originalURL: URL(fileURLWithPath: "/tmp/notes.txt"),
                filename: "notes.txt",
                fileSize: 45_000,
                mimeType: "text/plain",
                content: "These are sample notes for testing the document processing functionality.",
                chunks: [],
                metadata: DocumentMetadata(
                    title: "Notes"
                ),
                isActive: true
            ),
            ProcessedDocument(
                originalURL: URL(fileURLWithPath: "/tmp/data.csv"),
                filename: "data.csv",
                fileSize: 1_100_000,
                mimeType: "text/csv",
                content: "Sample CSV data with headers and rows for testing purposes.",
                chunks: [],
                metadata: DocumentMetadata(
                    title: "Data"
                ),
                isActive: false
            )
        ]
        
        documents.append(contentsOf: mockDocuments)
    }
}

/// Enhanced Files section view with drag-and-drop support and document management
struct FilesView: View {
    @ObservedObject var documentManager: DocumentManager
    @Binding var isExpanded: Bool
    
    @State private var isDragOver = false
    @State private var showingFilePicker = false
    @State private var showingDocumentDetails: ProcessedDocument?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            FilesHeaderView(
                isExpanded: $isExpanded,
                contextSummary: documentManager.contextSummary,
                onAddFiles: { showingFilePicker = true },
                onClearAll: { documentManager.removeAllDocuments() },
                hasDocuments: !documentManager.documents.isEmpty
            )
            
            if isExpanded {
                // Document list or empty state
                if documentManager.documents.isEmpty && !documentManager.isProcessing {
                    EmptyFilesView(
                        onAddFiles: { showingFilePicker = true }
                    )
                } else {
                    DocumentListView(
                        documents: documentManager.documents,
                        onToggleActive: documentManager.toggleDocumentActive,
                        onRemove: documentManager.removeDocument,
                        onShowDetails: { document in
                            showingDocumentDetails = document
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .background(
            // Drag and drop background
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isDragOver ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                        .animation(.easeInOut(duration: 0.2), value: isDragOver)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            // For now, just show that files were dropped
            print("Files dropped: \(providers.count)")
            return true
        }
        .sheet(item: $showingDocumentDetails) { document in
            DocumentDetailSheet(document: document)
        }
    }
}

/// Files section header with controls
struct FilesHeaderView: View {
    @Binding var isExpanded: Bool
    let contextSummary: String
    let onAddFiles: () -> Void
    let onClearAll: () -> Void
    let hasDocuments: Bool
    
    var body: some View {
        HStack {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Text("Files")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(contextSummary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Add files button
            Menu {
                Button("Add Files...") {
                    onAddFiles()
                }
                
                if hasDocuments {
                    Divider()
                    
                    Button("Clear All") {
                        onClearAll()
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Empty state view for files section
struct EmptyFilesView: View {
    let onAddFiles: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No documents")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Drag files here or click + to add")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Text("Supports: PDF, TXT, CSV, DOCX")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Add Files") {
                onAddFiles()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

/// List of documents
struct DocumentListView: View {
    let documents: [ProcessedDocument]
    let onToggleActive: (ProcessedDocument) -> Void
    let onRemove: (ProcessedDocument) -> Void
    let onShowDetails: (ProcessedDocument) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(documents) { document in
                DocumentItemView(
                    document: document,
                    onToggleActive: { onToggleActive(document) },
                    onRemove: { onRemove(document) },
                    onShowDetails: { onShowDetails(document) }
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Individual document item view
struct DocumentItemView: View {
    let document: ProcessedDocument
    let onToggleActive: () -> Void
    let onRemove: () -> Void
    let onShowDetails: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileIcon(for: document.filename))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            // File info
            VStack(alignment: .leading, spacing: 1) {
                Text(document.filename)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(document.fileSizeString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if document.isChunked {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        
                        Text("\(document.chunkCount) chunks")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Context indicator and controls
            HStack(spacing: 6) {
                // Context eye icon
                Button(action: onToggleActive) {
                    Image(systemName: document.isActive ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10))
                        .foregroundColor(document.isActive ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(document.isActive ? "Remove from context" : "Add to context")
                
                // More options (shown on hover)
                if isHovered {
                    Menu {
                        Button("View Details") {
                            onShowDetails()
                        }
                        
                        Button(document.isActive ? "Remove from Context" : "Add to Context") {
                            onToggleActive()
                        }
                        
                        Divider()
                        
                        Button("Remove") {
                            onRemove()
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(document.isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onToggleActive()
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

/// Document detail sheet
struct DocumentDetailSheet: View {
    let document: ProcessedDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: fileIcon(for: document.filename))
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.filename)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(document.fileSizeString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if let title = document.metadata.title, title != document.filename {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Content preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Preview")
                            .font(.headline)
                        
                        ScrollView {
                            Text(String(document.content.prefix(1000)) + (document.content.count > 1000 ? "..." : ""))
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Document Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
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

// MARK: - Core Data Models

/// Parameters for controlling model inference behavior
struct InferenceParameters: Codable, Equatable {
    var temperature: Float
    var maxTokens: Int
    var topP: Float
    var topK: Int?
    var systemPrompt: String
    var stopSequences: [String]
    var repeatPenalty: Float?
    var seed: Int?
    
    init(
        temperature: Float = 0.7,
        maxTokens: Int = 2048,
        topP: Float = 0.9,
        topK: Int? = nil,
        systemPrompt: String = "",
        stopSequences: [String] = [],
        repeatPenalty: Float? = nil,
        seed: Int? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.systemPrompt = systemPrompt
        self.stopSequences = stopSequences
        self.repeatPenalty = repeatPenalty
        self.seed = seed
    }
    
    /// Validate parameter values and return any validation errors
    func validate() throws {
        if temperature < 0.0 || temperature > 2.0 {
            throw ManyLLMError.validationError("Temperature must be between 0.0 and 2.0")
        }
        
        if maxTokens < 1 || maxTokens > 32768 {
            throw ManyLLMError.validationError("Max tokens must be between 1 and 32768")
        }
        
        if topP < 0.0 || topP > 1.0 {
            throw ManyLLMError.validationError("Top-p must be between 0.0 and 1.0")
        }
        
        if let topK = topK, topK < 1 {
            throw ManyLLMError.validationError("Top-k must be greater than 0")
        }
        
        if let repeatPenalty = repeatPenalty, repeatPenalty < 0.0 {
            throw ManyLLMError.validationError("Repeat penalty must be non-negative")
        }
    }
    
    /// Create a copy with modified temperature
    func withTemperature(_ temperature: Float) -> InferenceParameters {
        var copy = self
        copy.temperature = temperature
        return copy
    }
    
    /// Create a copy with modified max tokens
    func withMaxTokens(_ maxTokens: Int) -> InferenceParameters {
        var copy = self
        copy.maxTokens = maxTokens
        return copy
    }
    
    /// Create a copy with modified system prompt
    func withSystemPrompt(_ systemPrompt: String) -> InferenceParameters {
        var copy = self
        copy.systemPrompt = systemPrompt
        return copy
    }
    
    /// Default parameters for different use cases
    static let `default` = InferenceParameters()
    
    static let creative = InferenceParameters(
        temperature: 1.0,
        maxTokens: 2048,
        topP: 0.95
    )
    
    static let precise = InferenceParameters(
        temperature: 0.1,
        maxTokens: 1024,
        topP: 0.8
    )
    
    static let balanced = InferenceParameters(
        temperature: 0.7,
        maxTokens: 2048,
        topP: 0.9
    )
}

/// Comprehensive error types for the ManyLLM application
enum ManyLLMError: LocalizedError, Equatable {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case inferenceError(String)
    case documentProcessingFailed(String)
    case networkError(String)
    case storageError(String)
    case apiServerError(String)
    case validationError(String)
    case insufficientResources(String)
    case unsupportedFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' could not be found"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .inferenceError(let reason):
            return "Inference failed: \(reason)"
        case .documentProcessingFailed(let reason):
            return "Document processing failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .apiServerError(let reason):
            return "API server error: \(reason)"
        case .validationError(let reason):
            return "Validation error: \(reason)"
        case .insufficientResources(let reason):
            return "Insufficient resources: \(reason)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotFound:
            return "Please check that the model exists and try again, or download the model from the model browser."
        case .modelLoadFailed:
            return "Try restarting the application or freeing up system memory before loading the model."
        case .inferenceError:
            return "Check your input parameters and try again. If the problem persists, try reloading the model."
        case .documentProcessingFailed:
            return "Ensure the document is not corrupted and is in a supported format (PDF, DOCX, TXT, CSV)."
        case .networkError:
            return "Check your internet connection and try again."
        case .storageError:
            return "Check available disk space and file permissions."
        case .apiServerError:
            return "Check API server configuration and try restarting the server."
        case .validationError:
            return "Please correct the input and try again."
        case .insufficientResources:
            return "Close other applications or try using a smaller model to free up system resources."
        case .unsupportedFormat:
            return "Please use a supported file format (PDF, DOCX, TXT, CSV)."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .modelNotFound:
            return "The specified model could not be located in the local storage or remote repository."
        case .modelLoadFailed:
            return "The model could not be loaded into memory, possibly due to insufficient resources or corruption."
        case .inferenceError:
            return "The model failed to generate a response, possibly due to invalid parameters or model state."
        case .documentProcessingFailed:
            return "The document could not be processed for text extraction or embedding generation."
        case .networkError:
            return "A network operation failed, preventing communication with remote services."
        case .storageError:
            return "A file system operation failed, preventing data persistence or retrieval."
        case .apiServerError:
            return "The API server encountered an error while processing a request."
        case .validationError:
            return "Input validation failed due to invalid or missing required data."
        case .insufficientResources:
            return "The system does not have enough memory or processing power to complete the operation."
        case .unsupportedFormat:
            return "The file format is not supported by the current document processing pipeline."
        }
    }
}

// MARK: - Parameter Management Classes

/// Manages inference parameters with validation and real-time updates
@MainActor
class ParameterManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var parameters = InferenceParameters()
    @Published var validationErrors: [String] = []
    @Published var hasValidationErrors: Bool = false
    
    // MARK: - System Prompt Presets
    
    static let systemPromptPresets: [SystemPromptPreset] = [
        SystemPromptPreset(
            name: "Default",
            prompt: "",
            description: "No system prompt - use model's default behavior"
        ),
        SystemPromptPreset(
            name: "Helpful Assistant",
            prompt: "You are a helpful, harmless, and honest AI assistant. Provide clear, accurate, and useful responses.",
            description: "General purpose helpful assistant"
        ),
        SystemPromptPreset(
            name: "Code Assistant",
            prompt: "You are an expert programmer and code reviewer. Provide clear, well-documented code examples and explanations. Focus on best practices, security, and maintainability.",
            description: "Specialized for programming tasks"
        ),
        SystemPromptPreset(
            name: "Research Assistant",
            prompt: "You are a research assistant. Provide thorough, well-sourced information. When uncertain, clearly state limitations and suggest further research directions.",
            description: "Focused on research and analysis"
        ),
        SystemPromptPreset(
            name: "Creative Writer",
            prompt: "You are a creative writing assistant. Help with storytelling, character development, and creative expression. Be imaginative while maintaining coherence.",
            description: "For creative writing tasks"
        ),
        SystemPromptPreset(
            name: "Technical Writer",
            prompt: "You are a technical writing expert. Create clear, concise documentation and explanations. Use appropriate technical terminology while remaining accessible.",
            description: "For technical documentation"
        )
    ]
    
    @Published var selectedPresetName: String = "Default"
    
    // MARK: - Parameter Ranges and Validation
    
    static let temperatureRange: ClosedRange<Float> = 0.0...2.0
    static let maxTokensRange: ClosedRange<Int> = 1...8192
    static let topPRange: ClosedRange<Float> = 0.0...1.0
    
    // MARK: - Initialization
    
    init() {
        validateParameters()
    }
    
    // MARK: - Parameter Updates
    
    /// Update temperature with validation
    func updateTemperature(_ temperature: Float) {
        let clampedValue = max(Self.temperatureRange.lowerBound, 
                              min(Self.temperatureRange.upperBound, temperature))
        parameters.temperature = clampedValue
        validateParameters()
    }
    
    /// Update max tokens with validation
    func updateMaxTokens(_ maxTokens: Int) {
        let clampedValue = max(Self.maxTokensRange.lowerBound,
                              min(Self.maxTokensRange.upperBound, maxTokens))
        parameters.maxTokens = clampedValue
        validateParameters()
    }
    
    /// Update top-p with validation
    func updateTopP(_ topP: Float) {
        let clampedValue = max(Self.topPRange.lowerBound,
                              min(Self.topPRange.upperBound, topP))
        parameters.topP = clampedValue
        validateParameters()
    }
    
    /// Update system prompt from preset
    func selectSystemPromptPreset(_ presetName: String) {
        selectedPresetName = presetName
        if let preset = Self.systemPromptPresets.first(where: { $0.name == presetName }) {
            parameters.systemPrompt = preset.prompt
        }
        validateParameters()
    }
    
    /// Update system prompt directly
    func updateSystemPrompt(_ prompt: String) {
        parameters.systemPrompt = prompt
        // Update selected preset to "Custom" if prompt doesn't match any preset
        if !Self.systemPromptPresets.contains(where: { $0.prompt == prompt }) {
            selectedPresetName = "Custom"
        }
        validateParameters()
    }
    
    /// Reset parameters to defaults
    func resetToDefaults() {
        parameters = InferenceParameters()
        selectedPresetName = "Default"
        validateParameters()
    }
    
    /// Load preset parameters
    func loadPreset(_ preset: ParameterPreset) {
        parameters = preset.parameters
        selectedPresetName = preset.systemPromptName
        validateParameters()
    }
    
    // MARK: - Validation
    
    private func validateParameters() {
        validationErrors.removeAll()
        
        do {
            try parameters.validate()
            hasValidationErrors = false
        } catch let error as ManyLLMError {
            validationErrors.append(error.localizedDescription)
            hasValidationErrors = true
        } catch {
            validationErrors.append("Unknown validation error")
            hasValidationErrors = true
        }
    }
    
    /// Get validation status for a specific parameter
    func getValidationStatus(for parameter: ParameterType) -> ValidationStatus {
        switch parameter {
        case .temperature:
            return parameters.temperature >= Self.temperatureRange.lowerBound && 
                   parameters.temperature <= Self.temperatureRange.upperBound ? .valid : .invalid
        case .maxTokens:
            return parameters.maxTokens >= Self.maxTokensRange.lowerBound && 
                   parameters.maxTokens <= Self.maxTokensRange.upperBound ? .valid : .invalid
        case .topP:
            return parameters.topP >= Self.topPRange.lowerBound && 
                   parameters.topP <= Self.topPRange.upperBound ? .valid : .invalid
        case .systemPrompt:
            return .valid // System prompt is always valid
        }
    }
}

// MARK: - Supporting Types

struct SystemPromptPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let prompt: String
    let description: String
}

struct ParameterPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let parameters: InferenceParameters
    let systemPromptName: String
    
    static let presets: [ParameterPreset] = [
        ParameterPreset(
            name: "Balanced",
            description: "Good balance of creativity and coherence",
            parameters: InferenceParameters.balanced,
            systemPromptName: "Default"
        ),
        ParameterPreset(
            name: "Creative",
            description: "More creative and varied responses",
            parameters: InferenceParameters.creative,
            systemPromptName: "Creative Writer"
        ),
        ParameterPreset(
            name: "Precise",
            description: "Focused and deterministic responses",
            parameters: InferenceParameters.precise,
            systemPromptName: "Helpful Assistant"
        ),
        ParameterPreset(
            name: "Code Generation",
            description: "Optimized for programming tasks",
            parameters: InferenceParameters(
                temperature: 0.2,
                maxTokens: 4096,
                topP: 0.8,
                systemPrompt: ""
            ),
            systemPromptName: "Code Assistant"
        )
    ]
}

enum ParameterType {
    case temperature
    case maxTokens
    case topP
    case systemPrompt
}

enum ValidationStatus {
    case valid
    case invalid
    case warning
}

// MARK: - Parameter Controls Views

/// Enhanced parameter controls for the top toolbar with validation feedback
struct ParameterControlsView: View {
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Temperature Slider
            ParameterSliderView(
                title: "Temperature",
                value: Binding(
                    get: { Double(parameterManager.parameters.temperature) },
                    set: { parameterManager.updateTemperature(Float($0)) }
                ),
                range: Double(ParameterManager.temperatureRange.lowerBound)...Double(ParameterManager.temperatureRange.upperBound),
                step: 0.1,
                format: "%.1f",
                validationStatus: parameterManager.getValidationStatus(for: .temperature),
                width: 80
            )
            
            // Max Tokens Slider
            ParameterSliderView(
                title: "Max Tokens",
                value: Binding(
                    get: { Double(parameterManager.parameters.maxTokens) },
                    set: { parameterManager.updateMaxTokens(Int($0)) }
                ),
                range: Double(ParameterManager.maxTokensRange.lowerBound)...Double(ParameterManager.maxTokensRange.upperBound),
                step: 1,
                format: "%.0f",
                validationStatus: parameterManager.getValidationStatus(for: .maxTokens),
                width: 80
            )
            
            // Top-P Slider (Advanced parameter, shown in compact form)
            // ParameterSliderView(
            //     title: "Top-P",
            //     value: Binding(
            //         get: { Double(parameterManager.parameters.topP) },
            //         set: { parameterManager.updateTopP(Float($0)) }
            //     ),
            //     range: Double(ParameterManager.topPRange.lowerBound)...Double(ParameterManager.topPRange.upperBound),
            //     step: 0.05,
            //     format: "%.2f",
            //     validationStatus: parameterManager.getValidationStatus(for: .topP),
            //     width: 70
            // )
        }
    }
}

/// Individual parameter slider with validation feedback
struct ParameterSliderView: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let validationStatus: ValidationStatus
    let width: CGFloat
    
    @State private var isEditing = false
    @State private var showingTooltip = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title with validation indicator
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if validationStatus == .invalid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            
            // Slider and value display
            HStack(spacing: 8) {
                Slider(value: $value, in: range, step: step) { editing in
                    isEditing = editing
                }
                .frame(width: width)
                .accentColor(sliderColor)
                
                // Value display with validation styling
                Text(String(format: format, value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(valueColor)
                    .frame(width: valueWidth, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(valueBackgroundColor)
                    .cornerRadius(4)
            }
        }
        .onHover { hovering in
            showingTooltip = hovering
        }
        .help(tooltipText)
    }
    
    private var sliderColor: Color {
        switch validationStatus {
        case .valid:
            return .accentColor
        case .invalid:
            return .orange
        case .warning:
            return .yellow
        }
    }
    
    private var valueColor: Color {
        switch validationStatus {
        case .valid:
            return .secondary
        case .invalid:
            return .orange
        case .warning:
            return .yellow
        }
    }
    
    private var valueBackgroundColor: Color {
        if isEditing {
            return Color.accentColor.opacity(0.1)
        } else if validationStatus == .invalid {
            return Color.orange.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var valueWidth: CGFloat {
        switch title {
        case "Temperature", "Top-P":
            return 35
        case "Max Tokens":
            return 45
        default:
            return 40
        }
    }
    
    private var tooltipText: String {
        switch title {
        case "Temperature":
            return "Controls randomness (0.0 = deterministic, 2.0 = very creative)"
        case "Max Tokens":
            return "Maximum number of tokens to generate"
        case "Top-P":
            return "Nucleus sampling threshold (0.0 = most likely tokens only)"
        default:
            return ""
        }
    }
}

/// System prompt dropdown for the bottom input area
struct SystemPromptDropdownView: View {
    @ObservedObject var parameterManager: ParameterManager
    @State private var showingCustomPromptEditor = false
    @State private var customPromptText = ""
    
    var body: some View {
        Menu {
            // Preset options
            Section("Presets") {
                ForEach(ParameterManager.systemPromptPresets) { preset in
                    Button(action: {
                        parameterManager.selectSystemPromptPreset(preset.name)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 13))
                                
                                Text(preset.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if parameterManager.selectedPresetName == preset.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Custom prompt option
            Button("Custom Prompt...") {
                customPromptText = parameterManager.parameters.systemPrompt
                showingCustomPromptEditor = true
            }
            
            // Clear prompt option
            if !parameterManager.parameters.systemPrompt.isEmpty {
                Button("Clear Prompt") {
                    parameterManager.selectSystemPromptPreset("Default")
                }
            }
            
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(tooltipText)
        .sheet(isPresented: $showingCustomPromptEditor) {
            CustomPromptEditorSheet(
                promptText: $customPromptText,
                onSave: { prompt in
                    parameterManager.updateSystemPrompt(prompt)
                }
            )
        }
    }
    
    private var displayText: String {
        if parameterManager.selectedPresetName == "Custom" {
            return "Custom"
        } else if parameterManager.selectedPresetName == "Default" {
            return "System Prompt"
        } else {
            return parameterManager.selectedPresetName
        }
    }
    
    private var tooltipText: String {
        if parameterManager.parameters.systemPrompt.isEmpty {
            return "No system prompt set"
        } else if parameterManager.selectedPresetName == "Custom" {
            return "Custom system prompt: \(String(parameterManager.parameters.systemPrompt.prefix(100)))"
        } else {
            return ParameterManager.systemPromptPresets.first { $0.name == parameterManager.selectedPresetName }?.description ?? ""
        }
    }
}

/// Custom prompt editor sheet
struct CustomPromptEditorSheet: View {
    @Binding var promptText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingText: String = ""
    @State private var characterCount: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom System Prompt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Define how the AI should behave and respond. This prompt will be sent with every message.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Prompt Text")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(characterCount) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TextEditor(text: $editingText)
                        .font(.system(size: 14, design: .default))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .frame(minHeight: 200)
                        .onChange(of: editingText) { newValue in
                            characterCount = newValue.count
                        }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("System Prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editingText)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            editingText = promptText
            characterCount = promptText.count
        }
    }
}

struct ContentView: View {
    @State private var sidebarCollapsed = false
    @State private var workspacesExpanded = true
    @State private var filesExpanded = true
    
    // Parameter management
    @StateObject private var parameterManager = ParameterManager()
    @State private var showingSettings = false
    
    // Document management
    @StateObject private var documentManager = DocumentManager()
    
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
                    FilesView(
                        documentManager: documentManager,
                        isExpanded: $filesExpanded
                    )
                    
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
                    
                    // Parameter Controls
                    ParameterControlsView(parameterManager: parameterManager)
                    
                    // Settings Gear
                    Menu {
                        Button("Preferences...") { 
                            showingSettings = true
                        }
                        
                        Divider()
                        
                        // Parameter presets submenu
                        Menu("Parameter Presets") {
                            ForEach(ParameterPreset.presets) { preset in
                                Button(preset.name) {
                                    parameterManager.loadPreset(preset)
                                }
                            }
                            
                            Divider()
                            
                            Button("Reset to Defaults") {
                                parameterManager.resetToDefaults()
                            }
                        }
                        
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
                ChatView(
                    parameterManager: parameterManager,
                    documentManager: documentManager
                )
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(parameterManager: parameterManager)
        }
        .sheet(isPresented: $showingModelBrowser) {
            SimpleModelBrowserView()
        }
        .onAppear {
            // Add mock documents for testing
            documentManager.addMockDocuments()
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
    @ObservedObject var parameterManager: ParameterManager
    @ObservedObject var documentManager: DocumentManager
    @State private var messages: [SimpleChatMessage] = []
    @State private var messageText = ""
    @State private var isProcessing = false
    
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
            if !documentManager.activeDocuments.isEmpty {
                FileContextBar(documents: documentManager.activeDocuments.map { $0.filename })
            }
            
            // Bottom Input Area
            ChatInputView(
                messageText: $messageText,
                isProcessing: $isProcessing,
                parameterManager: parameterManager,
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
        let systemPromptInfo = parameterManager.selectedPresetName != "Default" ? 
            " (using \(parameterManager.selectedPresetName) system prompt)" : ""
        
        let parameterInfo = "Temperature: \(parameterManager.parameters.temperature), Max Tokens: \(parameterManager.parameters.maxTokens)"
        
        let responses = [
            "I understand your question about \"\(input)\"\(systemPromptInfo). This is a mock response that will be replaced with actual AI inference. Current parameters: \(parameterInfo)",
            "Thank you for your message. I'm currently running in preview mode\(systemPromptInfo), so this is a simulated response to demonstrate the chat interface with parameters: \(parameterInfo)",
            "Based on your input \"\(input)\"\(systemPromptInfo), I would provide a helpful response here. This interface is ready for integration with the actual inference engine. Parameters: \(parameterInfo)"
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
    @Binding var isProcessing: Bool
    @ObservedObject var parameterManager: ParameterManager
    
    let onSendMessage: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // System Prompt Dropdown
            HStack {
                Text("System Prompt:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                SystemPromptDropdownView(parameterManager: parameterManager)
                
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

// MARK: - Settings View

/// Basic settings view for parameter configuration
struct SettingsView: View {
    @ObservedObject var parameterManager: ParameterManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Parameter Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Configure how the AI model generates responses. Changes apply immediately to new messages.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Parameter presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Presets")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ParameterPreset.presets) { preset in
                            PresetCardView(preset: preset, parameterManager: parameterManager)
                        }
                    }
                }
                
                Divider()
                
                // Individual parameter controls
                VStack(alignment: .leading, spacing: 20) {
                    Text("Individual Parameters")
                        .font(.headline)
                    
                    // Temperature
                    ParameterDetailView(
                        title: "Temperature",
                        description: "Controls randomness in responses. Lower values make output more focused and deterministic, higher values make it more creative and varied.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.temperature) },
                            set: { parameterManager.updateTemperature(Float($0)) }
                        ),
                        range: Double(ParameterManager.temperatureRange.lowerBound)...Double(ParameterManager.temperatureRange.upperBound),
                        step: 0.1,
                        format: "%.1f",
                        validationStatus: parameterManager.getValidationStatus(for: .temperature)
                    )
                    
                    // Max Tokens
                    ParameterDetailView(
                        title: "Max Tokens",
                        description: "Maximum number of tokens (words/word pieces) the model can generate in a single response.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.maxTokens) },
                            set: { parameterManager.updateMaxTokens(Int($0)) }
                        ),
                        range: Double(ParameterManager.maxTokensRange.lowerBound)...Double(ParameterManager.maxTokensRange.upperBound),
                        step: 1,
                        format: "%.0f",
                        validationStatus: parameterManager.getValidationStatus(for: .maxTokens)
                    )
                    
                    // Top-P
                    ParameterDetailView(
                        title: "Top-P (Nucleus Sampling)",
                        description: "Limits token selection to the most probable tokens whose cumulative probability is below this threshold.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.topP) },
                            set: { parameterManager.updateTopP(Float($0)) }
                        ),
                        range: Double(ParameterManager.topPRange.lowerBound)...Double(ParameterManager.topPRange.upperBound),
                        step: 0.05,
                        format: "%.2f",
                        validationStatus: parameterManager.getValidationStatus(for: .topP)
                    )
                }
                
                // Reset button
                HStack {
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        parameterManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

/// Preset card view
struct PresetCardView: View {
    let preset: ParameterPreset
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name)
                .font(.system(size: 14, weight: .medium))
            
            Text(preset.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Temp: \(preset.parameters.temperature, specifier: "%.1f"), Tokens: \(preset.parameters.maxTokens)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Apply") {
                parameterManager.loadPreset(preset)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .frame(height: 120)
        .background(isCurrentPreset ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentPreset ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    private var isCurrentPreset: Bool {
        return parameterManager.parameters.temperature == preset.parameters.temperature &&
               parameterManager.parameters.maxTokens == preset.parameters.maxTokens &&
               parameterManager.parameters.topP == preset.parameters.topP
    }
}

/// Detailed parameter control view
struct ParameterDetailView: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let validationStatus: ValidationStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                if validationStatus == .invalid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(validationStatus == .invalid ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack {
                Text(String(format: format, range.lowerBound))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range, step: step)
                    .accentColor(validationStatus == .invalid ? .orange : .accentColor)
                
                Text(String(format: format, range.upperBound))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Simple Model Browser for Testing

/// Simple model browser view for testing download functionality
struct SimpleModelBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sampleModels: [SampleModelInfo] = []
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Model Browser")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .padding()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Model list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredModels) { model in
                            SimpleModelCard(model: model)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadSampleModels()
        }
    }
    
    private var filteredModels: [SampleModelInfo] {
        if searchText.isEmpty {
            return sampleModels
        } else {
            return sampleModels.filter { model in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func loadSampleModels() {
        sampleModels = [
            SampleModelInfo(
                name: "Llama 3 8B Instruct",
                author: "Meta",
                description: "A powerful 8B parameter instruction-tuned model",
                size: "4.6 GB",
                parameters: "8B",
                isLocal: false
            ),
            SampleModelInfo(
                name: "CodeLlama 7B",
                author: "Meta",
                description: "Specialized code generation model",
                size: "3.8 GB",
                parameters: "7B",
                isLocal: false
            ),
            SampleModelInfo(
                name: "Mistral 7B Instruct",
                author: "Mistral AI",
                description: "High-quality instruction following model",
                size: "4.1 GB",
                parameters: "7B",
                isLocal: false
            ),
            SampleModelInfo(
                name: "Local Test Model",
                author: "Test",
                description: "A test model that's already downloaded",
                size: "500 MB",
                parameters: "1B",
                isLocal: true
            )
        ]
    }
}

/// Simple model card for testing
struct SimpleModelCard: View {
    let model: SampleModelInfo
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                    
                    Text("by \(model.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status
                if model.isLocal {
                    Label("Local", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if isDownloading {
                    Label("Downloading", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Label("Available", systemImage: "cloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text(model.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Details
            HStack {
                Label(model.parameters, systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(model.size, systemImage: "externaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Download progress or button
            if isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            isDownloading = false
                            downloadProgress = 0.0
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                    
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            } else if model.isLocal {
                HStack {
                    Button("Open") {
                        print("Opening model: \(model.name)")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Delete") {
                        print("Deleting model: \(model.name)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
            } else {
                HStack {
                    Button("Download") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Details") {
                        print("Showing details for: \(model.name)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private func startDownload() {
        isDownloading = true
        downloadProgress = 0.0
        
        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                downloadProgress = 0.0
                print("✅ Download completed for: \(model.name)")
            }
        }
    }
}

/// Sample model info for testing
struct SampleModelInfo: Identifiable {
    let id = UUID()
    let name: String
    let author: String
    let description: String
    let size: String
    let parameters: String
    let isLocal: Bool
}