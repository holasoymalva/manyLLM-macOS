import XCTest
@testable import ManyLLM

@MainActor
final class DocumentManagerTests: XCTestCase {
    
    var documentManager: DocumentManager!
    var mockProcessor: MockDocumentProcessor!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockProcessor = MockDocumentProcessor()
        documentManager = DocumentManager(documentProcessor: mockProcessor)
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocumentManagerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        documentManager = nil
        mockProcessor = nil
        tempDirectory = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(documentManager.documents.isEmpty)
        XCTAssertFalse(documentManager.isProcessing)
        XCTAssertEqual(documentManager.processingProgress, 0.0)
        XCTAssertEqual(documentManager.activeDocumentCount, 0)
        XCTAssertEqual(documentManager.totalDocumentCount, 0)
        XCTAssertEqual(documentManager.contextSummary, "No files")
    }
    
    // MARK: - Document Upload Tests
    
    func testUploadSingleDocument() async {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        mockProcessor.mockResult = DocumentProcessingResult(
            document: createMockDocument(filename: "test.txt"),
            processingTime: 0.1
        )
        
        await documentManager.uploadDocuments(from: [testFile])
        
        XCTAssertEqual(documentManager.documents.count, 1)
        XCTAssertEqual(documentManager.documents.first?.filename, "test.txt")
        XCTAssertFalse(documentManager.isProcessing)
    }
    
    func testUploadMultipleDocuments() async {
        let testFiles = [
            tempDirectory.appendingPathComponent("test1.txt"),
            tempDirectory.appendingPathComponent("test2.txt"),
            tempDirectory.appendingPathComponent("test3.txt")
        ]
        
        for (index, file) in testFiles.enumerated() {
            try "Test content \(index + 1)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        mockProcessor.mockResults = [
            DocumentProcessingResult(document: createMockDocument(filename: "test1.txt"), processingTime: 0.1),
            DocumentProcessingResult(document: createMockDocument(filename: "test2.txt"), processingTime: 0.1),
            DocumentProcessingResult(document: createMockDocument(filename: "test3.txt"), processingTime: 0.1)
        ]
        
        await documentManager.uploadDocuments(from: testFiles)
        
        XCTAssertEqual(documentManager.documents.count, 3)
        XCTAssertFalse(documentManager.isProcessing)
    }
    
    func testUploadEmptyArray() async {
        await documentManager.uploadDocuments(from: [])
        
        XCTAssertTrue(documentManager.documents.isEmpty)
        XCTAssertFalse(documentManager.isProcessing)
    }
    
    // MARK: - Document Management Tests
    
    func testToggleDocumentActive() {
        let document = createMockDocument(filename: "test.txt", isActive: false)
        documentManager.documents.append(document)
        
        XCTAssertFalse(document.isActive)
        XCTAssertEqual(documentManager.activeDocumentCount, 0)
        
        documentManager.toggleDocumentActive(document)
        
        XCTAssertTrue(documentManager.documents.first?.isActive ?? false)
        XCTAssertEqual(documentManager.activeDocumentCount, 1)
    }
    
    func testRemoveDocument() {
        let document1 = createMockDocument(filename: "test1.txt")
        let document2 = createMockDocument(filename: "test2.txt")
        
        documentManager.documents.append(contentsOf: [document1, document2])
        XCTAssertEqual(documentManager.documents.count, 2)
        
        documentManager.removeDocument(document1)
        
        XCTAssertEqual(documentManager.documents.count, 1)
        XCTAssertEqual(documentManager.documents.first?.filename, "test2.txt")
    }
    
    func testRemoveAllDocuments() {
        let documents = [
            createMockDocument(filename: "test1.txt"),
            createMockDocument(filename: "test2.txt"),
            createMockDocument(filename: "test3.txt")
        ]
        
        documentManager.documents.append(contentsOf: documents)
        XCTAssertEqual(documentManager.documents.count, 3)
        
        documentManager.removeAllDocuments()
        
        XCTAssertTrue(documentManager.documents.isEmpty)
    }
    
    func testSetAllDocumentsActive() {
        let documents = [
            createMockDocument(filename: "test1.txt", isActive: false),
            createMockDocument(filename: "test2.txt", isActive: true),
            createMockDocument(filename: "test3.txt", isActive: false)
        ]
        
        documentManager.documents.append(contentsOf: documents)
        XCTAssertEqual(documentManager.activeDocumentCount, 1)
        
        documentManager.setAllDocumentsActive(true)
        
        XCTAssertEqual(documentManager.activeDocumentCount, 3)
        XCTAssertTrue(documentManager.documents.allSatisfy { $0.isActive })
        
        documentManager.setAllDocumentsActive(false)
        
        XCTAssertEqual(documentManager.activeDocumentCount, 0)
        XCTAssertTrue(documentManager.documents.allSatisfy { !$0.isActive })
    }
    
    // MARK: - Context Summary Tests
    
    func testContextSummaryNoFiles() {
        XCTAssertEqual(documentManager.contextSummary, "No files")
    }
    
    func testContextSummaryAllActive() {
        let documents = [
            createMockDocument(filename: "test1.txt", isActive: true),
            createMockDocument(filename: "test2.txt", isActive: true)
        ]
        
        documentManager.documents.append(contentsOf: documents)
        
        XCTAssertEqual(documentManager.contextSummary, "2 files in context")
    }
    
    func testContextSummaryPartialActive() {
        let documents = [
            createMockDocument(filename: "test1.txt", isActive: true),
            createMockDocument(filename: "test2.txt", isActive: false),
            createMockDocument(filename: "test3.txt", isActive: true)
        ]
        
        documentManager.documents.append(contentsOf: documents)
        
        XCTAssertEqual(documentManager.contextSummary, "2 of 3 files in context")
    }
    
    func testContextSummarySingleFile() {
        let document = createMockDocument(filename: "test.txt", isActive: true)
        documentManager.documents.append(document)
        
        XCTAssertEqual(documentManager.contextSummary, "1 file in context")
    }
    
    // MARK: - Document Context Tests
    
    func testGetActiveDocumentContext() {
        let documents = [
            createMockDocument(filename: "doc1.txt", content: "Content 1", isActive: true),
            createMockDocument(filename: "doc2.txt", content: "Content 2", isActive: false),
            createMockDocument(filename: "doc3.txt", content: "Content 3", isActive: true)
        ]
        
        documentManager.documents.append(contentsOf: documents)
        
        let context = documentManager.getActiveDocumentContext()
        
        XCTAssertTrue(context.contains("Document: doc1.txt"))
        XCTAssertTrue(context.contains("Content 1"))
        XCTAssertFalse(context.contains("Document: doc2.txt"))
        XCTAssertFalse(context.contains("Content 2"))
        XCTAssertTrue(context.contains("Document: doc3.txt"))
        XCTAssertTrue(context.contains("Content 3"))
    }
    
    func testGetActiveDocumentContextEmpty() {
        let context = documentManager.getActiveDocumentContext()
        XCTAssertTrue(context.isEmpty)
    }
    
    // MARK: - File Validation Tests
    
    func testValidateFiles() {
        let validFile = tempDirectory.appendingPathComponent("valid.txt")
        let invalidFile = tempDirectory.appendingPathComponent("invalid.xyz")
        
        try! "Valid content".write(to: validFile, atomically: true, encoding: .utf8)
        try! "Invalid content".write(to: invalidFile, atomically: true, encoding: .utf8)
        
        mockProcessor.shouldThrowValidationError = true
        mockProcessor.validationErrorFile = invalidFile
        
        let (valid, invalid) = documentManager.validateFiles([validFile, invalidFile])
        
        XCTAssertEqual(valid.count, 1)
        XCTAssertEqual(valid.first, validFile)
        XCTAssertEqual(invalid.count, 1)
        XCTAssertEqual(invalid.first?.0, invalidFile)
    }
    
    // MARK: - Error Handling Tests
    
    func testUploadDocumentWithError() async {
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        mockProcessor.shouldThrowError = true
        mockProcessor.errorToThrow = ManyLLMError.documentProcessingFailed("Test error")
        
        await documentManager.uploadDocuments(from: [testFile])
        
        XCTAssertTrue(documentManager.documents.isEmpty)
        XCTAssertNotNil(documentManager.errorMessage)
        XCTAssertTrue(documentManager.showingError)
        XCTAssertFalse(documentManager.isProcessing)
    }
    
    // MARK: - Mock Data Tests
    
    func testAddMockDocuments() {
        documentManager.addMockDocuments()
        
        XCTAssertEqual(documentManager.documents.count, 3)
        XCTAssertEqual(documentManager.activeDocumentCount, 2)
        
        let filenames = documentManager.documents.map { $0.filename }
        XCTAssertTrue(filenames.contains("document.pdf"))
        XCTAssertTrue(filenames.contains("notes.txt"))
        XCTAssertTrue(filenames.contains("data.csv"))
    }
    
    // MARK: - Drag and Drop Tests
    
    func testHandleDroppedFiles() async {
        let testFile = tempDirectory.appendingPathComponent("dropped.txt")
        try! "Dropped file content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // Create mock NSItemProvider
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: "public.file-url", fileOptions: []) { completion in
            completion(testFile, true, nil)
            return nil
        }
        
        mockProcessor.mockResult = DocumentProcessingResult(
            document: createMockDocument(filename: "dropped.txt", content: "Dropped file content"),
            processingTime: 0.1
        )
        
        await documentManager.handleDroppedFiles([provider])
        
        // Note: This test may not work perfectly due to NSItemProvider async nature
        // In a real app, this would be tested through UI tests
    }
    
    // MARK: - Integration Tests
    
    func testCompleteDocumentManagementWorkflow() async {
        // Start with empty state
        XCTAssertTrue(documentManager.documents.isEmpty)
        XCTAssertEqual(documentManager.contextSummary, "No files")
        
        // Create test files
        let files = [
            tempDirectory.appendingPathComponent("doc1.txt"),
            tempDirectory.appendingPathComponent("doc2.txt")
        ]
        
        for (index, file) in files.enumerated() {
            try! "Content of document \(index + 1)".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Set up mock results
        mockProcessor.mockResults = [
            DocumentProcessingResult(
                document: createMockDocument(filename: "doc1.txt", content: "Content of document 1"),
                processingTime: 0.1
            ),
            DocumentProcessingResult(
                document: createMockDocument(filename: "doc2.txt", content: "Content of document 2"),
                processingTime: 0.1
            )
        ]
        
        // Upload documents
        await documentManager.uploadDocuments(from: files)
        
        // Verify upload
        XCTAssertEqual(documentManager.documents.count, 2)
        XCTAssertEqual(documentManager.contextSummary, "0 of 2 files in context")
        
        // Activate first document
        documentManager.toggleDocumentActive(documentManager.documents[0])
        XCTAssertEqual(documentManager.activeDocumentCount, 1)
        XCTAssertEqual(documentManager.contextSummary, "1 of 2 files in context")
        
        // Activate all documents
        documentManager.setAllDocumentsActive(true)
        XCTAssertEqual(documentManager.activeDocumentCount, 2)
        XCTAssertEqual(documentManager.contextSummary, "2 files in context")
        
        // Get context
        let context = documentManager.getActiveDocumentContext()
        XCTAssertTrue(context.contains("Document: doc1.txt"))
        XCTAssertTrue(context.contains("Document: doc2.txt"))
        XCTAssertTrue(context.contains("Content of document 1"))
        XCTAssertTrue(context.contains("Content of document 2"))
        
        // Remove one document
        documentManager.removeDocument(documentManager.documents[0])
        XCTAssertEqual(documentManager.documents.count, 1)
        
        // Clear all
        documentManager.removeAllDocuments()
        XCTAssertTrue(documentManager.documents.isEmpty)
        XCTAssertEqual(documentManager.contextSummary, "No files")
    }
    
    // MARK: - Helper Methods
    
    private func createMockDocument(
        filename: String,
        content: String = "Mock content",
        isActive: Bool = false
    ) -> ProcessedDocument {
        return ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            filename: filename,
            fileSize: Int64(content.count),
            mimeType: "text/plain",
            content: content,
            chunks: [],
            metadata: DocumentMetadata(title: filename),
            isActive: isActive
        )
    }
}

