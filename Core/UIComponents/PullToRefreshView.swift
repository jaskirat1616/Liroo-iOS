import SwiftUI

/// Pull-to-refresh modifier for ScrollView
struct PullToRefresh: ViewModifier {
    let action: () async -> Void
    @State private var isRefreshing = false
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                HapticFeedbackManager.shared.refresh()
                await action()
            }
    }
}

extension View {
    func pullToRefresh(action: @escaping () async -> Void) -> some View {
        modifier(PullToRefresh(action: action))
    }
}

/// Custom pull-to-refresh view for iOS 14 compatibility
struct PullToRefreshView<Content: View>: View {
    @Binding var isRefreshing: Bool
    let action: () async -> Void
    let content: Content
    
    init(isRefreshing: Binding<Bool>, action: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self._isRefreshing = isRefreshing
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isRefreshing {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
                content
            }
        }
        .gesture(
            DragGesture()
                .onChanged { _ in
                    // Handle pull gesture
                }
                .onEnded { value in
                    if value.translation.height > 100 && !isRefreshing {
                        isRefreshing = true
                        HapticFeedbackManager.shared.refresh()
                        Task {
                            await action()
                            isRefreshing = false
                        }
                    }
                }
        )
    }
}

