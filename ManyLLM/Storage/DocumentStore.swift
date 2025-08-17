import Foundation
import CoreData
import OSLog

/// Store for managing document persistence operations
class DocumentStore: ObservableObject {
    private let coreDataStack: CoreDataStack
    private let logger = Logger(subsystem: "com.manyllm.desktop", category: "DocumentStore")
    
    @Published var documents: [ProcessedDocument] = []
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
        loadDocuments()
    }
    
    // MARK: - Public Interface
    
    /// Saves a processed document
    func saveDocument(_ document: ProcessedDocument) throws {
        logger.debug("Saving document: \(document.filename)")
        
        try coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            let entity: DocumentEntity
            if let existingEntity = entities.first {
                entity = existingEntity
            } else {
                entity = DocumentEntity(context: context)
            }
            
            self.populateEntity(entity, from: document, in: context)
        }
        
        await MainActor.run {
            if let index = documents.firstIndex(where: { $0.id == document.id }) {
                documents[index] = document
            } else {
                documents.append(document)
            }
        }
        
        logger.debug("Document saved successfully")
    }
    
    /// Loads all documents from storage
    func loadDocuments() {
        logger.info("Loading documents from storage")
        
        Task {
            do {
                let loadedDocuments = try await coreDataStack.performBackgroundTask { context in
                    let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DocumentEntity.processedAt, ascending: false)]
                    
                    let entities = try context.fetch(fetchRequest)
                    return entities.compactMap { self.createDocument(from: $0) }
                }
                
                await MainActor.run {
                    self.documents = loadedDocuments
                }
                
                logger.info("Loaded \(loadedDocuments.count) documents")
            } catch {
                logger.error("Failed to load documents: \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets a document by ID
    func getDocument(id: UUID) -> ProcessedDocument? {
        return documents.first { $0.id == id }
    }
    
    /// Gets documents by IDs
    func getDocuments(ids: [UUID]) -> [ProcessedDocument] {
        return documents.filter { ids.contains($0.id) }
    }
    
    /// Deletes a document
    func deleteDocument(_ document: ProcessedDocument) throws {
        logger.info("Deleting document: \(document.filename)")
        
        try coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            for entity in entities {
                context.delete(entity)
            }
        }
        
        await MainActor.run {
            documents.removeAll { $0.id == document.id }
        }
        
        logger.info("Document deleted successfully")
    }
    
    /// Updates document active status
    func updateDocumentActiveStatus(_ documentId: UUID, isActive: Bool) throws {
        guard let document = getDocument(id: documentId) else {
            throw ManyLLMError.storageError("Document not found")
        }
        
        var updatedDocument = document
        updatedDocument.isActive = isActive
        
        try saveDocument(updatedDocument)
        logger.debug("Updated document active status: \(documentId) -> \(isActive)")
    }
    
    /// Gets all active documents
    func getActiveDocuments() -> [ProcessedDocument] {
        return documents.filter { $0.isActive }
    }
    
    /// Gets documents by file extension
    func getDocuments(withExtension extension: String) -> [ProcessedDocument] {
        return documents.filter { $0.fileExtension.lowercased() == `extension`.lowercased() }
    }
    
    // MARK: - Private Methods
    
    private func populateEntity(_ entity: DocumentEntity, from document: ProcessedDocument, in context: NSManagedObjectContext) {
        entity.id = document.id
        entity.originalURLString = document.originalURL.absoluteString
        entity.filename = document.filename
        entity.fileSize = document.fileSize
        entity.mimeType = document.mimeType
        entity.content = document.content
        entity.processedAt = document.processedAt
        entity.isActive = document.isActive
        entity.fileExtension = document.fileExtension
        entity.characterCount = Int32(document.characterCount)
        entity.wordCount = Int32(document.wordCount)
        entity.chunkCount = Int32(document.chunkCount)
        entity.hasEmbeddings = document.hasEmbeddings
        
        // Document metadata
        let metadata = document.metadata
        entity.title = metadata.title
        entity.author = metadata.author
        entity.subject = metadata.subject
        entity.keywords = metadata.keywords
        entity.creationDate = metadata.creationDate
        entity.modificationDate = metadata.modificationDate
        entity.pageCount = metadata.pageCount.map { Int32($0) }
        entity.language = metadata.language
        entity.processingDuration = metadata.processingDuration
        entity.extractionMethod = metadata.extractionMethod
        
        // Handle chunks
        // First, remove existing chunks
        if let existingChunks = entity.chunks {
            for chunk in existingChunks {
                context.delete(chunk as! DocumentChunkEntity)
            }
        }
        
        // Add new chunks
        for chunk in document.chunks {
            let chunkEntity = DocumentChunkEntity(context: context)
            chunkEntity.id = chunk.id
            chunkEntity.content = chunk.content
            chunkEntity.startIndex = Int32(chunk.startIndex)
            chunkEntity.endIndex = Int32(chunk.endIndex)
            chunkEntity.pageNumber = chunk.pageNumber.map { Int32($0) }
            chunkEntity.embeddings = chunk.embeddings
            chunkEntity.document = entity
        }
    }
    
    private func createDocument(from entity: DocumentEntity) -> ProcessedDocument? {
        guard let id = entity.id,
              let urlString = entity.originalURLString,
              let url = URL(string: urlString),
              let filename = entity.filename,
              let mimeType = entity.mimeType,
              let content = entity.content,
              let processedAt = entity.processedAt else {
            logger.error("Invalid document entity data")
            return nil
        }
        
        let metadata = DocumentMetadata(
            title: entity.title,
            author: entity.author,
            subject: entity.subject,
            keywords: entity.keywords,
            creationDate: entity.creationDate,
            modificationDate: entity.modificationDate,
            pageCount: entity.pageCount == 0 ? nil : Int(entity.pageCount),
            language: entity.language,
            processingDuration: entity.processingDuration == 0 ? nil : entity.processingDuration,
            extractionMethod: entity.extractionMethod
        )
        
        let chunks = entity.chunks?.compactMap { chunkEntity in
            createDocumentChunk(from: chunkEntity as! DocumentChunkEntity)
        } ?? []
        
        return ProcessedDocument(
            id: id,
            originalURL: url,
            filename: filename,
            fileSize: entity.fileSize,
            mimeType: mimeType,
            content: content,
            chunks: Array(chunks),
            metadata: metadata,
            processedAt: processedAt,
            isActive: entity.isActive
        )
    }
    
    private func createDocumentChunk(from entity: DocumentChunkEntity) -> DocumentChunk? {
        guard let id = entity.id,
              let content = entity.content else {
            logger.error("Invalid document chunk entity data")
            return nil
        }
        
        return DocumentChunk(
            id: id,
            content: content,
            startIndex: Int(entity.startIndex),
            endIndex: Int(entity.endIndex),
            pageNumber: entity.pageNumber == 0 ? nil : Int(entity.pageNumber),
            embeddings: entity.embeddings
        )
    }
}

// MARK: - Search and Filtering

extension DocumentStore {
    /// Searches documents by filename or content
    func searchDocuments(query: String) -> [ProcessedDocument] {
        let lowercaseQuery = query.lowercased()
        
        return documents.filter { document in
            document.filename.lowercased().contains(lowercaseQuery) ||
            document.content.lowercased().contains(lowercaseQuery) ||
            document.metadata.title?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    /// Gets documents larger than a specified size
    func getDocuments(largerThan size: Int64) -> [ProcessedDocument] {
        return documents.filter { $0.fileSize > size }
    }
    
    /// Gets documents processed after a specific date
    func getDocuments(processedAfter date: Date) -> [ProcessedDocument] {
        return documents.filter { $0.processedAt > date }
    }
}