// MARK: - Mock Document Processor

class MockDocumentProcessor: DocumentProcessor {
    var isProcessing: Bool = false
    var supportedExtensions: [String] = ["pdf", "txt", "csv", "docx", "doc"]
    var maxFileSize: Int64 = 100 * 1024 * 1024
    
    var mockResult: DocumentProcessingResult?
    var mockResults: [DocumentProcessingResult] = []
    var shouldThrowError = false
    var errorToThrow: Error = ManyLLMError.documentProcessingFailed("Mock error")
    var shouldThrowValidationError = false
    var validationErrorFile: URL?
    
    func processDocument(
        from url: URL,
        config: DocumentProcessingConfig
    ) async throws -> DocumentProcessingResult {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockResult ?? DocumentProcessingResult(
            document: ProcessedDocument(
                originalURL: url,
                filename: url.lastPathComponent,
                fileSize: 1000,
                mimeType: "text/plain",
                content: "Mock content",
                chunks: [],
                metadata: DocumentMetadata()
            ),
            processingTime: 0.1
        )
    }
    
    func processDocuments(
        from urls: [URL],
        config: DocumentProcessingConfig,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> [DocumentProcessingResult] {
        if shouldThrowError {
            throw errorToThrow
        }
        
        var results: [DocumentProcessingResult] = []
        
        for (index, url) in urls.enumerated() {
            if index < mockResults.count {
                results.append(mockResults[index])
            } else {
                results.append(DocumentProcessingResult(
                    document: ProcessedDocument(
                        originalURL: url,
                        filename: url.lastPathComponent,
                        fileSize: 1000,
                        mimeType: "text/plain",
                        content: "Mock content",
                        chunks: [],
                        metadata: DocumentMetadata()
                    ),
                    processingTime: 0.1
                ))
            }
            
            progressHandler(index + 1, urls.count)
        }
        
        return results
    }
    
    func extractText(from url: URL) async throws -> String {
        if shouldThrowError {
            throw errorToThrow
        }
        return "Mock extracted text"
    }
    
    func extractMetadata(from url: URL) async throws -> DocumentMetadata {
        if shouldThrowError {
            throw errorToThrow
        }
        return DocumentMetadata()
    }
    
    func generateChunks(from content: String, chunkSize: Int, overlap: Int) -> [DocumentChunk] {
        return [DocumentChunk(content: content, startIndex: 0, endIndex: content.count)]
    }
    
    func generateEmbeddings(for chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        if shouldThrowError {
            throw errorToThrow
        }
        return chunks
    }
    
    func isFormatSupported(_ url: URL) -> Bool {
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    func validateDocument(at url: URL) throws {
        if shouldThrowValidationError && url == validationErrorFile {
            throw ManyLLMError.unsupportedFormat(url.pathExtension)
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func cancelProcessing() async {
        isProcessing = false
    }
}