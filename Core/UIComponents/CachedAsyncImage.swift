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
        .onChange(of: url) { _ in
            // Reset state when URL changes
            image = nil
            isLoading = false
            hasError = false
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        print("[CachedAsyncImage] Loading image from URL: \(url.absoluteString)")
        isLoading = true
        hasError = false
        
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            print("[CachedAsyncImage] ✅ Image found in cache for URL: \(url.absoluteString)")
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        print("[CachedAsyncImage] 📥 Downloading image from URL: \(url.absoluteString)")
        
        // Load from network
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("[CachedAsyncImage] ❌ Error loading image from \(url.absoluteString): \(error.localizedDescription)")
                    self.hasError = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[CachedAsyncImage] 📡 HTTP Response: \(httpResponse.statusCode) for URL: \(url.absoluteString)")
                    
                    if httpResponse.statusCode != 200 {
                        print("[CachedAsyncImage] ❌ HTTP Error: \(httpResponse.statusCode) for URL: \(url.absoluteString)")
                        self.hasError = true
                        return
                    }
                }
                
                if let data = data, let downloadedImage = UIImage(data: data) {
                    print("[CachedAsyncImage] ✅ Successfully downloaded image (\(data.count) bytes) from URL: \(url.absoluteString)")
                    // Cache the image
                    ImageCache.shared.set(downloadedImage, forKey: url.absoluteString)
                    self.image = downloadedImage
                } else {
                    print("[CachedAsyncImage] ❌ Failed to create UIImage from data for URL: \(url.absoluteString)")
                    self.hasError = true
                }
            }
        }.resume()
    }
}

// MARK: - Image Cache
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Maximum number of images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
} 