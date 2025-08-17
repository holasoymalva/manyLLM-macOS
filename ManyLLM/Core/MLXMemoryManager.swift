import Foundation
import os.log

/// Memory management utilities for MLX models
@available(macOS 13.0, *)
class MLXMemoryManager {
    
    private let logger = Logger(subsystem: "com.manyllm.app", category: "MLXMemoryManager")
    
    // MARK: - Memory Monitoring
    
    /// Get current memory usage information
    func getCurrentMemoryUsage() -> MemoryUsageInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalMemory = getTotalPhysicalMemory()
            let usedMemory = Int64(info.resident_size)
            let availableMemory = totalMemory - usedMemory
            
            return MemoryUsageInfo(
                totalMemory: totalMemory,
                usedMemory: usedMemory,
                availableMemory: availableMemory,
                memoryPressure: calculateMemoryPressure(used: usedMemory, total: totalMemory)
            )
        } else {
            logger.error("Failed to get memory info: \(kerr)")
            return MemoryUsageInfo(
                totalMemory: 8 * 1024 * 1024 * 1024, // 8GB fallback
                usedMemory: 0,
                availableMemory: 8 * 1024 * 1024 * 1024,
                memoryPressure: .normal
            )
        }
    }
    
    /// Monitor memory usage over time
    func startMemoryMonitoring(interval: TimeInterval = 5.0, callback: @escaping (MemoryUsageInfo) -> Void) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let memoryInfo = self.getCurrentMemoryUsage()
            callback(memoryInfo)
        }
    }
    
    // MARK: - Memory Optimization
    
    /// Perform memory cleanup and optimization
    func performMemoryCleanup() async {
        logger.info("Performing memory cleanup")
        
        // Force garbage collection
        await Task.yield()
        
        // In a real MLX implementation, this would call MLX-specific cleanup functions
        // For example: MLX.clearCache(), MLX.freeUnusedMemory(), etc.
        
        logger.info("Memory cleanup completed")
    }
    
    /// Check if there's enough memory to load a model
    func canAllocateMemory(size: Int64) -> Bool {
        let memoryInfo = getCurrentMemoryUsage()
        let safetyMargin: Int64 = 1024 * 1024 * 1024 // 1GB safety margin
        
        let canAllocate = memoryInfo.availableMemory > (size + safetyMargin)
        
        logger.info("Memory allocation check: requested \(formatBytes(size)), available \(formatBytes(memoryInfo.availableMemory)), can allocate: \(canAllocate)")
        
        return canAllocate
    }
    
    /// Get recommended memory allocation for a model size
    func getRecommendedAllocation(for modelSize: Int64) -> MemoryAllocationRecommendation {
        let memoryInfo = getCurrentMemoryUsage()
        let mlxOverhead: Double = 1.3 // MLX typically uses 30% overhead
        let requiredMemory = Int64(Double(modelSize) * mlxOverhead)
        
        let recommendation: AllocationStrategy
        let canLoad: Bool
        
        if requiredMemory <= memoryInfo.availableMemory / 2 {
            recommendation = .optimal
            canLoad = true
        } else if requiredMemory <= memoryInfo.availableMemory * 3 / 4 {
            recommendation = .conservative
            canLoad = true
        } else if requiredMemory <= memoryInfo.availableMemory {
            recommendation = .aggressive
            canLoad = true
        } else {
            recommendation = .impossible
            canLoad = false
        }
        
        return MemoryAllocationRecommendation(
            canLoad: canLoad,
            strategy: recommendation,
            requiredMemory: requiredMemory,
            availableMemory: memoryInfo.availableMemory,
            estimatedPerformance: estimatePerformance(for: recommendation, memoryPressure: memoryInfo.memoryPressure)
        )
    }
    
    // MARK: - GPU Memory Management (Apple Silicon)
    
    /// Get GPU memory information (Apple Silicon specific)
    func getGPUMemoryInfo() -> GPUMemoryInfo {
        // On Apple Silicon, GPU and system memory are unified
        let memoryInfo = getCurrentMemoryUsage()
        
        // Estimate GPU memory allocation (typically 75% of system memory is available for GPU)
        let gpuMemoryPool = Int64(Double(memoryInfo.totalMemory) * 0.75)
        let estimatedGPUUsage = Int64(Double(memoryInfo.usedMemory) * 0.3) // Rough estimate
        
        return GPUMemoryInfo(
            totalGPUMemory: gpuMemoryPool,
            usedGPUMemory: estimatedGPUUsage,
            availableGPUMemory: gpuMemoryPool - estimatedGPUUsage,
            isUnifiedMemory: true
        )
    }
    
    // MARK: - Memory Pressure Detection
    
    /// Detect system memory pressure
    func detectMemoryPressure() -> MemoryPressure {
        let memoryInfo = getCurrentMemoryUsage()
        return calculateMemoryPressure(used: memoryInfo.usedMemory, total: memoryInfo.totalMemory)
    }
    
    /// Get memory pressure notifications
    func startMemoryPressureMonitoring(callback: @escaping (MemoryPressure) -> Void) {
        // Set up memory pressure monitoring using dispatch sources
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        source.setEventHandler {
            let pressure = self.detectMemoryPressure()
            callback(pressure)
        }
        
        source.resume()
    }
    
    // MARK: - Private Helper Methods
    
    private func getTotalPhysicalMemory() -> Int64 {
        var size: UInt64 = 0
        var sizeSize = MemoryLayout<UInt64>.size
        
        let result = sysctlbyname("hw.memsize", &size, &sizeSize, nil, 0)
        
        if result == 0 {
            return Int64(size)
        } else {
            logger.error("Failed to get total memory size")
            return 8 * 1024 * 1024 * 1024 // 8GB fallback
        }
    }
    
    private func calculateMemoryPressure(used: Int64, total: Int64) -> MemoryPressure {
        let usagePercentage = Double(used) / Double(total)
        
        switch usagePercentage {
        case 0..<0.7:
            return .normal
        case 0.7..<0.85:
            return .warning
        default:
            return .critical
        }
    }
    
    private func estimatePerformance(for strategy: AllocationStrategy, memoryPressure: MemoryPressure) -> PerformanceEstimate {
        switch (strategy, memoryPressure) {
        case (.optimal, .normal):
            return .excellent
        case (.optimal, .warning), (.conservative, .normal):
            return .good
        case (.conservative, .warning), (.aggressive, .normal):
            return .fair
        case (.aggressive, .warning), (.aggressive, .critical):
            return .poor
        default:
            return .poor
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Data Structures

/// Memory usage information
struct MemoryUsageInfo {
    let totalMemory: Int64
    let usedMemory: Int64
    let availableMemory: Int64
    let memoryPressure: MemoryPressure
    
    var usagePercentage: Double {
        return Double(usedMemory) / Double(totalMemory)
    }
    
    var formattedTotalMemory: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: totalMemory)
    }
    
    var formattedUsedMemory: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: usedMemory)
    }
    
    var formattedAvailableMemory: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: availableMemory)
    }
}

