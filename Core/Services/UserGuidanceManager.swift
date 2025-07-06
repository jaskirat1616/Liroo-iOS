import Foundation
import SwiftUI

@MainActor
class UserGuidanceManager: ObservableObject {
    @Published var showingTooltip = false
    @Published var tooltipMessage = ""
    @Published var tooltipPosition: CGPoint = .zero
    
    private let userDefaults = UserDefaults.standard
    private let guidanceShownKey = "guidanceShown"
    
    // Track which guidance has been shown
    private var shownGuidance: Set<String> {
        get {
            let array = userDefaults.array(forKey: guidanceShownKey) as? [String] ?? []
            return Set(array)
        }
        set {
            userDefaults.set(Array(newValue), forKey: guidanceShownKey)
        }
    }
    
    // MARK: - Tooltips
    func showTooltip(_ message: String, at position: CGPoint) {
        tooltipMessage = message
        tooltipPosition = position
        showingTooltip = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.showingTooltip {
                self.hideTooltip()
            }
        }
    }
    
    func hideTooltip() {
        showingTooltip = false
        tooltipMessage = ""
    }
    
    // MARK: - Feature Guidance
    func shouldShowGuidance(for feature: String) -> Bool {
        !shownGuidance.contains(feature)
    }
    
    func markGuidanceAsShown(for feature: String) {
        shownGuidance.insert(feature)
    }
    
    func resetGuidance() {
        shownGuidance.removeAll()
    }
}

// MARK: - Tooltip View
struct TooltipView: View {
    let message: String
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
            
            // Arrow pointing down
            Triangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 12, height: 6)
        }
        .position(position)
        .transition(.opacity.combined(with: .scale))
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
} 