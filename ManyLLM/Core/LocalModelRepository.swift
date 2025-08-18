import Foundation
import OSLog

/// Local model repository for managing downloaded models on the file system
class LocalModelRepository: ModelRepository {
    private let logger = Logger(subsystem: "com.manyllm.app", category: "LocalModelRepository")
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    private let metadataFileName = "model_metadata.json"
    private let cacheFileName = "models_cache.json"
    
    // Cache for model metadata to avoid frequent file system reads
    private var modelCache: [String: ModelInfo] = [:]
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    init() throws {
        // Create models directory in Application Support
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        self.modelsDirectory = appSupportURL
            .appendingPathComponent("ManyLLM")
            .appendingPathComponent("Models")
        
        try createDirectoryStructure()
        try loadModelCache()
    }
    
    // MARK: - ModelRepository Protocol Implementation
    
    func fetchAvailableModels() async throws -> [ModelInfo] {
        // This implementation focuses on local models only
        // Remote model fetching would be implemented in a separate RemoteModelRepository
        return getLocalModels()
    }
    
    func searchModels(query: String) async throws -> [ModelInfo] {
        let localModels = getLocalModels()
        let lowercaseQuery = query.lowercased()
        
        return localModels.filter { model in
            model.name.lowercased().contains(lowercaseQuery) ||
            model.author.lowercased().contains(lowercaseQuery) ||
            model.description.lowercased().contains(lowercaseQuery) ||
            model.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func downloadModel(_ model: ModelInfo, progressHandler: @escaping (Double) -> Void) async throws -> ModelInfo {
        // This implementation focuses on local model management
        // Download functionality would be implemented in a separate RemoteModelRepository
        throw ManyLLMError.networkError("Download functionality not implemented in LocalModelRepository")
    }
    
    func getLocalModels() -> [ModelInfo] {
        do {
            try refreshCacheIfNeeded()
            return Array(modelCache.values).sorted { $0.name < $1.name }
        } catch {
            logger.error("Failed to get local models: \(error.localizedDescription)")
            return []
        }
    }
    
    func getLocalModel(id: String) -> ModelInfo? {
        do {
            try refreshCacheIfNeeded()
            return modelCache[id]
        } catch {
            logger.error("Failed to get local model \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteModel(_ model: ModelInfo) throws {
        guard model.isLocal, let localPath = model.localPath else {
            throw ManyLLMError.modelNotFound("Model is not stored locally")
        }
        
        logger.info("Deleting model: \(model.name) at \(localPath.path)")
        
        // Remove model files
        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }
        
        // Remove from cache
        modelCache.removeValue(forKey: model.id)
        
        // Save updated cache
        try saveModelCache()
        
        logger.info("Successfully deleted model: \(model.name)")
    }
    
    func isModelLocal(_ model: ModelInfo) -> Bool {
        guard let localPath = model.localPath else { return false }
        return fileManager.fileExists(atPath: localPath.path)
    }
    
    func getModelPath(_ model: ModelInfo) -> URL? {
        guard model.isLocal else { return nil }
        return model.localPath
    }
    
    func verifyModelIntegrity(_ model: ModelInfo) async throws -> Bool {
        guard let localPath = model.localPath else {
            throw ManyLLMError.modelNotFound("Model path not found")
        }
        
        guard fileManager.fileExists(atPath: localPath.path) else {
            throw ManyLLMError.modelNotFound("Model file does not exist at path: \(localPath.path)")
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: localPath.path) else {
            throw ManyLLMError.storageError("Model file is not readable")
        }
        
        // Verify file size matches expected size
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localPath.path)
            if let fileSize = attributes[.size] as? Int64 {
                if fileSize != model.size {
                    logger.warning("Model file size mismatch. Expected: \(model.size), Actual: \(fileSize)")
                    return false
                }
            }
        } catch {
            throw ManyLLMError.storageError("Failed to read model file attributes: \(error.localizedDescription)")
        }
        
        return true
    }
    
    func getDownloadProgress(for modelId: String) -> Double? {
        // Download progress tracking would be implemented in RemoteModelRepository
        return nil
    }
    
    func cancelDownload(for modelId: String) throws {
        // Download cancellation would be implemented in RemoteModelRepository
        throw ManyLLMError.networkError("Download cancellation not supported in LocalModelRepository")
    }
}

// MARK: - Local Model Management

extension LocalModelRepository {
    
