import Foundation
import OSLog

/// Remote model repository for downloading models from external sources
class RemoteModelRepository: NSObject, ModelRepository {
    private let logger = Logger(subsystem: "com.manyllm.app", category: "RemoteModelRepository")
    private let localRepository: LocalModelRepository
    private let urlSession: URLSession
    private let fileManager = FileManager.default
    private let integrityVerifier = ModelIntegrityVerifier()
    
    // Download tracking
    private var activeDownloads: [String: DownloadTask] = [:]
    private var downloadProgressHandlers: [String: (Double) -> Void] = [:]
    private var modelInfoCache: [String: ModelInfo] = [:]
    private let downloadQueue = DispatchQueue(label: "com.manyllm.downloads", qos: .utility)
    
    // Model sources configuration
    private let modelSources: [ModelSource] = [
        ModelSource(
            name: "Hugging Face",
            baseURL: URL(string: "https://huggingface.co")!,
            apiURL: URL(string: "https://huggingface.co/api")!
        )
    ]
    
    init(localRepository: LocalModelRepository) throws {
        self.localRepository = localRepository
        
        // Configure URLSession for background downloads
        let config = URLSessionConfiguration.background(withIdentifier: "com.manyllm.downloads")
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        self.urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
        super.init()
        
        // Set self as delegate after initialization
        self.urlSession.delegate = self
        
        logger.info("RemoteModelRepository initialized with background download support")
    }
    
    deinit {
        urlSession.invalidateAndCancel()
    }
}

// MARK: - ModelRepository Protocol Implementation

extension RemoteModelRepository {
    
    func fetchAvailableModels() async throws -> [ModelInfo] {
        logger.info("Fetching available models from remote sources")
        
        var allModels: [ModelInfo] = []
        
        // Fetch from each model source
        for source in modelSources {
            do {
                let models = try await fetchModelsFromSource(source)
                allModels.append(contentsOf: models)
                logger.debug("Fetched \(models.count) models from \(source.name)")
            } catch {
                logger.error("Failed to fetch models from \(source.name): \(error.localizedDescription)")
                // Continue with other sources
            }
        }
        
        // Merge with local models
        let localModels = localRepository.getLocalModels()
        let mergedModels = mergeRemoteAndLocalModels(remote: allModels, local: localModels)
        
        logger.info("Fetched \(allModels.count) remote models, merged with \(localModels.count) local models")
        return mergedModels
    }
    
    func searchModels(query: String) async throws -> [ModelInfo] {
        return try await searchModels(query: query, filters: ModelSearchFilters())
    }
    
    func searchModels(query: String, filters: ModelSearchFilters = ModelSearchFilters()) async throws -> [ModelInfo] {
        let allModels = try await fetchAvailableModels()
        
        // Apply text search
        var filteredModels = allModels
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            filteredModels = filteredModels.filter { model in
                model.name.lowercased().contains(lowercaseQuery) ||
                model.author.lowercased().contains(lowercaseQuery) ||
                model.description.lowercased().contains(lowercaseQuery) ||
                model.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
                model.parameters.lowercased().contains(lowercaseQuery)
            }
        }
        
        // Apply filters
        filteredModels = applyFilters(to: filteredModels, filters: filters)
        
        // Apply sorting
        filteredModels = applySorting(to: filteredModels, sortBy: filters.sortBy, ascending: filters.sortAscending)
        
