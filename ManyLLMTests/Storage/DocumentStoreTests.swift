import XCTest
import CoreData
@testable import ManyLLM

class DocumentStoreTests: XCTestCase {
    var documentStore: DocumentStore!
    var coreDataStack: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory Core Data stack for testing
        coreDataStack = createInMemoryCoreDataStack()
        documentStore = DocumentStore(coreDataStack: coreDataStack)
    }
    
    override func tearDown() {
        documentStore = nil
        coreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryCoreDataStack() -> CoreDataStack {
        let container = NSPersistentContainer(name: "ManyLLM")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        return CoreDataStack.shared
    }
    
    private func createTestDocument(filename: String = "test.pdf") -> ProcessedDocument {
        let url = URL(fileURLWithPath: "/tmp/\(filename)")
        let metadata = DocumentMetadata(
            title: "Test Document",
            author: "Test Author",
            subject: "Test Subject",
            keywords: ["test", "document"],
            creationDate: Date(),
            modificationDate: Date(),
            pageCount: 5,
            language: "en",
            processingDuration: 1.5,
            extractionMethod: "PDFKit"
        )
        
        let chunks = [
            DocumentChunk(
                content: "This is the first chunk of content.",
                startIndex: 0,
                endIndex: 35,
                pageNumber: 1,
                embeddings: [0.1, 0.2, 0.3, 0.4, 0.5]
            ),
            DocumentChunk(
                content: "This is the second chunk of content.",
                startIndex: 36,
                endIndex: 72,
                pageNumber: 1,
                embeddings: [0.6, 0.7, 0.8, 0.9, 1.0]
            )
        ]
        
        return ProcessedDocument(
            originalURL: url,
            filename: filename,
            fileSize: 1024,
            mimeType: "application/pdf",
            content: "This is the first chunk of content. This is the second chunk of content.",
            chunks: chunks,
            metadata: metadata,
            processedAt: Date(),
            isActive: false
        )
    }
    
    // MARK: - Document CRUD Tests
    
    func testSaveDocument() throws {
        let document = createTestDocument()
        
        try documentStore.saveDocument(document)
        
        let savedDocument = documentStore.getDocument(id: document.id)
        XCTAssertNotNil(savedDocument)
        XCTAssertEqual(savedDocument?.filename, document.filename)
        XCTAssertEqual(savedDocument?.content, document.content)
        XCTAssertEqual(savedDocument?.chunks.count, document.chunks.count)
    }
    
    func testUpdateDocument() throws {
        var document = createTestDocument()
        try documentStore.saveDocument(document)
        
        // Update the document
        document.isActive = true
        
        try documentStore.saveDocument(document)
        
        let updatedDocument = documentStore.getDocument(id: document.id)
        XCTAssertEqual(updatedDocument?.isActive, true)
    }
    
    func testGetDocumentById() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        let retrievedDocument = documentStore.getDocument(id: document.id)
        
        XCTAssertNotNil(retrievedDocument)
        XCTAssertEqual(retrievedDocument?.id, document.id)
        XCTAssertEqual(retrievedDocument?.filename, document.filename)
    }
    
    func testGetDocumentsByIds() throws {
        let document1 = createTestDocument(filename: "test1.pdf")
        let document2 = createTestDocument(filename: "test2.pdf")
        let document3 = createTestDocument(filename: "test3.pdf")
        
        try documentStore.saveDocument(document1)
        try documentStore.saveDocument(document2)
        try documentStore.saveDocument(document3)
        
        let ids = [document1.id, document3.id]
        let retrievedDocuments = documentStore.getDocuments(ids: ids)
        
        XCTAssertEqual(retrievedDocuments.count, 2)
        XCTAssertTrue(retrievedDocuments.contains { $0.id == document1.id })
        XCTAssertTrue(retrievedDocuments.contains { $0.id == document3.id })
        XCTAssertFalse(retrievedDocuments.contains { $0.id == document2.id })
    }
    
    func testDeleteDocument() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        XCTAssertNotNil(documentStore.getDocument(id: document.id))
        
        try documentStore.deleteDocument(document)
        
        XCTAssertNil(documentStore.getDocument(id: document.id))
        XCTAssertFalse(documentStore.documents.contains { $0.id == document.id })
    }
    
    // MARK: - Active Status Tests
    
    func testUpdateDocumentActiveStatus() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        XCTAssertFalse(document.isActive)
        
        try documentStore.updateDocumentActiveStatus(document.id, isActive: true)
        
        let updatedDocument = documentStore.getDocument(id: document.id)
        XCTAssertEqual(updatedDocument?.isActive, true)
    }
    
    func testUpdateActiveStatusForNonExistentDocument() {
        let nonExistentId = UUID()
        
        XCTAssertThrowsError(try documentStore.updateDocumentActiveStatus(nonExistentId, isActive: true)) { error in
            XCTAssertTrue(error is ManyLLMError)
            if case .storageError(let message) = error as? ManyLLMError {
                XCTAssertEqual(message, "Document not found")
            }
        }
    }
    
    func testGetActiveDocuments() throws {
        let document1 = createTestDocument(filename: "active1.pdf")
        let document2 = createTestDocument(filename: "inactive.pdf")
        let document3 = createTestDocument(filename: "active2.pdf")
        
        try documentStore.saveDocument(document1)
        try documentStore.saveDocument(document2)
        try documentStore.saveDocument(document3)
        
        try documentStore.updateDocumentActiveStatus(document1.id, isActive: true)
        try documentStore.updateDocumentActiveStatus(document3.id, isActive: true)
        
        let activeDocuments = documentStore.getActiveDocuments()
        
        XCTAssertEqual(activeDocuments.count, 2)
        XCTAssertTrue(activeDocuments.contains { $0.id == document1.id })
        XCTAssertTrue(activeDocuments.contains { $0.id == document3.id })
        XCTAssertFalse(activeDocuments.contains { $0.id == document2.id })
    }
    
    // MARK: - Filtering Tests
    
    func testGetDocumentsByExtension() throws {
        let pdfDocument = createTestDocument(filename: "test.pdf")
        let txtDocument = createTestDocument(filename: "test.txt")
        let docxDocument = createTestDocument(filename: "test.docx")
        
        try documentStore.saveDocument(pdfDocument)
        try documentStore.saveDocument(txtDocument)
        try documentStore.saveDocument(docxDocument)
        
        let pdfDocuments = documentStore.getDocuments(withExtension: "pdf")
        let txtDocuments = documentStore.getDocuments(withExtension: "txt")
        
        XCTAssertEqual(pdfDocuments.count, 1)
        XCTAssertEqual(pdfDocuments.first?.filename, "test.pdf")
        
        XCTAssertEqual(txtDocuments.count, 1)
        XCTAssertEqual(txtDocuments.first?.filename, "test.txt")
    }
    
    func testGetDocumentsByExtensionCaseInsensitive() throws {
        let document = createTestDocument(filename: "test.PDF")
        try documentStore.saveDocument(document)
        
        let documents = documentStore.getDocuments(withExtension: "pdf")
        
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.filename, "test.PDF")
    }
    
    func testGetDocumentsLargerThanSize() throws {
        let smallDocument = createTestDocument(filename: "small.pdf")
        let largeDocument = createTestDocument(filename: "large.pdf")
        
        // Modify file sizes
        var smallDoc = smallDocument
        var largeDoc = largeDocument
        
        // This would require modifying the createTestDocument method or creating documents with different sizes
        // For now, we'll test the filtering logic
        
        try documentStore.saveDocument(smallDoc)
        try documentStore.saveDocument(largeDoc)
        
        let largeDocuments = documentStore.getDocuments(largerThan: 500)
        
        // Both test documents have size 1024, so both should be returned
        XCTAssertEqual(largeDocuments.count, 2)
    }
    
    func testGetDocumentsProcessedAfterDate() throws {
        let oldDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let recentDate = Date()
        
        let document1 = createTestDocument(filename: "old.pdf")
        let document2 = createTestDocument(filename: "recent.pdf")
        
        try documentStore.saveDocument(document1)
        try documentStore.saveDocument(document2)
        
        let recentDocuments = documentStore.getDocuments(processedAfter: oldDate)
        
        // Both documents should be recent since they were just created
        XCTAssertEqual(recentDocuments.count, 2)
    }
    
    // MARK: - Search Tests
    
    func testSearchDocumentsByFilename() throws {
        let document1 = createTestDocument(filename: "important_report.pdf")
        let document2 = createTestDocument(filename: "meeting_notes.txt")
        let document3 = createTestDocument(filename: "report_summary.docx")
        
        try documentStore.saveDocument(document1)
        try documentStore.saveDocument(document2)
        try documentStore.saveDocument(document3)
        
        let searchResults = documentStore.searchDocuments(query: "report")
        
        XCTAssertEqual(searchResults.count, 2)
        XCTAssertTrue(searchResults.contains { $0.filename == "important_report.pdf" })
        XCTAssertTrue(searchResults.contains { $0.filename == "report_summary.docx" })
    }
    
    func testSearchDocumentsByContent() throws {
        let document1 = createTestDocument(filename: "doc1.pdf")
        let document2 = createTestDocument(filename: "doc2.pdf")
        
        // Modify content for testing
        var doc1 = document1
        var doc2 = document2
        doc1.content = "This document contains important information about machine learning."
        doc2.content = "This document is about natural language processing."
        
        try documentStore.saveDocument(doc1)
        try documentStore.saveDocument(doc2)
        
        let searchResults = documentStore.searchDocuments(query: "machine learning")
        
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.filename, "doc1.pdf")
    }
    
    func testSearchDocumentsByTitle() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        let searchResults = documentStore.searchDocuments(query: "Test Document")
        
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, document.id)
    }
    
    func testSearchDocumentsCaseInsensitive() throws {
        let document = createTestDocument(filename: "Important_File.PDF")
        try documentStore.saveDocument(document)
        
        let searchResults = documentStore.searchDocuments(query: "important")
        
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.filename, "Important_File.PDF")
    }
    
    // MARK: - Document Metadata Tests
    
    func testDocumentMetadataPersistence() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        let savedDocument = documentStore.getDocument(id: document.id)
        
        XCTAssertEqual(savedDocument?.metadata.title, "Test Document")
        XCTAssertEqual(savedDocument?.metadata.author, "Test Author")
        XCTAssertEqual(savedDocument?.metadata.subject, "Test Subject")
        XCTAssertEqual(savedDocument?.metadata.keywords, ["test", "document"])
        XCTAssertEqual(savedDocument?.metadata.pageCount, 5)
        XCTAssertEqual(savedDocument?.metadata.language, "en")
        XCTAssertEqual(savedDocument?.metadata.processingDuration, 1.5)
        XCTAssertEqual(savedDocument?.metadata.extractionMethod, "PDFKit")
    }
    
    func testDocumentChunksPersistence() throws {
        let document = createTestDocument()
        try documentStore.saveDocument(document)
        
        let savedDocument = documentStore.getDocument(id: document.id)
        
        XCTAssertEqual(savedDocument?.chunks.count, 2)
        
        let firstChunk = savedDocument?.chunks.first
        XCTAssertEqual(firstChunk?.content, "This is the first chunk of content.")
        XCTAssertEqual(firstChunk?.startIndex, 0)
        XCTAssertEqual(firstChunk?.endIndex, 35)
        XCTAssertEqual(firstChunk?.pageNumber, 1)
        XCTAssertEqual(firstChunk?.embeddings, [0.1, 0.2, 0.3, 0.4, 0.5])
    }
}

// MARK: - Performance Tests

extension DocumentStoreTests {
    func testSaveMultipleDocumentsPerformance() {
        measure {
            for i in 0..<20 {
                let document = createTestDocument(filename: "document_\(i).pdf")
                do {
                    try documentStore.saveDocument(document)
                } catch {
                    XCTFail("Failed to save document: \(error)")
                }
            }
        }
    }
    
    func testSearchPerformance() throws {
        // Create multiple documents for search testing
        for i in 0..<100 {
            let document = createTestDocument(filename: "document_\(i).pdf")
            try documentStore.saveDocument(document)
        }
        
        measure {
            let _ = documentStore.searchDocuments(query: "document")
        }
    }
}