    /// Add a model to the local repository
    func addModel(_ model: ModelInfo, at path: URL) throws -> ModelInfo {
        logger.info("Adding model to repository: \(model.name)")
        
        // Verify the file exists
        guard fileManager.fileExists(atPath: path.path) else {
            throw ManyLLMError.modelNotFound("Model file not found at path: \(path.path)")
        }
        
        // Create model directory
        let modelDirectory = modelsDirectory.appendingPathComponent(model.id)
        try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // Copy model file to repository
        let destinationPath = modelDirectory.appendingPathComponent(path.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.removeItem(at: destinationPath)
        }
        
        try fileManager.copyItem(at: path, to: destinationPath)
        
        // Update model info
        var updatedModel = model
        updatedModel.localPath = destinationPath
        updatedModel.isLocal = true
        updatedModel.updatedAt = Date()
        
        // Save model metadata
        try saveModelMetadata(updatedModel, to: modelDirectory)
        
        // Update cache
        modelCache[updatedModel.id] = updatedModel
        try saveModelCache()
        
        logger.info("Successfully added model: \(model.name)")
        return updatedModel
    }
    
    /// Discover models from the local file system
    func discoverLocalModels() throws {
        logger.info("Discovering local models in directory: \(modelsDirectory.path)")
        
        guard fileManager.fileExists(atPath: modelsDirectory.path) else {
            logger.info("Models directory does not exist, creating it")
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            return
        }
        
        let modelDirectories = try fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        
        for modelDirectory in modelDirectories {
            do {
                if let model = try loadModelFromDirectory(modelDirectory) {
                    modelCache[model.id] = model
                    logger.debug("Discovered model: \(model.name)")
                }
            } catch {
                logger.error("Failed to load model from directory \(modelDirectory.path): \(error.localizedDescription)")
            }
        }
        
        try saveModelCache()
        logger.info("Discovered \(modelCache.count) local models")
    }
    
    /// Get storage statistics for local models
    func getStorageStatistics() -> (totalSize: Int64, modelCount: Int) {
        let models = getLocalModels()
        let totalSize = models.reduce(0) { $0 + $1.size }
        return (totalSize: totalSize, modelCount: models.count)
    }
    
    /// Clean up orphaned model files
    func cleanupOrphanedFiles() throws {
        logger.info("Cleaning up orphaned model files")
        
        let modelDirectories = try fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        
        var cleanedCount = 0
        
        for modelDirectory in modelDirectories {
            let metadataPath = modelDirectory.appendingPathComponent(metadataFileName)
            
            // If no metadata file exists, consider it orphaned
            if !fileManager.fileExists(atPath: metadataPath.path) {
                logger.info("Removing orphaned directory: \(modelDirectory.path)")
                try fileManager.removeItem(at: modelDirectory)
                cleanedCount += 1
            }
        }
        
        logger.info("Cleaned up \(cleanedCount) orphaned directories")
    }
}

// MARK: - Private Helper Methods

private extension LocalModelRepository {
    
    func createDirectoryStructure() throws {
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        logger.info("Created models directory at: \(modelsDirectory.path)")
    }
    
    func refreshCacheIfNeeded() throws {
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) > cacheValidityDuration {
            try discoverLocalModels()
            lastCacheUpdate = now
        }
    }
    
    func loadModelCache() throws {
        let cacheURL = modelsDirectory.appendingPathComponent(cacheFileName)
        
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            // No cache file exists, discover models
            try discoverLocalModels()
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cachedModels = try decoder.decode([String: ModelInfo].self, from: data)
            self.modelCache = cachedModels
            self.lastCacheUpdate = Date()
            
            logger.info("Loaded \(cachedModels.count) models from cache")
        } catch {
            logger.error("Failed to load model cache, discovering models: \(error.localizedDescription)")
            try discoverLocalModels()
        }
    }
    
    func saveModelCache() throws {
        let cacheURL = modelsDirectory.appendingPathComponent(cacheFileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(modelCache)
        try data.write(to: cacheURL)
        
        logger.debug("Saved model cache with \(modelCache.count) models")
    }
    
    func loadModelFromDirectory(_ directory: URL) throws -> ModelInfo? {
        let metadataPath = directory.appendingPathComponent(metadataFileName)
        
        guard fileManager.fileExists(atPath: metadataPath.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: metadataPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var model = try decoder.decode(ModelInfo.self, from: data)
        
        // Verify the model file still exists
        if let localPath = model.localPath {
            model.isLocal = fileManager.fileExists(atPath: localPath.path)
        }
        
        return model
    }
    
    func saveModelMetadata(_ model: ModelInfo, to directory: URL) throws {
        let metadataPath = directory.appendingPathComponent(metadataFileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(model)
        try data.write(to: metadataPath)
        
        logger.debug("Saved metadata for model: \(model.name)")
    }
}