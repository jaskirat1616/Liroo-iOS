import SwiftUI

// MARK: - Cache Debug View (Development Only)
#if DEBUG
struct CacheDebugView: View {
    @State private var cacheStats: (count: Int, totalCost: Int) = (0, 0)
    @State private var isLoadingCount: Int = 0
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🖼️ Image Cache Debug")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cached Images: \(cacheStats.count)")
                        .font(.caption)
                    Text("Memory Used: \(cacheStats.totalCost / 1024 / 1024) MB")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Loading: \(isLoadingCount)")
                        .font(.caption)
                        .foregroundColor(isLoadingCount > 0 ? .orange : .green)
                }
            }
            
            HStack {
                Button("Clear Cache") {
                    ImageCache.clearCache()
                    updateStats()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Refresh Stats") {
                    updateStats()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            updateStats()
            // Auto-refresh every 5 seconds
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                updateStats()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func updateStats() {
        cacheStats = ImageCache.shared.getCacheStats()
        isLoadingCount = ImageCache.getLoadingCount()
    }
}
#endif 