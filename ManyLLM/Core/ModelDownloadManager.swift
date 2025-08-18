import Foundation
import OSLog
import Combine

/// Manages model downloads with progress tracking and error handling
@MainActor
class ModelDownloadManager: ObservableObject {
    private let logger = Logger(subsystem: "com.manyllm.app", category: "ModelDownloadManager")
    
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    @Published var downloadHistory: [DownloadRecord] = []
    
    private let remoteRepository: RemoteModelRepository
    private let localRepository: LocalModelRepository
    private var cancellables = Set<AnyCancellable>()
    
    // Download configuration
    private let maxConcurrentDownloads = 2
    private let downloadQueue = DispatchQueue(label: "com.manyllm.download-queue", qos: .utility)
    
    init(remoteRepository: RemoteModelRepository, localRepository: LocalModelRepository) {
        self.remoteRepository = remoteRepository
        self.localRepository = localRepository
        
        logger.info("ModelDownloadManager initialized")
    }
    
    /// Start downloading a model
    func downloadModel(_ model: ModelInfo) async throws {
        guard !model.isLocal else {
            throw ManyLLMError.validationError("Model '\(model.name)' is already downloaded")
        }
        
        guard model.downloadURL != nil else {
            throw ManyLLMError.networkError("No download URL available for model '\(model.name)'")
        }
        
        guard activeDownloads[model.id] == nil else {
            throw ManyLLMError.networkError("Download already in progress for model '\(model.name)'")
        }
        
        // Check concurrent download limit
        if activeDownloads.count >= maxConcurrentDownloads {
            throw ManyLLMError.networkError("Maximum concurrent downloads (\(maxConcurrentDownloads)) reached")
        }
        
        logger.info("Starting download for model: \(model.name)")
        
        // Create download progress tracker
        let downloadProgress = DownloadProgress(
            modelId: model.id,
            modelName: model.name,
            modelSize: model.size,
            startTime: Date()
        )
        
        activeDownloads[model.id] = downloadProgress
        
        do {
            // Start the download
            let downloadedModel = try await remoteRepository.downloadModel(model) { [weak self] progress in
                Task { @MainActor in
                    self?.updateDownloadProgress(modelId: model.id, progress: progress)
                }
            }
            
            // Download completed successfully
            await handleDownloadSuccess(model: downloadedModel, downloadProgress: downloadProgress)
            
        } catch {
            // Download failed
            await handleDownloadFailure(modelId: model.id, error: error, downloadProgress: downloadProgress)
            throw error
        }
    }
    
