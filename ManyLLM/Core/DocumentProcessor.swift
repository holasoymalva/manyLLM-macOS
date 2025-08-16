import Foundation

/// Result of document processing operation
struct DocumentProcessingResult {
    let document: ProcessedDocument
    let warnings: [String]
    let processingTime: TimeInterval
    
    init(document: ProcessedDocument, warnings: [String] = [], processingTime: TimeInterval) {
        self.document = document
        self.warnings = warnings
        self.processingTime = processingTime
    }
}

/// Configuration for document processing
struct DocumentProcessingConfig {
    let chunkSize: Int
    let chunkOverlap: Int
    let generateEmbeddings: Bool
    let extractMetadata: Bool
    let preserveFormatting: Bool
    let language: String?
    
    init(
        chunkSize: Int = 1000,
        chunkOverlap: Int = 200,
        generateEmbeddings: Bool = true,
        extractMetadata: Bool = true,
        preserveFormatting: Bool = false,
        language: String? = nil
    ) {
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.generateEmbeddings = generateEmbeddings
        self.extractMetadata = extractMetadata
        self.preserveFormatting = preserveFormatting
        self.language = language
    }
    
    static let `default` = DocumentProcessingConfig()
}

/// Protocol for processing documents and extracting text content
protocol DocumentProcessor {
    /// Process a document from a file URL
    func processDocument(
        from url: URL,
        config: DocumentProcessingConfig
    ) async throws -> DocumentProcessingResult
    
    /// Process multiple documents concurrently
    func processDocuments(
        from urls: [URL],
        config: DocumentProcessingConfig,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> [DocumentProcessingResult]
    
    /// Extract text content from a document without full processing
    func extractText(from url: URL) async throws -> String
    
    /// Extract metadata from a document
    func extractMetadata(from url: URL) async throws -> DocumentMetadata
    
    /// Generate text chunks from content
    func generateChunks(
        from content: String,
        chunkSize: Int,
        overlap: Int
    ) -> [DocumentChunk]
    
    /// Generate embeddings for text chunks
    func generateEmbeddings(for chunks: [DocumentChunk]) async throws -> [DocumentChunk]
    
    /// Check if a file format is supported
    func isFormatSupported(_ url: URL) -> Bool
    
    /// Get supported file extensions
    var supportedExtensions: [String] { get }
    
    /// Get maximum file size supported
    var maxFileSize: Int64 { get }
    
    /// Validate document before processing
    func validateDocument(at url: URL) throws
    
    /// Cancel ongoing processing operations
    func cancelProcessing() async
    
    /// Check if processor is currently busy
    var isProcessing: Bool { get }
}