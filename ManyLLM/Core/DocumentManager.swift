import Foundation
import SwiftUI

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
    
    // MARK: - Private Properties
    
    private let documentProcessor: DocumentProcessor
    private let maxConcurrentProcessing = 3
    
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
    
    // MARK: - Initialization
    
    init(documentProcessor: DocumentProcessor = DefaultDocumentProcessor()) {
        self.documentProcessor = documentProcessor
    }
    
    // MARK: - Document Management
    
    /// Upload and process documents from URLs
    func uploadDocuments(from urls: [URL]) async {
        guard !urls.isEmpty else { return }
        
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Processing \(urls.count) document\(urls.count == 1 ? "" : "s")..."
        errorMessage = nil
        
        do {
            let results = try await documentProcessor.processDocuments(
                from: urls,
                config: DocumentProcessingConfig.default
            ) { completed, total in
                Task { @MainActor in
                    self.processingProgress = Double(completed) / Double(total)
                    self.processingStatus = "Processed \(completed) of \(total) documents"
                }
            }
            
            // Add successfully processed documents
            for result in results {
                if !documents.contains(where: { $0.id == result.document.id }) {
                    documents.append(result.document)
                }
            }
            
            processingStatus = "Successfully processed \(results.count) document\(results.count == 1 ? "" : "s")"
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            processingStatus = "Processing failed"
        }
        
        isProcessing = false
        
        // Clear status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.isProcessing {
                self.processingStatus = ""
            }
        }
    }
    
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
    
    /// Set all documents as active/inactive
    func setAllDocumentsActive(_ active: Bool) {
        for index in documents.indices {
            documents[index].isActive = active
        }
    }
    
    /// Get document by ID
    func getDocument(by id: UUID) -> ProcessedDocument? {
        return documents.first { $0.id == id }
    }
    
    /// Get active document content for context
    func getActiveDocumentContext() -> String {
        let activeContent = activeDocuments.map { document in
            "Document: \(document.filename)\n\(document.content)\n"
        }.joined(separator: "\n---\n\n")
        
        return activeContent
    }
    
    /// Validate if files can be processed
    func validateFiles(_ urls: [URL]) -> (valid: [URL], invalid: [(URL, String)]) {
        var validFiles: [URL] = []
        var invalidFiles: [(URL, String)] = []
        
        for url in urls {
            do {
                try documentProcessor.validateDocument(at: url)
                validFiles.append(url)
            } catch {
                invalidFiles.append((url, error.localizedDescription))
            }
        }
        
        return (validFiles, invalidFiles)
    }
    
    /// Check if a file type is supported
    func isFileSupported(_ url: URL) -> Bool {
        return documentProcessor.isFormatSupported(url)
    }
    
    /// Get supported file extensions
    var supportedExtensions: [String] {
        return documentProcessor.supportedExtensions
    }
    
    /// Cancel ongoing processing
    func cancelProcessing() async {
        await documentProcessor.cancelProcessing()
        isProcessing = false
        processingStatus = "Processing cancelled"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.processingStatus = ""
        }
    }
    
    // MARK: - Drag and Drop Support
    
    /// Handle dropped files
    func handleDroppedFiles(_ providers: [NSItemProvider]) async {
        var urls: [URL] = []
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                do {
                    let item = try await provider.loadItem(forTypeIdentifier: "public.file-url")
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                } catch {
                    print("Failed to load dropped file: \(error)")
                }
            }
        }
        
        if !urls.isEmpty {
            await uploadDocuments(from: urls)
        }
    }
    
    /// Check if drop is valid
    func canHandleDrop(_ providers: [NSItemProvider]) -> Bool {
        return providers.contains { provider in
            provider.hasItemConformingToTypeIdentifier("public.file-url")
        }
    }
}

// MARK: - Mock Data for Testing

extension DocumentManager {
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