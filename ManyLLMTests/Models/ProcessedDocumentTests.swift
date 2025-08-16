import XCTest
@testable import ManyLLM

final class ProcessedDocumentTests: XCTestCase {
    
    func testProcessedDocumentInitialization() throws {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let metadata = DocumentMetadata(
            title: "Test Document",
            author: "Test Author",
            pageCount: 5
        )
        
        let document = ProcessedDocument(
            originalURL: url,
            filename: "test.pdf",
            fileSize: 1024 * 1024, // 1MB
            mimeType: "application/pdf",
            content: "This is test content",
            metadata: metadata
        )
        
        XCTAssertEqual(document.filename, "test.pdf")
        XCTAssertEqual(document.fileSize, 1024 * 1024)
        XCTAssertEqual(document.mimeType, "application/pdf")
        XCTAssertEqual(document.content, "This is test content")
        XCTAssertEqual(document.fileExtension, "pdf")
        XCTAssertFalse(document.isActive)
        XCTAssertFalse(document.isChunked)
        XCTAssertFalse(document.hasEmbeddings)
    }
    
    func testProcessedDocumentWithChunks() throws {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let metadata = DocumentMetadata()
        
        let chunk1 = DocumentChunk(
            content: "First chunk",
            startIndex: 0,
            endIndex: 11,
            embeddings: [0.1, 0.2, 0.3]
        )
        let chunk2 = DocumentChunk(
            content: "Second chunk",
            startIndex: 12,
            endIndex: 24,
            embeddings: [0.4, 0.5, 0.6]
        )
        
        let document = ProcessedDocument(
            originalURL: url,
            filename: "test.txt",
            fileSize: 1024,
            mimeType: "text/plain",
            content: "First chunk Second chunk",
            chunks: [chunk1, chunk2],
            metadata: metadata
        )
        
        XCTAssertTrue(document.isChunked)
        XCTAssertTrue(document.hasEmbeddings)
        XCTAssertEqual(document.chunkCount, 2)
        XCTAssertEqual(document.characterCount, 24)
        XCTAssertEqual(document.wordCount, 4)
    }
    
    func testProcessedDocumentSerialization() throws {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let metadata = DocumentMetadata(title: "Test Document")
        
        let originalDocument = ProcessedDocument(
            originalURL: url,
            filename: "test.pdf",
            fileSize: 1024,
            mimeType: "application/pdf",
            content: "Test content",
            metadata: metadata
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalDocument)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(ProcessedDocument.self, from: data)
        
        XCTAssertEqual(originalDocument, decodedDocument)
    }
    
    func testDocumentChunkInitialization() {
        let chunk = DocumentChunk(
            content: "Test chunk content",
            startIndex: 0,
            endIndex: 18,
            pageNumber: 1,
            embeddings: [0.1, 0.2, 0.3, 0.4, 0.5]
        )
        
        XCTAssertEqual(chunk.content, "Test chunk content")
        XCTAssertEqual(chunk.startIndex, 0)
        XCTAssertEqual(chunk.endIndex, 18)
        XCTAssertEqual(chunk.pageNumber, 1)
        XCTAssertEqual(chunk.length, 18)
        XCTAssertTrue(chunk.hasEmbeddings)
        XCTAssertEqual(chunk.embeddings?.count, 5)
    }
    
    func testDocumentMetadata() {
        let metadata = DocumentMetadata(
            title: "Test Document",
            author: "John Doe",
            subject: "Testing",
            keywords: ["test", "document", "example"],
            creationDate: Date(),
            pageCount: 10,
            language: "en",
            processingDuration: 2.5,
            extractionMethod: "PDFKit"
        )
        
        XCTAssertEqual(metadata.title, "Test Document")
        XCTAssertEqual(metadata.author, "John Doe")
        XCTAssertEqual(metadata.subject, "Testing")
        XCTAssertEqual(metadata.keywords?.count, 3)
        XCTAssertEqual(metadata.pageCount, 10)
        XCTAssertEqual(metadata.language, "en")
        XCTAssertEqual(metadata.processingDuration, 2.5)
        XCTAssertEqual(metadata.extractionMethod, "PDFKit")
    }
    
    func testDocumentFileSizeString() throws {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let metadata = DocumentMetadata()
        
        let document = ProcessedDocument(
            originalURL: url,
            filename: "test.pdf",
            fileSize: 1024 * 1024, // 1MB
            mimeType: "application/pdf",
            content: "Test content",
            metadata: metadata
        )
        
        let sizeString = document.fileSizeString
        XCTAssertTrue(sizeString.contains("1"))
        XCTAssertTrue(sizeString.contains("MB") || sizeString.contains("KB"))
    }
}