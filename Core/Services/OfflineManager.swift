import Foundation
import Network
import Combine

/// Manages offline mode, queue, and sync functionality
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOffline: Bool = false
    @Published var queuedOperations: [QueuedOperation] = []
    @Published var isSyncing: Bool = false
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.liroo.offline.monitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Queue storage
    private let queueStorageKey = "offline_queue"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        startNetworkMonitoring()
        loadQueuedOperations()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                
                // Auto-sync when coming back online
                if wasOffline && !(self?.isOffline ?? true) {
                    await self?.syncQueue()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue Management
    
    struct QueuedOperation: Codable, Identifiable {
        let id: String
        let type: OperationType
        let data: Data
        let timestamp: Date
        var retryCount: Int
        var lastError: String?
        
        enum OperationType: String, Codable {
            case contentGeneration
            case imageGeneration
            case contentUpdate
            case contentDelete
        }
    }
    
    /// Add operation to offline queue
    func queueOperation(type: QueuedOperation.OperationType, data: Data) {
        let operation = QueuedOperation(
            id: UUID().uuidString,
            type: type,
            data: data,
            timestamp: Date(),
            retryCount: 0,
            lastError: nil
        )
        
        queuedOperations.append(operation)
        saveQueuedOperations()
    }
    
    /// Remove completed operation from queue
    func removeOperation(_ operationId: String) {
        queuedOperations.removeAll { $0.id == operationId }
        saveQueuedOperations()
    }
    
    // MARK: - Sync
    
    /// Sync all queued operations when back online
    func syncQueue() async {
        guard !isOffline else {
            print("[OfflineManager] Still offline, cannot sync")
            return
        }
        
        guard !isSyncing else {
            print("[OfflineManager] Already syncing")
            return
        }
        
        guard !queuedOperations.isEmpty else {
            print("[OfflineManager] No operations to sync")
            return
        }
        
        isSyncing = true
        print("[OfflineManager] Starting sync of \(queuedOperations.count) operations")
        
        var operationsToRemove: [String] = []
        
        for operation in queuedOperations {
            do {
                try await processOperation(operation)
                operationsToRemove.append(operation.id)
                print("[OfflineManager] Successfully synced operation: \(operation.id)")
            } catch {
                var updatedOperation = operation
                updatedOperation.retryCount += 1
                updatedOperation.lastError = error.localizedDescription
                
                // Remove if exceeded max retries
                if updatedOperation.retryCount >= 3 {
                    operationsToRemove.append(operation.id)
                    print("[OfflineManager] Operation \(operation.id) exceeded max retries, removing")
                } else {
                    // Update operation in queue
                    if let index = queuedOperations.firstIndex(where: { $0.id == operation.id }) {
                        queuedOperations[index] = updatedOperation
                    }
                }
            }
        }
        
        // Remove successfully synced operations
        for operationId in operationsToRemove {
            removeOperation(operationId)
        }
        
        isSyncing = false
        print("[OfflineManager] Sync completed")
    }
    
    private func processOperation(_ operation: QueuedOperation) async throws {
        // Process operation based on type
        switch operation.type {
        case .contentGeneration:
            // Decode and process content generation
            // This would call the appropriate service
            break
        case .imageGeneration:
            // Process image generation
            break
        case .contentUpdate:
            // Process content update
            break
        case .contentDelete:
            // Process content deletion
            break
        }
    }
    
    // MARK: - Persistence
    
    private func saveQueuedOperations() {
        if let encoded = try? JSONEncoder().encode(queuedOperations) {
            userDefaults.set(encoded, forKey: queueStorageKey)
        }
    }
    
    private func loadQueuedOperations() {
        if let data = userDefaults.data(forKey: queueStorageKey),
           let decoded = try? JSONDecoder().decode([QueuedOperation].self, from: data) {
            queuedOperations = decoded
        }
    }
    
    /// Clear all queued operations
    func clearQueue() {
        queuedOperations.removeAll()
        userDefaults.removeObject(forKey: queueStorageKey)
    }
}

// Extension to make QueuedOperation mutable for updates
extension OfflineManager.QueuedOperation {
    mutating func updateRetry(error: Error) {
        retryCount += 1
        lastError = error.localizedDescription
    }
}

