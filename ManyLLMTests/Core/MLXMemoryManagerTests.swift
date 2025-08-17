import XCTest
@testable import ManyLLM

@available(macOS 13.0, *)
final class MLXMemoryManagerTests: XCTestCase {
    
    var memoryManager: MLXMemoryManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        memoryManager = MLXMemoryManager()
    }
    
    override func tearDownWithError() throws {
        memoryManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Memory Usage Tests
    
    func testGetCurrentMemoryUsage() {
        let memoryInfo = memoryManager.getCurrentMemoryUsage()
        
        XCTAssertGreaterThan(memoryInfo.totalMemory, 0)
        XCTAssertGreaterThanOrEqual(memoryInfo.usedMemory, 0)
        XCTAssertGreaterThan(memoryInfo.availableMemory, 0)
        XCTAssertLessThanOrEqual(memoryInfo.usedMemory, memoryInfo.totalMemory)
        XCTAssertEqual(memoryInfo.usedMemory + memoryInfo.availableMemory, memoryInfo.totalMemory)
    }
    
    func testMemoryUsageFormatting() {
        let memoryInfo = memoryManager.getCurrentMemoryUsage()
        
        XCTAssertFalse(memoryInfo.formattedTotalMemory.isEmpty)
        XCTAssertFalse(memoryInfo.formattedUsedMemory.isEmpty)
        XCTAssertFalse(memoryInfo.formattedAvailableMemory.isEmpty)
        
        // Should contain GB or MB
        XCTAssertTrue(memoryInfo.formattedTotalMemory.contains("GB") || memoryInfo.formattedTotalMemory.contains("MB"))
    }
    
    func testUsagePercentage() {
        let memoryInfo = memoryManager.getCurrentMemoryUsage()
        
        XCTAssertGreaterThanOrEqual(memoryInfo.usagePercentage, 0.0)
        XCTAssertLessThanOrEqual(memoryInfo.usagePercentage, 1.0)
    }
    
    // MARK: - Memory Allocation Tests
    
    func testCanAllocateMemorySmallAmount() {
        let smallAmount: Int64 = 100 * 1024 * 1024 // 100MB
        let canAllocate = memoryManager.canAllocateMemory(size: smallAmount)
        
        // Should be able to allocate 100MB on any reasonable system
        XCTAssertTrue(canAllocate)
    }
    
    func testCanAllocateMemoryLargeAmount() {
        let largeAmount: Int64 = 100 * 1024 * 1024 * 1024 // 100GB
        let canAllocate = memoryManager.canAllocateMemory(size: largeAmount)
        
        // Should not be able to allocate 100GB on most systems
        XCTAssertFalse(canAllocate)
    }
    
    func testGetRecommendedAllocationSmallModel() {
        let smallModelSize: Int64 = 500 * 1024 * 1024 // 500MB
        let recommendation = memoryManager.getRecommendedAllocation(for: smallModelSize)
        
        XCTAssertTrue(recommendation.canLoad)
        XCTAssertEqual(recommendation.strategy, .optimal)
        XCTAssertGreaterThan(recommendation.requiredMemory, smallModelSize) // Should include overhead
        XCTAssertNotEqual(recommendation.estimatedPerformance, .poor)
    }
    
    func testGetRecommendedAllocationLargeModel() {
        let largeModelSize: Int64 = 50 * 1024 * 1024 * 1024 // 50GB
        let recommendation = memoryManager.getRecommendedAllocation(for: largeModelSize)
        
        // On most systems, 50GB model should not be loadable
        XCTAssertFalse(recommendation.canLoad)
        XCTAssertEqual(recommendation.strategy, .impossible)
    }
    
    // MARK: - GPU Memory Tests
    
    func testGetGPUMemoryInfo() {
        let gpuInfo = memoryManager.getGPUMemoryInfo()
        
        XCTAssertGreaterThan(gpuInfo.totalGPUMemory, 0)
        XCTAssertGreaterThanOrEqual(gpuInfo.usedGPUMemory, 0)
        XCTAssertGreaterThan(gpuInfo.availableGPUMemory, 0)
        XCTAssertTrue(gpuInfo.isUnifiedMemory) // Should be true on Apple Silicon
        
        XCTAssertGreaterThanOrEqual(gpuInfo.gpuUsagePercentage, 0.0)
        XCTAssertLessThanOrEqual(gpuInfo.gpuUsagePercentage, 1.0)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testDetectMemoryPressure() {
        let pressure = memoryManager.detectMemoryPressure()
        
        // Should return a valid pressure level
        switch pressure {
        case .normal, .warning, .critical:
            break // All valid
        }
        
        XCTAssertFalse(pressure.description.isEmpty)
        XCTAssertFalse(pressure.color.isEmpty)
    }
    
    // MARK: - Memory Monitoring Tests
    
    func testStartMemoryMonitoring() {
        let expectation = XCTestExpectation(description: "Memory monitoring callback")
        var callbackCount = 0
        
        let timer = memoryManager.startMemoryMonitoring(interval: 0.1) { memoryInfo in
            callbackCount += 1
            XCTAssertGreaterThan(memoryInfo.totalMemory, 0)
            
            if callbackCount >= 2 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        timer.invalidate()
        
        XCTAssertGreaterThanOrEqual(callbackCount, 2)
    }
    
    // MARK: - Memory Cleanup Tests
    
    func testPerformMemoryCleanup() async {
        // Should not throw or crash
        await memoryManager.performMemoryCleanup()
        
        // Memory cleanup is async, so we just verify it completes
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testMemoryInfoPerformance() {
        measure {
            _ = memoryManager.getCurrentMemoryUsage()
        }
    }
    
    func testAllocationCheckPerformance() {
        let testSize: Int64 = 1024 * 1024 * 1024 // 1GB
        
        measure {
            _ = memoryManager.canAllocateMemory(size: testSize)
        }
    }
    
    // MARK: - Data Structure Tests
    
    func testMemoryAllocationRecommendation() {
        let recommendation = MemoryAllocationRecommendation(
            canLoad: true,
            strategy: .optimal,
            requiredMemory: 1024 * 1024 * 1024,
            availableMemory: 8 * 1024 * 1024 * 1024,
            estimatedPerformance: .excellent
        )
        
        XCTAssertTrue(recommendation.canLoad)
        XCTAssertEqual(recommendation.strategy, .optimal)
        XCTAssertFalse(recommendation.recommendation.isEmpty)
        XCTAssertTrue(recommendation.recommendation.contains("Optimal"))
    }
    
    func testAllocationStrategyRecommendations() {
        let strategies: [AllocationStrategy] = [.optimal, .conservative, .aggressive, .impossible]
        
        for strategy in strategies {
            let recommendation = MemoryAllocationRecommendation(
                canLoad: strategy != .impossible,
                strategy: strategy,
                requiredMemory: 1024,
                availableMemory: 2048,
                estimatedPerformance: .good
            )
            
            XCTAssertFalse(recommendation.recommendation.isEmpty)
            
            switch strategy {
            case .optimal:
                XCTAssertTrue(recommendation.recommendation.contains("Optimal"))
            case .conservative:
                XCTAssertTrue(recommendation.recommendation.contains("Conservative"))
            case .aggressive:
                XCTAssertTrue(recommendation.recommendation.contains("Aggressive"))
            case .impossible:
                XCTAssertTrue(recommendation.recommendation.contains("Impossible"))
            }
        }
    }
    
    func testMemoryPressureDescriptions() {
        let pressures: [MemoryPressure] = [.normal, .warning, .critical]
        
        for pressure in pressures {
            XCTAssertFalse(pressure.description.isEmpty)
            XCTAssertFalse(pressure.color.isEmpty)
            
            switch pressure {
            case .normal:
                XCTAssertEqual(pressure.color, "green")
            case .warning:
                XCTAssertEqual(pressure.color, "yellow")
            case .critical:
                XCTAssertEqual(pressure.color, "red")
            }
        }
    }
    
    func testPerformanceEstimateDescriptions() {
        let estimates: [PerformanceEstimate] = [.excellent, .good, .fair, .poor]
        
        for estimate in estimates {
            XCTAssertFalse(estimate.description.isEmpty)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroMemoryAllocation() {
        let canAllocate = memoryManager.canAllocateMemory(size: 0)
        XCTAssertTrue(canAllocate) // Should be able to "allocate" zero bytes
    }
    
    func testNegativeMemoryAllocation() {
        let canAllocate = memoryManager.canAllocateMemory(size: -1024)
        XCTAssertTrue(canAllocate) // Negative allocation should be treated as zero
    }
    
    func testVerySmallModelRecommendation() {
        let tinyModelSize: Int64 = 1024 // 1KB
        let recommendation = memoryManager.getRecommendedAllocation(for: tinyModelSize)
        
        XCTAssertTrue(recommendation.canLoad)
        XCTAssertEqual(recommendation.strategy, .optimal)
    }
}