import Foundation

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