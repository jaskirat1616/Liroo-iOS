import SwiftUI

/// Shimmer effect for skeleton loading
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .blur(radius: 10)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

/// Skeleton view for content cards
struct ContentCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 20)
                .frame(maxWidth: 200)
            
            // Content skeleton lines
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: 150)
            }
            
            // Image skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 150)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shimmer()
    }
}

/// Skeleton view for list items
struct ListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: 150)
            }
            
            Spacer()
        }
        .padding()
        .shimmer()
    }
}

/// Skeleton view for story chapter
struct StoryChapterSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chapter header
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 24)
                Spacer()
            }
            
            // Title
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 24)
                .frame(maxWidth: 250)
            
            // Image
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            
            // Content lines
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<5) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .frame(maxWidth: 150)
            }
        }
        .padding()
        .shimmer()
    }
}

/// Generic skeleton container
struct SkeletonView<Content: View>: View {
    let content: Content
    let count: Int
    
    init(count: Int = 3, @ViewBuilder content: () -> Content) {
        self.count = count
        self.content = content()
    }
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            content
        }
    }
}

