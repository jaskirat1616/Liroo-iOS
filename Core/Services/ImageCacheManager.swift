import Foundation
import UIKit
import SwiftUI
import Network

/// Image quality levels for network-aware caching
enum ImageQuality {
    case low
    case medium
    case high
}

/// Enhanced Image Cache Manager with LRU cache, preloading, and network-aware quality selection
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let accessOrder = NSMutableOrderedSet() // For LRU tracking
    private let cacheQueue = DispatchQueue(label: "com.liroo.imagecache.manager", attributes: .concurrent)
    private let maxCacheSize: Int = 150 // Maximum number of images in cache
    private let maxMemorySize: Int = 150 * 1024 * 1024 // 150 MB
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.liroo.network.monitor")
    private var isConnected: Bool = true
    private var isExpensive: Bool = false
    
    // Preloading queue
    private var preloadQueue: [String] = []
    private var isPreloading = false
    
    private init() {
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = maxMemorySize
        
        // Start network monitoring
        startNetworkMonitoring()
        
        // Listen to memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.isExpensive = path.isExpensive
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Cache Operations
    
    func getImage(for url: String) -> UIImage? {
        return cacheQueue.sync {
            if let image = cache.object(forKey: url as NSString) {
                // Update access order for LRU
                accessOrder.remove(url)
                accessOrder.add(url)
                return image
            }
            return nil
        }
    }
    
    func setImage(_ image: UIImage, for url: String) {
        cacheQueue.async(flags: .barrier) {
            // Remove oldest if cache is full
            if self.accessOrder.count >= self.maxCacheSize {
                if let oldestUrl = self.accessOrder.firstObject as? String {
                    self.cache.removeObject(forKey: oldestUrl as NSString)
                    self.accessOrder.removeObject(at: 0)
                }
            }
            
            self.cache.setObject(image, forKey: url as NSString)
            self.accessOrder.remove(url) // Remove if exists
            self.accessOrder.add(url) // Add to end (most recently used)
        }
    }
    
    func removeImage(for url: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeObject(forKey: url as NSString)
            self.accessOrder.remove(url)
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.accessOrder.removeAllObjects()
        }
    }
    
    // MARK: - Network-Aware Quality Selection
    
    func recommendedQuality() -> ImageQuality {
        if !isConnected {
            return .low
        }
        if isExpensive {
            return .medium
        }
        return .high
    }
    
    // MARK: - Preloading
    
    func preloadImages(urls: [String]) {
        guard !isPreloading else { return }
        
        preloadQueue = urls
        isPreloading = true
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.processPreloadQueue()
        }
    }
    
    private func processPreloadQueue() {
        while !preloadQueue.isEmpty {
            let urlString = preloadQueue.removeFirst()
            
            // Skip if already cached
            if getImage(for: urlString) != nil {
                continue
            }
            
            // Skip if network is expensive or not connected
            if isExpensive && recommendedQuality() == .low {
                continue
            }
            
            guard let url = URL(string: urlString) else { continue }
            
            // Download image
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                setImage(image, for: urlString)
            }
        }
        
        isPreloading = false
    }
    
    // MARK: - Memory Management
    
    @objc private func handleMemoryWarning() {
        // Clear 30% of cache when memory warning is received
        let itemsToRemove = maxCacheSize / 3
        cacheQueue.async(flags: .barrier) {
            for _ in 0..<min(itemsToRemove, self.accessOrder.count) {
                if let oldestUrl = self.accessOrder.firstObject as? String {
                    self.cache.removeObject(forKey: oldestUrl as NSString)
                    self.accessOrder.removeObject(at: 0)
                }
            }
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> (count: Int, size: Int) {
        return cacheQueue.sync {
            return (cache.countLimit, cache.totalCostLimit)
        }
    }
}

