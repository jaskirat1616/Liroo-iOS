import SwiftUI
import CommonCrypto

// MARK: - Cached Async Image Component with Progressive Loading
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let quality: ImageQuality?
    let enableProgressiveLoading: Bool
    
    @State private var image: UIImage?
    @State private var lowResImage: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var loadProgress: Double = 0.0
    
    init(url: URL?, 
         quality: ImageQuality? = nil,
         enableProgressiveLoading: Bool = true,
         @ViewBuilder content: @escaping (Image) -> Content, 
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.quality = quality
        self.enableProgressiveLoading = enableProgressiveLoading
        self.content = content
        self.placeholder = placeholder
    }
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.quality = nil
        self.enableProgressiveLoading = true
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else if hasError {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { newUrl in
            // Only reset and reload if URL actually changed
            if let currentUrl = url?.absoluteString, let newUrlString = newUrl?.absoluteString, currentUrl != newUrlString {
                print("[CachedAsyncImage] URL changed from \(currentUrl) to \(newUrlString)")
                image = nil
                isLoading = false
                hasError = false
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { 
            print("[CachedAsyncImage] ❌ No URL provided")
            return 
        }
        
        let urlString = url.absoluteString
        
        // Check if already loading this URL
        if ImageCache.shared.isLoading(urlString) {
            print("[CachedAsyncImage] 🔄 Already loading image for URL: \(urlString)")
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: urlString) {
            print("[CachedAsyncImage] ✅ Image found in cache for URL: \(urlString)")
            self.image = cachedImage
            self.isLoading = false
            self.hasError = false
            return
        }
        
        print("[CachedAsyncImage] 📥 Starting download for URL: \(urlString)")
        isLoading = true
        hasError = false
        
        // Mark as loading to prevent duplicate requests
        ImageCache.shared.markAsLoading(urlString)
        
        // Load from network
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                // Remove loading state
                ImageCache.shared.removeLoading(urlString)
                self.isLoading = false
                
                if let error = error {
                    print("[CachedAsyncImage] ❌ Error loading image from \(urlString): \(error.localizedDescription)")
                    self.hasError = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[CachedAsyncImage] 📡 HTTP Response: \(httpResponse.statusCode) for URL: \(urlString)")
                    
                    if httpResponse.statusCode != 200 {
                        print("[CachedAsyncImage] ❌ HTTP Error: \(httpResponse.statusCode) for URL: \(urlString)")
                        self.hasError = true
                        return
                    }
                }
                
                if let data = data, let downloadedImage = UIImage(data: data) {
                    print("[CachedAsyncImage] ✅ Successfully downloaded image (\(data.count) bytes) from URL: \(urlString)")
                    // Cache the image
                    ImageCache.shared.set(downloadedImage, forKey: urlString)
                    self.image = downloadedImage
                    self.hasError = false
                } else {
                    print("[CachedAsyncImage] ❌ Failed to create UIImage from data for URL: \(urlString)")
                    self.hasError = true
                }
            }
        }.resume()
    }
}

// MARK: - Enhanced Image Cache
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let loadingURLs = NSMutableSet()
    private let queue = DispatchQueue(label: "com.liroo.imagecache", attributes: .concurrent)
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let cacheExpiryDays: Int = 30
    
    private init() {
        cache.countLimit = 100 // Maximum number of images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
        // Disk cache directory
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("LirooImageCache", isDirectory: true)
        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
        }
        // Add memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        // Optionally clear old files on init
        clearOldFiles()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.setObject(image, forKey: key as NSString)
            print("[ImageCache] 💾 Cached image for key: \(key)")
            // Save to disk
            if let data = image.pngData() {
                let fileURL = self.diskCacheURL.appendingPathComponent(self.hashedFileName(for: key))
                try? data.write(to: fileURL)
                print("[ImageCache] 💾 Saved image to disk: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    func get(forKey key: String) -> UIImage? {
        // First check memory
        if let image = queue.sync(execute: { cache.object(forKey: key as NSString) }) {
            print("[ImageCache] 🎯 Cache hit for key: \(key)")
            return image
        }
        // Then check disk
        let fileURL = diskCacheURL.appendingPathComponent(hashedFileName(for: key))
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            print("[ImageCache] 💾 Disk cache hit for key: \(key)")
            // Put it back in memory cache
            queue.async(flags: .barrier) {
                self.cache.setObject(image, forKey: key as NSString)
            }
            return image
        }
        print("[ImageCache] ❌ Cache miss for key: \(key)")
        return nil
    }
    
    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: key as NSString)
            print("[ImageCache] 🗑️ Removed image for key: \(key)")
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.loadingURLs.removeAllObjects()
            print("[ImageCache] 🗑️ Cleared all cached images")
        }
    }
    
    // MARK: - Loading State Management
    
    func markAsLoading(_ urlString: String) {
        queue.async(flags: .barrier) {
            self.loadingURLs.add(urlString)
            print("[ImageCache] 🔄 Marked as loading: \(urlString)")
        }
    }
    
    func removeLoading(_ urlString: String) {
        queue.async(flags: .barrier) {
            self.loadingURLs.remove(urlString)
            print("[ImageCache] ✅ Removed loading state: \(urlString)")
        }
    }
    
    func isLoading(_ urlString: String) -> Bool {
        return queue.sync {
            let loading = self.loadingURLs.contains(urlString)
            if loading {
                print("[ImageCache] 🔄 URL is already loading: \(urlString)")
            }
            return loading
        }
    }
    
    func getLoadingCount() -> Int {
        return queue.sync {
            return self.loadingURLs.count
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> (count: Int, totalCost: Int) {
        return queue.sync {
            return (cache.totalCostLimit, cache.totalCostLimit)
        }
    }
    
    func printCacheStats() {
        let stats = getCacheStats()
        print("[ImageCache] 📊 Cache Stats - Count: \(stats.count), Total Cost: \(stats.totalCost)")
        print("[ImageCache] 📊 Currently Loading: \(loadingURLs.count) URLs")
    }
    
    @objc private func clearCache() {
        print("[ImageCache] ⚠️ Memory warning received, clearing cache")
        removeAll()
    }
    
    // MARK: - Disk Cache Helpers
    private func hashedFileName(for key: String) -> String {
        // Use SHA256 for unique, safe filenames
        if let data = key.data(using: .utf8) {
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString
    }
    private func clearOldFiles() {
        let expiry = Date().addingTimeInterval(-Double(cacheExpiryDays) * 24 * 60 * 60)
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { return }
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = attrs.contentModificationDate, modDate < expiry {
                try? fileManager.removeItem(at: file)
                print("[ImageCache] 🗑️ Removed expired cached image: \(file.lastPathComponent)")
            }
        }
    }
}

// MARK: - Debug Utilities
extension ImageCache {
    /// Debug method to print current cache status
    static func debugCacheStatus() {
        shared.printCacheStats()
    }
    
    /// Debug method to clear cache manually
    static func clearCache() {
        shared.removeAll()
    }
    
    /// Debug method to check if a specific URL is cached
    static func isCached(_ urlString: String) -> Bool {
        return shared.get(forKey: urlString) != nil
    }
    
    /// Debug method to check if a specific URL is currently loading
    static func isLoading(_ urlString: String) -> Bool {
        return shared.isLoading(urlString)
    }
    
    /// Debug method to get the number of currently loading URLs
    static func getLoadingCount() -> Int {
        return shared.getLoadingCount()
    }
} 