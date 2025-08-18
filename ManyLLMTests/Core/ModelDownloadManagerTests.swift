import XCTest
@testable import ManyLLM

@MainActor
final class ModelDownloadManagerTests: XCTestCase {
    var localRepository: LocalModelRepository!
    var remoteRepository: RemoteModelRepository!
    var downloadManager: ModelDownloadManager!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMDownloadTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create repositories and download manager
        localRepository = try LocalModelRepository()
        remoteRepository = try RemoteModelRepository(localRepository: localRepository)
        downloadManager = ModelDownloadManager(
            remoteRepository: remoteRepository,
            localRepository: localRepository
        )
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        downloadManager = nil
        remoteRepository = nil
        localRepository = nil
    }
    
    func testDownloadManagerInitialization() {
        XCTAssertNotNil(downloadManager)
        XCTAssertTrue(downloadManager.activeDownloads.isEmpty)
        XCTAssertTrue(downloadManager.downloadHistory.isEmpty)
    }
    
    func testDownloadValidation() async {
        // Test download validation for local model
        let localModel = ModelInfo(
            id: "local-test",
            name: "Local Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            isLocal: true
        )
        
        do {
            try await downloadManager.downloadModel(localModel)
            XCTFail("Should have thrown error for local model")
        } catch let error as ManyLLMError {
            if case .validationError(let message) = error {
                XCTAssertTrue(message.contains("already downloaded"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Test download validation for model without URL
        let modelWithoutURL = ModelInfo(
            id: "no-url-test",
            name: "No URL Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: nil
        )
        
        do {
            try await downloadManager.downloadModel(modelWithoutURL)
            XCTFail("Should have thrown error for model without URL")
        } catch let error as ManyLLMError {
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("No download URL"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDownloadProgressTracking() {
        let testModel = ModelInfo(
            id: "progress-test",
            name: "Progress Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 5000000,
            parameters: "1B",
            downloadURL: URL(string: "https://example.com/model.bin")
        )
        
        // Initially no progress
        XCTAssertNil(downloadManager.getDownloadProgress(for: testModel.id))
        
        // Test active downloads list
        let activeDownloads = downloadManager.getActiveDownloads()
        XCTAssertTrue(activeDownloads.isEmpty)
    }
    
    func testDownloadCancellation() async {
        // Test cancelling non-existent download
        do {
            try downloadManager.cancelDownload(modelId: "nonexistent")
            XCTFail("Should have thrown error for non-existent download")
        } catch let error as ManyLLMError {
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("No active download"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDownloadStatistics() {
        let stats = downloadManager.getDownloadStatistics()
        
        XCTAssertEqual(stats.totalDownloads, 0)
        XCTAssertEqual(stats.successfulDownloads, 0)
        XCTAssertEqual(stats.failedDownloads, 0)
        XCTAssertEqual(stats.cancelledDownloads, 0)
        XCTAssertEqual(stats.activeDownloads, 0)
        XCTAssertEqual(stats.totalBytesDownloaded, 0)
        XCTAssertEqual(stats.successRate, 0.0)
    }
    
    func testDownloadHistoryManagement() {
        // Initially empty
        XCTAssertTrue(downloadManager.downloadHistory.isEmpty)
        
        // Clear empty history (should not crash)
        downloadManager.clearDownloadHistory()
        XCTAssertTrue(downloadManager.downloadHistory.isEmpty)
    }
    
    func testRetryDownload() async {
        // Test retry for non-existent download
        do {
            try await downloadManager.retryDownload(modelId: "nonexistent")
            XCTFail("Should have thrown error for non-existent download")
        } catch let error as ManyLLMError {
            if case .validationError(let message) = error {
                XCTAssertTrue(message.contains("No failed download"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testConcurrentDownloadLimit() async {
        // Create multiple test models
        let models = (1...5).map { index in
            ModelInfo(
                id: "concurrent-test-\(index)",
                name: "Concurrent Test Model \(index)",
                author: "Test Author",
                description: "Test Description",
                size: 1000000,
                parameters: "1B",
                downloadURL: URL(string: "https://example.com/model\(index).bin")
            )
        }
        
        // This test would require mocking the actual download process
        // For now, we just verify the models are properly configured
        for model in models {
            XCTAssertNotNil(model.downloadURL)
            XCTAssertFalse(model.isLocal)
            XCTAssertTrue(model.canDownload)
        }
    }
}

// MARK: - Download Progress Tests

extension ModelDownloadManagerTests {
    
    func testDownloadProgressCreation() {
        let progress = DownloadProgress(
            modelId: "test-id",
            modelName: "Test Model",
            modelSize: 5000000,
            startTime: Date()
        )
        
        XCTAssertEqual(progress.modelId, "test-id")
        XCTAssertEqual(progress.modelName, "Test Model")
        XCTAssertEqual(progress.modelSize, 5000000)
        XCTAssertEqual(progress.progress, 0.0)
        XCTAssertEqual(progress.status, .pending)
        XCTAssertEqual(progress.downloadSpeed, 0.0)
        XCTAssertNil(progress.estimatedTimeRemaining)
        XCTAssertNil(progress.error)
    }
    
    func testDownloadProgressFormatting() {
        let progress = DownloadProgress(
            modelId: "format-test",
            modelName: "Format Test Model",
            modelSize: 5000000,
            startTime: Date().addingTimeInterval(-60)
        )
        
        progress.progress = 0.5
        progress.downloadSpeed = 1000000 // 1 MB/s
        progress.estimatedTimeRemaining = 120 // 2 minutes
        
        XCTAssertFalse(progress.downloadSpeedString.isEmpty)
        XCTAssertNotNil(progress.etaString)
        XCTAssertFalse(progress.modelSizeString.isEmpty)
    }
    
    func testDownloadRecord() {
        let progress = DownloadProgress(
            modelId: "record-test",
            modelName: "Record Test Model",
            modelSize: 3000000,
            startTime: Date().addingTimeInterval(-300)
        )
        
        progress.status = .completed
        progress.endTime = Date()
        
        let record = DownloadRecord(from: progress)
        
        XCTAssertEqual(record.modelId, progress.modelId)
        XCTAssertEqual(record.modelName, progress.modelName)
        XCTAssertEqual(record.modelSize, progress.modelSize)
        XCTAssertEqual(record.status, .completed)
        XCTAssertNotNil(record.duration)
        XCTAssertNotNil(record.durationString)
    }
    
    func testDownloadStatusProperties() {
        XCTAssertTrue(DownloadStatus.pending.isActive)
        XCTAssertTrue(DownloadStatus.downloading.isActive)
        XCTAssertFalse(DownloadStatus.completed.isActive)
        XCTAssertFalse(DownloadStatus.failed.isActive)
        XCTAssertFalse(DownloadStatus.cancelled.isActive)
        
        XCTAssertEqual(DownloadStatus.pending.displayName, "Pending")
        XCTAssertEqual(DownloadStatus.downloading.displayName, "Downloading")
        XCTAssertEqual(DownloadStatus.completed.displayName, "Completed")
        XCTAssertEqual(DownloadStatus.failed.displayName, "Failed")
        XCTAssertEqual(DownloadStatus.cancelled.displayName, "Cancelled")
    }
}