import Foundation
import PDFKit
import UniformTypeIdentifiers
import NaturalLanguage

/// Default implementation of DocumentProcessor supporting PDF, DOCX, TXT, and CSV files
@MainActor
class DefaultDocumentProcessor: DocumentProcessor, ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var isProcessing: Bool = false
    private var processingTasks: Set<Task<Void, Never>> = []
    
    let supportedExtensions: [String] = ["pdf", "txt", "csv", "docx", "doc"]
    let maxFileSize: Int64 = 100 * 1024 * 1024 // 100 MB
    
    // MARK: - DocumentProcessor Implementation
    
    func processDocument(
        from url: URL,
        config: DocumentProcessingConfig = .default
    ) async throws -> DocumentProcessingResult {
        let startTime = Date()
        
        // Validate document
        try validateDocument(at: url)
        
        // Extract basic file information
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let filename = url.lastPathComponent
        let mimeType = getMimeType(for: url)
        
        // Extract text content
        let content = try await extractText(from: url)
        
        // Extract metadata
        let metadata = try await extractMetadata(from: url)
        
        // Generate chunks
        let chunks = generateChunks(
            from: content,
            chunkSize: config.chunkSize,
            overlap: config.chunkOverlap
        )
        
        // Generate embeddings if requested
        let finalChunks: [DocumentChunk]
        if config.generateEmbeddings {
            finalChunks = try await generateEmbeddings(for: chunks)
        } else {
            finalChunks = chunks
        }
        
        // Create processed document
        let processedDocument = ProcessedDocument(
            originalURL: url,
            filename: filename,
            fileSize: fileSize,
            mimeType: mimeType,
            content: content,
            chunks: finalChunks,
            metadata: metadata,
            processedAt: Date(),
            isActive: false
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return DocumentProcessingResult(
            document: processedDocument,
            warnings: [],
            processingTime: processingTime
        )
    }
    
    func processDocuments(
        from urls: [URL],
        config: DocumentProcessingConfig = .default,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> [DocumentProcessingResult] {
        isProcessing = true
        defer { isProcessing = false }
        
        var results: [DocumentProcessingResult] = []
        
        for (index, url) in urls.enumerated() {
            do {
                let result = try await processDocument(from: url, config: config)
                results.append(result)
                progressHandler(index + 1, urls.count)
            } catch {
                // Continue processing other documents even if one fails
                print("Failed to process document \(url.lastPathComponent): \(error)")
                progressHandler(index + 1, urls.count)
            }
        }
        
        return results
    }
    
    func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try extractTextFromPDF(url: url)
        case "txt":
            return try extractTextFromTXT(url: url)
        case "csv":
            return try extractTextFromCSV(url: url)
        case "docx", "doc":
            return try extractTextFromDOCX(url: url)
        default:
            throw ManyLLMError.unsupportedFormat(fileExtension)
        }
    }
    
    func extractMetadata(from url: URL) async throws -> DocumentMetadata {
        let fileExtension = url.pathExtension.lowercased()
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        
        var metadata = DocumentMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            creationDate: fileAttributes[.creationDate] as? Date,
            modificationDate: fileAttributes[.modificationDate] as? Date,
            extractionMethod: "DefaultDocumentProcessor"
        )
        
        // Extract format-specific metadata
        switch fileExtension {
        case "pdf":
            metadata = try extractPDFMetadata(url: url, baseMetadata: metadata)
        default:
            break
        }
        
        return metadata
    }
    
    func generateChunks(
        from content: String,
        chunkSize: Int,
        overlap: Int
    ) -> [DocumentChunk] {
        guard !content.isEmpty else { return [] }
        
        var chunks: [DocumentChunk] = []
        let contentLength = content.count
        var startIndex = 0
        
        while startIndex < contentLength {
            let endIndex = min(startIndex + chunkSize, contentLength)
            let chunkContent = String(content[content.index(content.startIndex, offsetBy: startIndex)..<content.index(content.startIndex, offsetBy: endIndex)])
            
            let chunk = DocumentChunk(
                content: chunkContent,
                startIndex: startIndex,
                endIndex: endIndex
            )
            
            chunks.append(chunk)
            
            // Move to next chunk with overlap
            startIndex = max(startIndex + chunkSize - overlap, endIndex)
            
            // Prevent infinite loop
            if startIndex >= contentLength {
                break
            }
        }
        
        return chunks
    }
    
    func generateEmbeddings(for chunks: [DocumentChunk]) async throws -> [DocumentChunk] {
        // For now, return chunks without embeddings
        // In a real implementation, this would generate embeddings using a model
        return chunks.map { chunk in
            DocumentChunk(
                id: chunk.id,
                content: chunk.content,
                startIndex: chunk.startIndex,
                endIndex: chunk.endIndex,
                pageNumber: chunk.pageNumber,
                embeddings: nil // TODO: Implement actual embedding generation
            )
        }
    }
    
    func isFormatSupported(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(fileExtension)
    }
    
    func validateDocument(at url: URL) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ManyLLMError.documentProcessingFailed("File does not exist")
        }
        
        // Check file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        guard fileSize <= maxFileSize else {
            throw ManyLLMError.documentProcessingFailed("File size exceeds maximum limit of \(ByteCountFormatter().string(fromByteCount: maxFileSize))")
        }
        
        // Check if format is supported
        guard isFormatSupported(url) else {
            throw ManyLLMError.unsupportedFormat(url.pathExtension)
        }
    }
    
    func cancelProcessing() async {
        for task in processingTasks {
            task.cancel()
        }
        processingTasks.removeAll()
        isProcessing = false
    }
    
    // MARK: - Private Methods
    
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ManyLLMError.documentProcessingFailed("Unable to open PDF document")
        }
        
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                if let pageText = page.string {
                    text += pageText + "\n"
                }
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTextFromTXT(url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    private func extractTextFromCSV(url: URL) throws -> String {
        let csvContent = try String(contentsOf: url, encoding: .utf8)
        
        // Simple CSV parsing - convert to readable format
        let lines = csvContent.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return "" }
        
        var formattedText = ""
        
        // Use first line as headers if it looks like headers
        if let firstLine = lines.first, !firstLine.isEmpty {
            let headers = parseCSVLine(firstLine)
            formattedText += "Headers: " + headers.joined(separator: ", ") + "\n\n"
            
            // Process data rows
            for (index, line) in lines.dropFirst().enumerated() {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                let values = parseCSVLine(line)
                formattedText += "Row \(index + 1):\n"
                
                for (headerIndex, value) in values.enumerated() {
                    let header = headerIndex < headers.count ? headers[headerIndex] : "Column \(headerIndex + 1)"
                    formattedText += "  \(header): \(value)\n"
                }
                formattedText += "\n"
            }
        }
        
        return formattedText
    }
    
    private func extractTextFromDOCX(url: URL) throws -> String {
        // For now, provide a basic implementation that indicates DOCX files are detected
        // but full parsing requires additional libraries
        
        // Try to read the file as data to verify it's accessible
        let fileData = try Data(contentsOf: url)
        
        // Check if it's a valid ZIP file (DOCX files are ZIP archives)
        let zipSignature = Data([0x50, 0x4B, 0x03, 0x04]) // "PK" ZIP signature
        if fileData.count >= 4 && fileData.prefix(4) == zipSignature {
            // This is a valid DOCX file, but we can't extract text without additional libraries
            let filename = url.lastPathComponent
            let fileSize = ByteCountFormatter().string(fromByteCount: Int64(fileData.count))
            
            return """
            [DOCX Document: \(filename)]
            File Size: \(fileSize)
            
            Note: This is a Microsoft Word document. Full text extraction from DOCX files 
            requires additional libraries. The document has been detected and can be 
            referenced, but detailed content extraction is not yet available.
            
            To enable full DOCX support, consider:
            1. Converting the document to PDF or TXT format
            2. Adding a DOCX parsing library to the project
            """
        } else {
            throw ManyLLMError.documentProcessingFailed("File does not appear to be a valid DOCX document")
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                values.append(currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
                currentValue = ""
            } else {
                currentValue.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last value
        values.append(currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return values
    }
    
    private func extractPDFMetadata(url: URL, baseMetadata: DocumentMetadata) throws -> DocumentMetadata {
        guard let pdfDocument = PDFDocument(url: url) else {
            return baseMetadata
        }
        
        let documentAttributes = pdfDocument.documentAttributes
        
        return DocumentMetadata(
            title: documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? baseMetadata.title,
            author: documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
            subject: documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String,
            keywords: (documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? String)?.components(separatedBy: ","),
            creationDate: documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date ?? baseMetadata.creationDate,
            modificationDate: documentAttributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date ?? baseMetadata.modificationDate,
            pageCount: pdfDocument.pageCount,
            language: baseMetadata.language,
            processingDuration: baseMetadata.processingDuration,
            extractionMethod: baseMetadata.extractionMethod
        )
    }
    
    private func getMimeType(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "csv":
            return "text/csv"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc":
            return "application/msword"
        default:
            return "application/octet-stream"
        }
    }
}