/// GPU memory information (Apple Silicon unified memory)
struct GPUMemoryInfo {
    let totalGPUMemory: Int64
    let usedGPUMemory: Int64
    let availableGPUMemory: Int64
    let isUnifiedMemory: Bool
    
    var gpuUsagePercentage: Double {
        return Double(usedGPUMemory) / Double(totalGPUMemory)
    }
}

/// Memory allocation recommendation
struct MemoryAllocationRecommendation {
    let canLoad: Bool
    let strategy: AllocationStrategy
    let requiredMemory: Int64
    let availableMemory: Int64
    let estimatedPerformance: PerformanceEstimate
    
    var recommendation: String {
        switch strategy {
        case .optimal:
            return "Optimal - Excellent performance expected"
        case .conservative:
            return "Conservative - Good performance expected"
        case .aggressive:
            return "Aggressive - May impact system performance"
        case .impossible:
            return "Impossible - Insufficient memory available"
        }
    }
}

/// Memory allocation strategies
enum AllocationStrategy {
    case optimal      // Use < 50% of available memory
    case conservative // Use < 75% of available memory
    case aggressive   // Use < 100% of available memory
    case impossible   // Requires more than available memory
}

/// Memory pressure levels
enum MemoryPressure {
    case normal   // < 70% memory usage
    case warning  // 70-85% memory usage
    case critical // > 85% memory usage
    
    var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .normal:
            return "green"
        case .warning:
            return "yellow"
        case .critical:
            return "red"
        }
    }
}

/// Performance estimates
enum PerformanceEstimate {
    case excellent
    case good
    case fair
    case poor
    
    var description: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        }
    }
}