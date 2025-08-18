import Foundation

/// Protocol for managing model discovery, download, and local storage
protocol ModelRepository {
    /// Fetch available models from remote repositories
    func fetchAvailableModels() async throws -> [ModelInfo]
    
    /// Search for models matching the given query
    func searchModels(query: String) async throws -> [ModelInfo]
    
    /// Search for models with advanced filters
    func searchModels(query: String, filters: ModelSearchFilters) async throws -> [ModelInfo]
    
    /// Get models by category
    func getModelsByCategory(_ category: ModelCategory) async throws -> [ModelInfo]
    
    /// Download a model to local storage
    func downloadModel(_ model: ModelInfo, progressHandler: @escaping (Double) -> Void) async throws -> ModelInfo
    
    /// Get all locally stored models
    func getLocalModels() -> [ModelInfo]
    
    /// Get a specific local model by ID
    func getLocalModel(id: String) -> ModelInfo?
    
    /// Delete a local model
    func deleteModel(_ model: ModelInfo) throws
    
    /// Check if a model exists locally
    func isModelLocal(_ model: ModelInfo) -> Bool
    
    /// Get the local path for a model
    func getModelPath(_ model: ModelInfo) -> URL?
    
    /// Verify model integrity
    func verifyModelIntegrity(_ model: ModelInfo) async throws -> Bool
    
    /// Get model download progress (if downloading)
    func getDownloadProgress(for modelId: String) -> Double?
    
    /// Cancel an ongoing download
    func cancelDownload(for modelId: String) throws
}