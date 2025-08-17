import Foundation
import CoreData
import OSLog
import Combine

/// Store for managing workspace persistence operations
class WorkspaceStore: ObservableObject {
    private let coreDataStack: CoreDataStack
    private let logger = Logger(subsystem: "com.manyllm.desktop", category: "WorkspaceStore")
    
    @Published var workspaces: [Workspace] = []
    @Published var currentWorkspace: Workspace?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
        setupNotifications()
        loadWorkspaces()
    }
    
    // MARK: - Public Interface
    
    /// Creates a new workspace
    func createWorkspace(name: String) throws -> Workspace {
        logger.info("Creating new workspace: \(name)")
        
        let workspace = Workspace(name: name)
        
        try coreDataStack.performBackgroundTask { context in
            let entity = WorkspaceEntity(context: context)
            self.populateEntity(entity, from: workspace)
            return workspace
        }
        
        await MainActor.run {
            workspaces.append(workspace)
            if currentWorkspace == nil {
                currentWorkspace = workspace
            }
        }
        
        logger.info("Workspace created successfully: \(workspace.id)")
        return workspace
    }
    
    /// Saves an existing workspace
    func saveWorkspace(_ workspace: Workspace) throws {
        logger.debug("Saving workspace: \(workspace.name)")
        
        try coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<WorkspaceEntity> = WorkspaceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", workspace.id as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            if let entity = entities.first {
                // Update existing entity
                self.populateEntity(entity, from: workspace)
            } else {
                // Create new entity
                let entity = WorkspaceEntity(context: context)
                self.populateEntity(entity, from: workspace)
            }
        }
        
        await MainActor.run {
            if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[index] = workspace
            }
            
            if currentWorkspace?.id == workspace.id {
                currentWorkspace = workspace
            }
        }
        
        logger.debug("Workspace saved successfully")
    }
    
    /// Loads all workspaces from storage
    func loadWorkspaces() {
        logger.info("Loading workspaces from storage")
        
        Task {
            do {
                let loadedWorkspaces = try await coreDataStack.performBackgroundTask { context in
                    let fetchRequest: NSFetchRequest<WorkspaceEntity> = WorkspaceEntity.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkspaceEntity.lastModified, ascending: false)]
                    
                    let entities = try context.fetch(fetchRequest)
                    return entities.compactMap { self.createWorkspace(from: $0) }
                }
                
                await MainActor.run {
                    self.workspaces = loadedWorkspaces
                    if self.currentWorkspace == nil {
                        self.currentWorkspace = loadedWorkspaces.first
                    }
                }
                
                logger.info("Loaded \(loadedWorkspaces.count) workspaces")
            } catch {
                logger.error("Failed to load workspaces: \(error.localizedDescription)")
            }
        }
    }
    
    /// Deletes a workspace
    func deleteWorkspace(_ workspace: Workspace) throws {
        logger.info("Deleting workspace: \(workspace.name)")
        
        try coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<WorkspaceEntity> = WorkspaceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", workspace.id as CVarArg)
            
            let entities = try context.fetch(fetchRequest)
            
            for entity in entities {
                context.delete(entity)
            }
        }
        
        await MainActor.run {
            workspaces.removeAll { $0.id == workspace.id }
            
            if currentWorkspace?.id == workspace.id {
                currentWorkspace = workspaces.first
            }
        }
        
        logger.info("Workspace deleted successfully")
    }
    
    /// Gets a workspace by ID
    func getWorkspace(id: UUID) -> Workspace? {
        return workspaces.first { $0.id == id }
    }
    
    /// Sets the current active workspace
    func setCurrentWorkspace(_ workspace: Workspace) {
        logger.debug("Setting current workspace: \(workspace.name)")
        currentWorkspace = workspace
    }
    
    /// Adds a chat session to a workspace
    func addSession(_ session: ChatSession, to workspace: Workspace) throws {
        var updatedWorkspace = workspace
        updatedWorkspace.sessions.append(session)
        updatedWorkspace.touch()
        
        try saveWorkspace(updatedWorkspace)
        logger.debug("Added session to workspace: \(session.title)")
    }
    
    /// Updates a chat session in a workspace
    func updateSession(_ session: ChatSession, in workspace: Workspace) throws {
        var updatedWorkspace = workspace
        
        if let index = updatedWorkspace.sessions.firstIndex(where: { $0.id == session.id }) {
            updatedWorkspace.sessions[index] = session
            updatedWorkspace.touch()
            
            try saveWorkspace(updatedWorkspace)
            logger.debug("Updated session in workspace: \(session.title)")
        } else {
            throw ManyLLMError.storageError("Session not found in workspace")
        }
    }
    
    /// Removes a chat session from a workspace
    func removeSession(_ session: ChatSession, from workspace: Workspace) throws {
        var updatedWorkspace = workspace
        updatedWorkspace.sessions.removeAll { $0.id == session.id }
        updatedWorkspace.touch()
        
        try saveWorkspace(updatedWorkspace)
        logger.debug("Removed session from workspace: \(session.title)")
    }
    
    /// Adds a document to a workspace
    func addDocument(_ documentId: UUID, to workspace: Workspace) throws {
        var updatedWorkspace = workspace
        
        if !updatedWorkspace.documentIds.contains(documentId) {
            updatedWorkspace.documentIds.append(documentId)
            updatedWorkspace.touch()
            
            try saveWorkspace(updatedWorkspace)
            logger.debug("Added document to workspace: \(documentId)")
        }
    }
    
    /// Removes a document from a workspace
    func removeDocument(_ documentId: UUID, from workspace: Workspace) throws {
        var updatedWorkspace = workspace
        updatedWorkspace.documentIds.removeAll { $0 == documentId }
        updatedWorkspace.touch()
        
        try saveWorkspace(updatedWorkspace)
        logger.debug("Removed document from workspace: \(documentId)")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.loadWorkspaces()
            }
            .store(in: &cancellables)
    }
    
    private func populateEntity(_ entity: WorkspaceEntity, from workspace: Workspace) {
        entity.id = workspace.id
        entity.name = workspace.name
        entity.createdAt = workspace.createdAt
        entity.lastModified = workspace.lastModified
        
        // Workspace settings
        if let settings = workspace.settings {
            entity.defaultModel = settings.defaultModel
            entity.defaultSystemPrompt = settings.defaultSystemPrompt
            entity.defaultTemperature = settings.defaultTemperature ?? 0
            entity.defaultMaxTokens = Int32(settings.defaultMaxTokens ?? 0)
            entity.autoSave = settings.autoSave
        }
        
        // Handle sessions - this is a simplified approach
        // In a full implementation, you'd want to properly manage the relationships
        // For now, we'll store session data as part of the workspace entity
    }
    
    private func createWorkspace(from entity: WorkspaceEntity) -> Workspace? {
        guard let id = entity.id,
              let name = entity.name,
              let createdAt = entity.createdAt,
              let lastModified = entity.lastModified else {
            logger.error("Invalid workspace entity data")
            return nil
        }
        
        let settings = WorkspaceSettings(
            defaultModel: entity.defaultModel,
            defaultSystemPrompt: entity.defaultSystemPrompt,
            defaultTemperature: entity.defaultTemperature == 0 ? nil : entity.defaultTemperature,
            defaultMaxTokens: entity.defaultMaxTokens == 0 ? nil : Int(entity.defaultMaxTokens),
            autoSave: entity.autoSave
        )
        
        // Load sessions from the relationship
        let sessions = entity.sessions?.compactMap { sessionEntity in
            createChatSession(from: sessionEntity as! ChatSessionEntity)
        } ?? []
        
        // Load document IDs from the relationship
        let documentIds = entity.documents?.compactMap { documentEntity in
            (documentEntity as! DocumentEntity).id
        } ?? []
        
        return Workspace(
            id: id,
            name: name,
            sessions: Array(sessions),
            documentIds: Array(documentIds),
            createdAt: createdAt,
            lastModified: lastModified,
            settings: settings
        )
    }
    
    private func createChatSession(from entity: ChatSessionEntity) -> ChatSession? {
        guard let id = entity.id,
              let title = entity.title,
              let createdAt = entity.createdAt,
              let lastModified = entity.lastModified else {
            logger.error("Invalid chat session entity data")
            return nil
        }
        
        let messages = entity.messages?.compactMap { messageEntity in
            createChatMessage(from: messageEntity as! MessageEntity)
        } ?? []
        
        return ChatSession(
            id: id,
            title: title,
            messages: Array(messages),
            createdAt: createdAt,
            lastModified: lastModified,
            modelUsed: entity.modelUsed
        )
    }
    
    private func createChatMessage(from entity: MessageEntity) -> ChatMessage? {
        guard let id = entity.id,
              let content = entity.content,
              let roleString = entity.role,
              let role = MessageRole(rawValue: roleString),
              let timestamp = entity.timestamp else {
            logger.error("Invalid message entity data")
            return nil
        }
        
        let metadata = MessageMetadata(
            modelUsed: entity.modelUsed,
            inferenceTime: entity.inferenceTime == 0 ? nil : entity.inferenceTime,
            tokenCount: entity.tokenCount == 0 ? nil : Int(entity.tokenCount),
            temperature: entity.temperature == 0 ? nil : entity.temperature,
            maxTokens: entity.maxTokens == 0 ? nil : Int(entity.maxTokens),
            documentReferences: entity.documentReferences
        )
        
        return ChatMessage(
            id: id,
            content: content,
            role: role,
            timestamp: timestamp,
            metadata: metadata
        )
    }
}

// MARK: - Convenience Extensions

extension WorkspaceStore {
    /// Creates a default workspace if none exist
    func createDefaultWorkspaceIfNeeded() {
        if workspaces.isEmpty {
            do {
                let defaultWorkspace = try createWorkspace(name: "Default Workspace")
                logger.info("Created default workspace")
            } catch {
                logger.error("Failed to create default workspace: \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the current workspace or creates a default one
    func getCurrentOrDefaultWorkspace() -> Workspace? {
        if let current = currentWorkspace {
            return current
        }
        
        createDefaultWorkspaceIfNeeded()
        return workspaces.first
    }
}