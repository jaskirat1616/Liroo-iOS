import Foundation
import OSLog

/// Monitors app performance and identifies bottlenecks
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.liroo.app", category: "Performance")
    private var metrics: [String: PerformanceMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.liroo.performance.metrics", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - Models
    
    struct PerformanceMetric {
        var operation: String
        var startTime: Date
        var endTime: Date?
        var duration: TimeInterval?
        var metadata: [String: Any]
        
        var isComplete: Bool {
            return endTime != nil
        }
        
        mutating func finish() {
            endTime = Date()
            duration = endTime!.timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Measurement
    
    /// Start measuring an operation
    func startMeasurement(operation: String, metadata: [String: Any] = [:]) -> String {
        let id = UUID().uuidString
        let metric = PerformanceMetric(
            operation: operation,
            startTime: Date(),
            endTime: nil,
            duration: nil,
            metadata: metadata
        )
        
        metricsQueue.async(flags: .barrier) {
            self.metrics[id] = metric
        }
        
        logger.debug("Started measurement: \(operation, privacy: .public)")
        
        return id
    }
    
    /// End measuring an operation
    func endMeasurement(_ id: String, metadata: [String: Any] = [:]) -> TimeInterval? {
        return metricsQueue.sync(flags: .barrier) {
            guard var metric = metrics[id] else {
                logger.warning("Measurement \(id) not found")
                return nil
            }
            
            metric.finish()
            
            // Merge additional metadata
            for (key, value) in metadata {
                metric.metadata[key] = value
            }
            
            metrics[id] = metric
            
            let duration = metric.duration ?? 0
            logger.info("Completed \(metric.operation, privacy: .public): \(duration, privacy: .public)s")
            
            // Log to analytics if duration is significant
            if duration > 1.0 {
                AnalyticsManager.shared.logEvent(name: "slow_operation", parameters: [
                    "operation": metric.operation,
                    "duration": duration,
                    "metadata": metric.metadata
                ])
            }
            
            return duration
        }
    }
    
    /// Measure an async operation
    func measure<T>(operation: String, metadata: [String: Any] = [:], block: () async throws -> T) async rethrows -> T {
        let id = startMeasurement(operation: operation, metadata: metadata)
        defer {
            _ = endMeasurement(id)
        }
        
        return try await block()
    }
    
    /// Measure a sync operation
    func measure<T>(operation: String, metadata: [String: Any] = [:], block: () throws -> T) rethrows -> T {
        let id = startMeasurement(operation: operation, metadata: metadata)
        defer {
            _ = endMeasurement(id)
        }
        
        return try block()
    }
    
    // MARK: - Memory Monitoring
    
    /// Get current memory usage
    func getMemoryUsage() -> (used: Int, total: Int) {
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
            let usedMB = Int(info.resident_size / 1024 / 1024)
            // Approximate total based on device
            let totalMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
            return (used: usedMB, total: totalMB)
        }
        
        return (used: 0, total: 0)
    }
    
    /// Monitor memory and log warnings
    func checkMemoryPressure() {
        let (used, total) = getMemoryUsage()
        let usagePercentage = Double(used) / Double(total) * 100.0
        
        if usagePercentage > 80 {
            logger.warning("High memory usage: \(used)MB / \(total)MB (\(Int(usagePercentage))%)")
            
            AnalyticsManager.shared.logEvent(name: "high_memory_usage", parameters: [
                "used_mb": used,
                "total_mb": total,
                "percentage": usagePercentage
            ])
            
            CrashlyticsManager.shared.logMemoryIssue(
                operation: "memory_check",
                memoryUsage: used,
                availableMemory: total - used
            )
        }
    }
    
    // MARK: - Network Performance
    
    /// Track network request performance
    func trackNetworkRequest(endpoint: String, duration: TimeInterval, statusCode: Int) {
        logger.info("Network request: \(endpoint, privacy: .public) - \(duration, privacy: .public)s - \(statusCode)")
        
        // Log slow requests
        if duration > 3.0 {
            AnalyticsManager.shared.logEvent(name: "slow_network_request", parameters: [
                "endpoint": endpoint,
                "duration": duration,
                "status_code": statusCode
            ])
        }
    }
    
    // MARK: - UI Performance
    
    /// Track view rendering time
    func trackViewRender(viewName: String, duration: TimeInterval) {
        logger.debug("View render: \(viewName, privacy: .public) - \(duration, privacy: .public)s")
        
        if duration > 0.1 {
            AnalyticsManager.shared.logEvent(name: "slow_view_render", parameters: [
                "view": viewName,
                "duration": duration
            ])
        }
    }
    
    // MARK: - Metrics Reporting
    
    /// Get performance report
    func getPerformanceReport() -> PerformanceReport {
        return metricsQueue.sync {
            let completedMetrics = metrics.values.filter { $0.isComplete }
            
            let averageDuration = completedMetrics.compactMap { $0.duration }.reduce(0, +) / Double(max(completedMetrics.count, 1))
            
            let slowOperations = completedMetrics.filter { ($0.duration ?? 0) > 2.0 }
            
            return PerformanceReport(
                totalOperations: completedMetrics.count,
                averageDuration: averageDuration,
                slowOperations: slowOperations.map { $0.operation },
                memoryUsage: getMemoryUsage()
            )
        }
    }
    
    struct PerformanceReport {
        let totalOperations: Int
        let averageDuration: TimeInterval
        let slowOperations: [String]
        let memoryUsage: (used: Int, total: Int)
    }
}

