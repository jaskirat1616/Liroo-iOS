import SwiftUI

// MARK: - Cached Async Image Component
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
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
    
    private init() {
        cache.countLimit = 100 // Maximum number of images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
        
        // Add memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.setObject(image, forKey: key as NSString)
            print("[ImageCache] 💾 Cached image for key: \(key)")
        }
    }
    
    func get(forKey key: String) -> UIImage? {
        return queue.sync {
            let image = cache.object(forKey: key as NSString)
            if image != nil {
                print("[ImageCache] 🎯 Cache hit for key: \(key)")
            } else {
                print("[ImageCache] ❌ Cache miss for key: \(key)")
            }
            return image
        }
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