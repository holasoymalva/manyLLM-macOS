import XCTest
@testable import ManyLLM

@MainActor
final class DocumentProcessorTests: XCTestCase {
    
    var documentProcessor: DefaultDocumentProcessor!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        documentProcessor = DefaultDocumentProcessor()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocumentProcessorTests")
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
        
        documentProcessor = nil
        tempDirectory = nil
        try await super.tearDown()
    }
    
    // MARK: - Format Support Tests
    
    func testSupportedFormats() {
        let supportedExtensions = documentProcessor.supportedExtensions
        
        XCTAssertTrue(supportedExtensions.contains("pdf"))
        XCTAssertTrue(supportedExtensions.contains("txt"))
        XCTAssertTrue(supportedExtensions.contains("csv"))
        XCTAssertTrue(supportedExtensions.contains("docx"))
        XCTAssertTrue(supportedExtensions.contains("doc"))
    }
    
    func testIsFormatSupported() {
        let pdfURL = URL(fileURLWithPath: "/test/document.pdf")
        let txtURL = URL(fileURLWithPath: "/test/document.txt")
        let csvURL = URL(fileURLWithPath: "/test/document.csv")
        let docxURL = URL(fileURLWithPath: "/test/document.docx")
        let unsupportedURL = URL(fileURLWithPath: "/test/document.xyz")
        
        XCTAssertTrue(documentProcessor.isFormatSupported(pdfURL))
        XCTAssertTrue(documentProcessor.isFormatSupported(txtURL))
        XCTAssertTrue(documentProcessor.isFormatSupported(csvURL))
        XCTAssertTrue(documentProcessor.isFormatSupported(docxURL))
        XCTAssertFalse(documentProcessor.isFormatSupported(unsupportedURL))
    }
    
    // MARK: - Text Extraction Tests
    
    func testExtractTextFromTXT() async throws {
        let testContent = "This is a test document.\nWith multiple lines.\nAnd some content."
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        let extractedText = try await documentProcessor.extractText(from: testFile)
        
        XCTAssertEqual(extractedText, testContent)
    }
    
    func testExtractTextFromCSV() async throws {
        let csvContent = """
        Name,Age,City
        John,25,New York
        Jane,30,Los Angeles
        Bob,35,Chicago
        """
        let testFile = tempDirectory.appendingPathComponent("test.csv")
        
        try csvContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        let extractedText = try await documentProcessor.extractText(from: testFile)
        
        XCTAssertTrue(extractedText.contains("Headers: Name, Age, City"))
        XCTAssertTrue(extractedText.contains("Row 1:"))
        XCTAssertTrue(extractedText.contains("Name: John"))
        XCTAssertTrue(extractedText.contains("Age: 25"))
        XCTAssertTrue(extractedText.contains("City: New York"))
    }
    
    func testExtractTextFromUnsupportedFormat() async {
        let testFile = tempDirectory.appendingPathComponent("test.xyz")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        do {
            _ = try await documentProcessor.extractText(from: testFile)
            XCTFail("Should have thrown unsupported format error")
        } catch let error as ManyLLMError {
            if case .unsupportedFormat(let format) = error {
                XCTAssertEqual(format, "xyz")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Document Processing Tests
    
    func testProcessDocument() async throws {
        let testContent = "This is a test document for processing."
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        let result = try await documentProcessor.processDocument(from: testFile)
        
        XCTAssertEqual(result.document.filename, "test.txt")
        XCTAssertEqual(result.document.content, testContent)
        XCTAssertEqual(result.document.mimeType, "text/plain")
        XCTAssertGreaterThan(result.document.fileSize, 0)
        XCTAssertGreaterThan(result.processingTime, 0)
        XCTAssertFalse(result.document.isActive)
    }
    
    func testProcessDocumentWithChunking() async throws {
        let longContent = String(repeating: "This is a long document. ", count: 100)
        let testFile = tempDirectory.appendingPathComponent("long_test.txt")
        
        try longContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        let config = DocumentProcessingConfig(
            chunkSize: 100,
            chunkOverlap: 20,
            generateEmbeddings: false
        )
        
        let result = try await documentProcessor.processDocument(from: testFile, config: config)
        
        XCTAssertGreaterThan(result.document.chunks.count, 1)
        XCTAssertTrue(result.document.isChunked)
        
        // Verify chunk properties
        for chunk in result.document.chunks {
            XCTAssertLessThanOrEqual(chunk.content.count, config.chunkSize + config.chunkOverlap)
            XCTAssertGreaterThan(chunk.content.count, 0)
        }
    }
    
    // MARK: - Validation Tests
    
    func testValidateDocument() throws {
        let testContent = "Valid test document"
        let testFile = tempDirectory.appendingPathComponent("valid.txt")
        
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Should not throw for valid document
        XCTAssertNoThrow(try documentProcessor.validateDocument(at: testFile))
    }
    
    func testValidateNonExistentDocument() {
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")
        
        XCTAssertThrowsError(try documentProcessor.validateDocument(at: nonExistentFile)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testValidateUnsupportedFormat() throws {
        let testContent = "Test content"
        let unsupportedFile = tempDirectory.appendingPathComponent("test.xyz")
        
        try testContent.write(to: unsupportedFile, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try documentProcessor.validateDocument(at: unsupportedFile)) { error in
            if let manyLLMError = error as? ManyLLMError,
               case .unsupportedFormat(let format) = manyLLMError {
                XCTAssertEqual(format, "xyz")
            } else {
                XCTFail("Expected unsupported format error")
            }
        }
    }
    
    // MARK: - Chunk Generation Tests
    
    func testGenerateChunks() {
        let content = "This is a test document with multiple sentences. It should be split into chunks properly. Each chunk should have the right size and overlap."
        
        let chunks = documentProcessor.generateChunks(
            from: content,
            chunkSize: 50,
            overlap: 10
        )
        
        XCTAssertGreaterThan(chunks.count, 1)
        
        // Verify chunk properties
        for (index, chunk) in chunks.enumerated() {
            XCTAssertLessThanOrEqual(chunk.content.count, 50)
            XCTAssertEqual(chunk.startIndex, index == 0 ? 0 : chunks[index - 1].endIndex - 10)
            XCTAssertGreaterThan(chunk.endIndex, chunk.startIndex)
        }
    }
    
    func testGenerateChunksEmptyContent() {
        let chunks = documentProcessor.generateChunks(
            from: "",
            chunkSize: 100,
            overlap: 20
        )
        
        XCTAssertTrue(chunks.isEmpty)
    }
    
    func testGenerateChunksSmallContent() {
        let content = "Small"
        
        let chunks = documentProcessor.generateChunks(
            from: content,
            chunkSize: 100,
            overlap: 20
        )
        
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].content, content)
        XCTAssertEqual(chunks[0].startIndex, 0)
        XCTAssertEqual(chunks[0].endIndex, content.count)
    }
    
    // MARK: - Multiple Document Processing Tests
    
    func testProcessMultipleDocuments() async throws {
        let testFiles = [
            ("test1.txt", "Content of first document"),
            ("test2.txt", "Content of second document"),
            ("test3.txt", "Content of third document")
        ]
        
        var fileURLs: [URL] = []
        
        for (filename, content) in testFiles {
            let fileURL = tempDirectory.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            fileURLs.append(fileURL)
        }
        
        var progressUpdates: [(Int, Int)] = []
        
        let results = try await documentProcessor.processDocuments(
            from: fileURLs,
            config: .default
        ) { completed, total in
            progressUpdates.append((completed, total))
        }
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(progressUpdates.count, 3)
        XCTAssertEqual(progressUpdates.last?.0, 3)
        XCTAssertEqual(progressUpdates.last?.1, 3)
        
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.document.filename, testFiles[index].0)
            XCTAssertEqual(result.document.content, testFiles[index].1)
        }
    }
    
    // MARK: - Processing State Tests
    
    func testProcessingState() async throws {
        XCTAssertFalse(documentProcessor.isProcessing)
        
        let testContent = "Test document"
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Start processing in background
        let processingTask = Task {
            _ = try await documentProcessor.processDocument(from: testFile)
        }
        
        // Give it a moment to start
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        await processingTask.value
        
        XCTAssertFalse(documentProcessor.isProcessing)
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessingErrorHandling() async {
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.txt")
        
        do {
            _ = try await documentProcessor.processDocument(from: nonExistentFile)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - DOCX Processing Tests
    
    func testDOCXProcessing() async throws {
        // Create a mock DOCX file (with ZIP signature)
        let docxFile = tempDirectory.appendingPathComponent("test.docx")
        let zipSignature = Data([0x50, 0x4B, 0x03, 0x04]) // "PK" ZIP signature
        let mockDocxData = zipSignature + Data("mock docx content".utf8)
        
        try mockDocxData.write(to: docxFile)
        
        let extractedText = try await documentProcessor.extractText(from: docxFile)
        
        XCTAssertTrue(extractedText.contains("[DOCX Document: test.docx]"))
        XCTAssertTrue(extractedText.contains("Microsoft Word document"))
    }
    
    func testInvalidDOCXProcessing() async {
        let invalidDocxFile = tempDirectory.appendingPathComponent("invalid.docx")
        try "not a docx file".write(to: invalidDocxFile, atomically: true, encoding: .utf8)
        
        do {
            _ = try await documentProcessor.extractText(from: invalidDocxFile)
            XCTFail("Should have thrown an error for invalid DOCX")
        } catch let error as ManyLLMError {
            if case .documentProcessingFailed(let message) = error {
                XCTAssertTrue(message.contains("valid DOCX document"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteDocumentWorkflow() async throws {
        // Create test files of different types
        let txtFile = tempDirectory.appendingPathComponent("test.txt")
        let csvFile = tempDirectory.appendingPathComponent("test.csv")
        let pdfFile = tempDirectory.appendingPathComponent("test.pdf") // We'll skip PDF for this test
        
        try "This is a test text document with some content.".write(to: txtFile, atomically: true, encoding: .utf8)
        try "Name,Age,City\nJohn,25,NYC\nJane,30,LA".write(to: csvFile, atomically: true, encoding: .utf8)
        
        let files = [txtFile, csvFile]
        
        // Process all files
        let results = try await documentProcessor.processDocuments(
            from: files,
            config: DocumentProcessingConfig(chunkSize: 50, chunkOverlap: 10)
        ) { completed, total in
            XCTAssertLessThanOrEqual(completed, total)
        }
        
        XCTAssertEqual(results.count, 2)
        
        // Verify TXT processing
        let txtResult = results.first { $0.document.filename == "test.txt" }
        XCTAssertNotNil(txtResult)
        XCTAssertEqual(txtResult?.document.mimeType, "text/plain")
        XCTAssertTrue(txtResult?.document.content.contains("test text document") ?? false)
        
        // Verify CSV processing
        let csvResult = results.first { $0.document.filename == "test.csv" }
        XCTAssertNotNil(csvResult)
        XCTAssertEqual(csvResult?.document.mimeType, "text/csv")
        XCTAssertTrue(csvResult?.document.content.contains("Headers: Name, Age, City") ?? false)
        XCTAssertTrue(csvResult?.document.content.contains("John") ?? false)
    }
}