    /// Cancel an active download
    func cancelDownload(modelId: String) throws {
        guard let downloadProgress = activeDownloads[modelId] else {
            throw ManyLLMError.networkError("No active download found for model ID: \(modelId)")
        }
        
        logger.info("Cancelling download for model: \(downloadProgress.modelName)")
        
        do {
            try remoteRepository.cancelDownload(for: modelId)
            
            // Update progress state
            downloadProgress.status = .cancelled
            downloadProgress.endTime = Date()
            
            // Move to history
            let record = DownloadRecord(from: downloadProgress)
            downloadHistory.append(record)
            
            // Remove from active downloads
            activeDownloads.removeValue(forKey: modelId)
            
            logger.info("Successfully cancelled download for model: \(downloadProgress.modelName)")
            
        } catch {
            logger.error("Failed to cancel download for model \(downloadProgress.modelName): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get download progress for a specific model
    func getDownloadProgress(for modelId: String) -> DownloadProgress? {
        return activeDownloads[modelId]
    }
    
    /// Get all active downloads
    func getActiveDownloads() -> [DownloadProgress] {
        return Array(activeDownloads.values).sorted { $0.startTime < $1.startTime }
    }
    
    /// Clear download history
    func clearDownloadHistory() {
        downloadHistory.removeAll()
        logger.info("Cleared download history")
    }
    
    /// Get download statistics
    func getDownloadStatistics() -> DownloadStatistics {
        let totalDownloads = downloadHistory.count + activeDownloads.count
        let successfulDownloads = downloadHistory.filter { $0.status == .completed }.count
        let failedDownloads = downloadHistory.filter { $0.status == .failed }.count
        let cancelledDownloads = downloadHistory.filter { $0.status == .cancelled }.count
        
        let totalBytesDownloaded = downloadHistory
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.modelSize }
        
        return DownloadStatistics(
            totalDownloads: totalDownloads,
            successfulDownloads: successfulDownloads,
            failedDownloads: failedDownloads,
            cancelledDownloads: cancelledDownloads,
            activeDownloads: activeDownloads.count,
            totalBytesDownloaded: totalBytesDownloaded
        )
    }
    
    /// Retry a failed download
    func retryDownload(modelId: String) async throws {
        // Find the model in history
        guard let record = downloadHistory.first(where: { $0.modelId == modelId }),
              record.status == .failed else {
            throw ManyLLMError.validationError("No failed download found for model ID: \(modelId)")
        }
        
        // Remove from history
        downloadHistory.removeAll { $0.modelId == modelId }
        
        // Create a new ModelInfo for retry (simplified - in real implementation would fetch from repository)
        let modelInfo = ModelInfo(
            id: record.modelId,
            name: record.modelName,
            author: "Unknown",
            description: "Retry download",
            size: record.modelSize,
            parameters: "Unknown",
            downloadURL: URL(string: "https://example.com/model")! // Would be actual URL
        )
        
        try await downloadModel(modelInfo)
    }
}

// MARK: - Private Methods

private extension ModelDownloadManager {
    
    func updateDownloadProgress(modelId: String, progress: Double) {
        guard let downloadProgress = activeDownloads[modelId] else { return }
        
        downloadProgress.progress = progress
        downloadProgress.status = .downloading
        
        // Calculate download speed and ETA
        let elapsed = Date().timeIntervalSince(downloadProgress.startTime)
        if elapsed > 0 && progress > 0 {
            let bytesDownloaded = Int64(Double(downloadProgress.modelSize) * progress)
            downloadProgress.downloadSpeed = Double(bytesDownloaded) / elapsed
            
            if progress < 1.0 {
                let remainingBytes = downloadProgress.modelSize - bytesDownloaded
                downloadProgress.estimatedTimeRemaining = remainingBytes > 0 
                    ? TimeInterval(Double(remainingBytes) / downloadProgress.downloadSpeed)
                    : nil
            }
        }
        
        logger.debug("Download progress for \(downloadProgress.modelName): \(Int(progress * 100))%")
    }
    
    func handleDownloadSuccess(model: ModelInfo, downloadProgress: DownloadProgress) async {
        logger.info("Download completed successfully for model: \(model.name)")
        
        downloadProgress.status = .completed
        downloadProgress.progress = 1.0
        downloadProgress.endTime = Date()
        
        // Move to history
        let record = DownloadRecord(from: downloadProgress)
        downloadHistory.append(record)
        
        // Remove from active downloads
        activeDownloads.removeValue(forKey: model.id)
        
        // Verify integrity
        do {
            let isValid = try await localRepository.verifyModelIntegrity(model)
            if !isValid {
                logger.warning("Model integrity verification failed for: \(model.name)")
            }
        } catch {
            logger.error("Failed to verify model integrity for \(model.name): \(error.localizedDescription)")
        }
    }
    
    func handleDownloadFailure(modelId: String, error: Error, downloadProgress: DownloadProgress) async {
        logger.error("Download failed for model \(downloadProgress.modelName): \(error.localizedDescription)")
        
        downloadProgress.status = .failed
        downloadProgress.error = error
        downloadProgress.endTime = Date()
        
        // Move to history
        let record = DownloadRecord(from: downloadProgress)
        downloadHistory.append(record)
        
        // Remove from active downloads
        activeDownloads.removeValue(forKey: modelId)
    }
}

// MARK: - Supporting Types

/// Represents the progress of an active download
class DownloadProgress: ObservableObject, Identifiable {
    let id = UUID()
    let modelId: String
    let modelName: String
    let modelSize: Int64
    let startTime: Date
    
    @Published var progress: Double = 0.0
    @Published var status: DownloadStatus = .pending
    @Published var downloadSpeed: Double = 0.0 // bytes per second
    @Published var estimatedTimeRemaining: TimeInterval?
    @Published var error: Error?
    
    var endTime: Date?
    
    init(modelId: String, modelName: String, modelSize: Int64, startTime: Date) {
        self.modelId = modelId
        self.modelName = modelName
        self.modelSize = modelSize
        self.startTime = startTime
    }
    
    /// Human-readable download speed
    var downloadSpeedString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(downloadSpeed)))/s"
    }
    
    /// Human-readable ETA
    var etaString: String? {
        guard let eta = estimatedTimeRemaining else { return nil }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: eta)
    }
    
    /// Human-readable model size
    var modelSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: modelSize)
    }
}

/// Represents a completed download record
struct DownloadRecord: Identifiable {
    let id = UUID()
    let modelId: String
    let modelName: String
    let modelSize: Int64
    let startTime: Date
    let endTime: Date?
    let status: DownloadStatus
    let error: Error?
    
    init(from progress: DownloadProgress) {
        self.modelId = progress.modelId
        self.modelName = progress.modelName
        self.modelSize = progress.modelSize
        self.startTime = progress.startTime
        self.endTime = progress.endTime
        self.status = progress.status
        self.error = progress.error
    }
    
    /// Duration of the download
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Human-readable duration
    var durationString: String? {
        guard let duration = duration else { return nil }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration)
    }
}

/// Download status enumeration
enum DownloadStatus: String, CaseIterable {
    case pending = "pending"
    case downloading = "downloading"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .downloading: return "Downloading"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        return self == .pending || self == .downloading
    }
}

/// Download statistics
struct DownloadStatistics {
    let totalDownloads: Int
    let successfulDownloads: Int
    let failedDownloads: Int
    let cancelledDownloads: Int
    let activeDownloads: Int
    let totalBytesDownloaded: Int64
    
    var successRate: Double {
        guard totalDownloads > 0 else { return 0.0 }
        return Double(successfulDownloads) / Double(totalDownloads)
    }
    
    var totalBytesDownloadedString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytesDownloaded)
    }
}