        return filteredModels
    }
    
    func getModelsByCategory(_ category: ModelCategory) async throws -> [ModelInfo] {
        let allModels = try await fetchAvailableModels()
        
        switch category {
        case .all:
            return allModels
        case .local:
            return allModels.filter { $0.isLocal }
        case .remote:
            return allModels.filter { !$0.isLocal }
        case .downloading:
            let downloadingIds = Set(activeDownloads.keys)
            return allModels.filter { downloadingIds.contains($0.id) }
        case .compatible:
            return allModels.filter { model in
                let checker = ModelCompatibilityChecker()
                let result = checker.checkCompatibility(for: model)
                return result.compatibility == .fullyCompatible
            }
        case .featured:
            return allModels.filter { $0.tags.contains("featured") || $0.tags.contains("popular") }
        }
    }
    
    func downloadModel(_ model: ModelInfo, progressHandler: @escaping (Double) -> Void) async throws -> ModelInfo {
        guard let downloadURL = model.downloadURL else {
            throw ManyLLMError.networkError("No download URL available for model: \(model.name)")
        }
        
        guard !model.isLocal else {
            throw ManyLLMError.validationError("Model is already downloaded locally")
        }
        
        // Check if download is already in progress
        if activeDownloads[model.id] != nil {
            throw ManyLLMError.networkError("Download already in progress for model: \(model.name)")
        }
        
        logger.info("Starting download for model: \(model.name)")
        
        // Store model info for later use
        modelInfoCache[model.id] = model
        
        return try await withCheckedThrowingContinuation { continuation in
            downloadQueue.async {
                do {
                    let downloadTask = try self.startDownload(
                        model: model,
                        url: downloadURL,
                        progressHandler: progressHandler,
                        completion: { result in
                            continuation.resume(with: result)
                        }
                    )
                    
                    self.activeDownloads[model.id] = downloadTask
                    self.downloadProgressHandlers[model.id] = progressHandler
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getLocalModels() -> [ModelInfo] {
        return localRepository.getLocalModels()
    }
    
    func getLocalModel(id: String) -> ModelInfo? {
        return localRepository.getLocalModel(id: id)
    }
    
    func deleteModel(_ model: ModelInfo) throws {
        try localRepository.deleteModel(model)
    }
    
    func isModelLocal(_ model: ModelInfo) -> Bool {
        return localRepository.isModelLocal(model)
    }
    
    func getModelPath(_ model: ModelInfo) -> URL? {
        return localRepository.getModelPath(model)
    }
    
    func verifyModelIntegrity(_ model: ModelInfo) async throws -> Bool {
        return try await localRepository.verifyModelIntegrity(model)
    }
    
    func getDownloadProgress(for modelId: String) -> Double? {
        return activeDownloads[modelId]?.progress
    }
    
    func cancelDownload(for modelId: String) throws {
        guard let downloadTask = activeDownloads[modelId] else {
            throw ManyLLMError.networkError("No active download found for model ID: \(modelId)")
        }
        
        logger.info("Cancelling download for model ID: \(modelId)")
        downloadTask.cancel()
        
        activeDownloads.removeValue(forKey: modelId)
        downloadProgressHandlers.removeValue(forKey: modelId)
    }
}

// MARK: - Search and Filtering

private extension RemoteModelRepository {
    
    func applyFilters(to models: [ModelInfo], filters: ModelSearchFilters) -> [ModelInfo] {
        var filteredModels = models
        
        // Filter by compatibility
        if let compatibility = filters.compatibility {
            let checker = ModelCompatibilityChecker()
            filteredModels = filteredModels.filter { model in
                let result = checker.checkCompatibility(for: model)
                return result.compatibility == compatibility
            }
        }
        
        // Filter by parameter size
        if let minParameters = filters.minParameters {
            filteredModels = filteredModels.filter { model in
                extractParameterCount(from: model.parameters) >= minParameters
            }
        }
        
        if let maxParameters = filters.maxParameters {
            filteredModels = filteredModels.filter { model in
                extractParameterCount(from: model.parameters) <= maxParameters
            }
        }
        
        // Filter by size
        if let minSize = filters.minSize {
            filteredModels = filteredModels.filter { $0.size >= minSize }
        }
        
        if let maxSize = filters.maxSize {
            filteredModels = filteredModels.filter { $0.size <= maxSize }
        }
        
        // Filter by author
        if let author = filters.author {
            filteredModels = filteredModels.filter { $0.author.lowercased() == author.lowercased() }
        }
        
        // Filter by tags
        if !filters.tags.isEmpty {
            filteredModels = filteredModels.filter { model in
                filters.tags.allSatisfy { tag in
                    model.tags.contains { $0.lowercased() == tag.lowercased() }
                }
            }
        }
        
        // Filter by license
        if let license = filters.license {
            filteredModels = filteredModels.filter { model in
                model.license?.lowercased().contains(license.lowercased()) == true
            }
        }
        
        return filteredModels
    }
    
    func applySorting(to models: [ModelInfo], sortBy: ModelSortOption, ascending: Bool) -> [ModelInfo] {
        let sortedModels: [ModelInfo]
        
        switch sortBy {
        case .name:
            sortedModels = models.sorted { $0.name < $1.name }
        case .author:
            sortedModels = models.sorted { $0.author < $1.author }
        case .size:
            sortedModels = models.sorted { $0.size < $1.size }
        case .parameters:
            sortedModels = models.sorted { 
                extractParameterCount(from: $0.parameters) < extractParameterCount(from: $1.parameters)
            }
        case .dateCreated:
            sortedModels = models.sorted { 
                ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
            }
        case .dateUpdated:
            sortedModels = models.sorted { 
                ($0.updatedAt ?? Date.distantPast) < ($1.updatedAt ?? Date.distantPast)
            }
        case .compatibility:
            let checker = ModelCompatibilityChecker()
            sortedModels = models.sorted { model1, model2 in
                let result1 = checker.checkCompatibility(for: model1)
                let result2 = checker.checkCompatibility(for: model2)
                return result1.compatibility > result2.compatibility
            }
        }
        
        return ascending ? sortedModels : sortedModels.reversed()
    }
    
    func extractParameterCount(from parameterString: String) -> Double {
        let cleanString = parameterString.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanString.hasSuffix("B") {
            return Double(cleanString.dropLast()) ?? 0
        } else if cleanString.hasSuffix("M") {
            return (Double(cleanString.dropLast()) ?? 0) / 1000
        } else if cleanString.hasSuffix("K") {
            return (Double(cleanString.dropLast()) ?? 0) / 1_000_000
        }
        
        return 0
    }
}

// MARK: - Download Management

private extension RemoteModelRepository {
    
    func startDownload(
        model: ModelInfo,
        url: URL,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<ModelInfo, Error>) -> Void
    ) throws -> DownloadTask {
        
        // Create temporary download directory
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("ManyLLM")
            .appendingPathComponent("Downloads")
            .appendingPathComponent(model.id)
        
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create download request
        var request = URLRequest(url: url)
        request.setValue("ManyLLM/1.0", forHTTPHeaderField: "User-Agent")
        
        // Check for partial download and add resume headers
        let tempFilePath = tempDirectory.appendingPathComponent("model.partial")
        var resumeData: Data?
        
        if fileManager.fileExists(atPath: tempFilePath.path) {
            let attributes = try fileManager.attributesOfItem(atPath: tempFilePath.path)
            if let fileSize = attributes[.size] as? Int64 {
                request.setValue("bytes=\(fileSize)-", forHTTPHeaderField: "Range")
                logger.info("Resuming download from byte \(fileSize)")
            }
        }
        
        // Create download task
        let downloadTask = urlSession.downloadTask(with: request)
        
        let task = DownloadTask(
            id: model.id,
            modelName: model.name,
            urlSessionTask: downloadTask,
            tempDirectory: tempDirectory,
            expectedSize: model.size,
            progressHandler: progressHandler,
            completion: completion
        )
        
        downloadTask.resume()
        
        logger.info("Started download task for model: \(model.name)")
        return task
    }
    
    func fetchModelsFromSource(_ source: ModelSource) async throws -> [ModelInfo] {
        // For testing purposes, return sample models
        // In a real implementation, you would make API calls to the specific source
        
        logger.info("Fetching models from source: \(source.name)")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Return sample models for testing
        return SampleModelProvider.createTestModels().filter { !$0.isLocal }
    }
    
    func mergeRemoteAndLocalModels(remote: [ModelInfo], local: [ModelInfo]) -> [ModelInfo] {
        var merged: [String: ModelInfo] = [:]
        
        // Add remote models
        for model in remote {
            merged[model.id] = model
        }
        
        // Update with local model information
        for localModel in local {
            if var remoteModel = merged[localModel.id] {
                // Update remote model with local information
                remoteModel.localPath = localModel.localPath
                remoteModel.isLocal = localModel.isLocal
                remoteModel.isLoaded = localModel.isLoaded
                remoteModel.updatedAt = localModel.updatedAt
                merged[localModel.id] = remoteModel
            } else {
                // Add local-only model
                merged[localModel.id] = localModel
            }
        }
        
        return Array(merged.values).sorted { $0.name < $1.name }
    }
    
    func handleDownloadCompletion(
        task: DownloadTask,
        location: URL?,
        error: Error?
    ) {
        defer {
            activeDownloads.removeValue(forKey: task.id)
            downloadProgressHandlers.removeValue(forKey: task.id)
        }
        
        if let error = error {
            logger.error("Download failed for \(task.modelName): \(error.localizedDescription)")
            task.completion(.failure(error))
            return
        }
        
        guard let location = location else {
            let error = ManyLLMError.networkError("Download completed but no file location provided")
            task.completion(.failure(error))
            return
        }
        
        do {
            let finalModel = try processDownloadedModel(task: task, downloadLocation: location)
            logger.info("Successfully downloaded and processed model: \(task.modelName)")
            task.completion(.success(finalModel))
        } catch {
            logger.error("Failed to process downloaded model \(task.modelName): \(error.localizedDescription)")
            task.completion(.failure(error))
        }
    }
    
    func processDownloadedModel(task: DownloadTask, downloadLocation: URL) throws -> ModelInfo {
        // Move downloaded file to final location
        let finalPath = task.tempDirectory.appendingPathComponent("model.bin")
        
        if fileManager.fileExists(atPath: finalPath.path) {
            try fileManager.removeItem(at: finalPath)
        }
        
        try fileManager.moveItem(at: downloadLocation, to: finalPath)
        
        // Verify file integrity
        let attributes = try fileManager.attributesOfItem(atPath: finalPath.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw ManyLLMError.storageError("Could not determine downloaded file size")
        }
        
        // Check if file size matches expected size (with some tolerance for compression)
        let sizeDifference = abs(fileSize - task.expectedSize)
        let tolerance = max(task.expectedSize / 100, 1024 * 1024) // 1% or 1MB tolerance
        
        if sizeDifference > tolerance {
            logger.warning("Downloaded file size (\(fileSize)) differs significantly from expected size (\(task.expectedSize))")
        }
        
        // Create updated model info
        guard let originalModel = getModelInfoForDownload(task.id) else {
            throw ManyLLMError.modelNotFound("Original model info not found for download task")
        }
        
        var updatedModel = originalModel
        updatedModel.localPath = finalPath
        updatedModel.isLocal = true
        updatedModel.size = fileSize
        updatedModel.updatedAt = Date()
        
        // Add to local repository
        let finalModel = try localRepository.addModel(updatedModel, at: finalPath)
        
        // Verify integrity of the downloaded model
        do {
            let verificationResult = try await integrityVerifier.verifyModel(finalModel)
            if !verificationResult.isValid {
                logger.warning("Downloaded model failed integrity verification: \(verificationResult.summary)")
                // Don't fail the download, but log the issue
            } else {
                logger.info("Downloaded model passed integrity verification")
            }
        } catch {
            logger.error("Failed to verify downloaded model integrity: \(error.localizedDescription)")
            // Don't fail the download for verification errors
        }
        
        // Clean up temp directory and cache
        try? fileManager.removeItem(at: task.tempDirectory)
        modelInfoCache.removeValue(forKey: task.id)
        
        return finalModel
    }
    
    func getModelInfoForDownload(_ downloadId: String) -> ModelInfo? {
        return modelInfoCache[downloadId]
    }
}

// MARK: - URLSessionDownloadDelegate

extension RemoteModelRepository: URLSessionDownloadDelegate {
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Find the corresponding download task
        let matchingTask = activeDownloads.values.first { task in
            task.urlSessionTask == downloadTask
        }
        
        guard let task = matchingTask else {
            logger.error("No matching download task found for completed download")
            return
        }
        
        handleDownloadCompletion(task: task, location: location, error: nil)
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Find the corresponding download task
        let matchingTask = activeDownloads.values.first { task in
            task.urlSessionTask == downloadTask
        }
        
        guard let task = matchingTask else { return }
        
        let progress = totalBytesExpectedToWrite > 0 
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0
        
        task.progress = progress
        
        DispatchQueue.main.async {
            task.progressHandler(progress)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        logger.info("Download resumed at offset \(fileOffset), expected total: \(expectedTotalBytes)")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Find the corresponding download task
            let matchingTask = activeDownloads.values.first { downloadTask in
                downloadTask.urlSessionTask == task
            }
            
            guard let downloadTask = matchingTask else {
                logger.error("No matching download task found for failed download")
                return
            }
            
            handleDownloadCompletion(task: downloadTask, location: nil, error: error)
        }
    }
}

// MARK: - Supporting Types

private struct ModelSource {
    let name: String
    let baseURL: URL
    let apiURL: URL
}

private class DownloadTask {
    let id: String
    let modelName: String
    let urlSessionTask: URLSessionDownloadTask
    let tempDirectory: URL
    let expectedSize: Int64
    let progressHandler: (Double) -> Void
    let completion: (Result<ModelInfo, Error>) -> Void
    
    var progress: Double = 0.0
    
    init(
        id: String,
        modelName: String,
        urlSessionTask: URLSessionDownloadTask,
        tempDirectory: URL,
        expectedSize: Int64,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<ModelInfo, Error>) -> Void
    ) {
        self.id = id
        self.modelName = modelName
        self.urlSessionTask = urlSessionTask
        self.tempDirectory = tempDirectory
        self.expectedSize = expectedSize
        self.progressHandler = progressHandler
        self.completion = completion
    }
    
    func cancel() {
        urlSessionTask.cancel()
    }
}