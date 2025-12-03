import SwiftUI

/// Accessibility helper extensions and modifiers
extension View {
    /// Adds comprehensive accessibility support
    func accessibilitySupport(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        isHeader: Bool = false
    ) -> some View {
        var finalTraits = traits
        if isHeader {
            finalTraits.insert(.isHeader)
        }
        
        return self
            .modifier(AccessibilitySupportModifier(
                label: label,
                hint: hint,
                value: value,
                traits: finalTraits
            ))
    }
}

private struct AccessibilitySupportModifier: ViewModifier {
    let label: String?
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Makes view accessible with dynamic type support
    func accessibleDynamicType() -> some View {
        self
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
    
    /// Adds accessibility support for buttons
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to activate")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds accessibility support for images
    func accessibleImage(label: String, description: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(description ?? "Image")
            .accessibilityAddTraits(.isImage)
    }
}

/// Accessibility-aware view modifier
struct AccessibilityAwareModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .default, value: UUID())
            .symbolEffect(.bounce, value: reduceMotion ? nil : UUID())
    }
}

extension View {
    func accessibilityAware() -> some View {
        modifier(AccessibilityAwareModifier())
    }
}

/// VoiceOver announcement helper
class AccessibilityAnnouncer {
    static func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    static func announceScreen(_ screenName: String) {
        UIAccessibility.post(notification: .screenChanged, argument: screenName)
    }
    
    static func announceLayout(_ layout: String) {
        UIAccessibility.post(notification: .layoutChanged, argument: layout)
    }
}

