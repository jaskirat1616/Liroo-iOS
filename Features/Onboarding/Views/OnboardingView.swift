import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(
                        colors: colorScheme == .dark ? 
                            [.cyan.opacity(0.2), Color(.systemBackground)] :
                            [.cyan.opacity(0.4), .white]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressView(value: Double(viewModel.currentStep.rawValue), total: Double(OnboardingViewModel.OnboardingStep.allCases.count - 1))
                        .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Content area
                    TabView(selection: $viewModel.currentStep) {
                        WelcomeStepView(viewModel: viewModel)
                            .tag(OnboardingViewModel.OnboardingStep.welcome)
                        
                        FeaturesStepView(viewModel: viewModel)
                            .tag(OnboardingViewModel.OnboardingStep.features)
                        
                        PreferencesStepView(viewModel: viewModel)
                            .tag(OnboardingViewModel.OnboardingStep.preferences)
                        
                        AccessibilityStepView(viewModel: viewModel)
                            .tag(OnboardingViewModel.OnboardingStep.accessibility)
                        
                        CompleteStepView(viewModel: viewModel)
                            .tag(OnboardingViewModel.OnboardingStep.complete)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                    
                    // Navigation buttons
                    HStack {
                        if viewModel.currentStep != .welcome {
                            Button("Back") {
                                viewModel.previousStep()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.currentStep == .welcome {
                            Button("Skip") {
                                viewModel.skipOnboarding()
                                dismiss()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Button(viewModel.currentStep == .complete ? "Get Started" : "Next") {
                            if viewModel.currentStep == .complete {
                                viewModel.completeOnboarding()
                                dismiss()
                            } else {
                                viewModel.nextStep()
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .cornerRadius(22)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
                
                VStack(spacing: 16) {
                    Text(viewModel.currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.currentStep.description)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(icon: "doc.text.fill", title: "Read Any Document", description: "Import PDFs, images, and text files")
                FeatureRow(icon: "brain.head.profile", title: "AI-Powered Summaries", description: "Get intelligent summaries and insights")
                FeatureRow(icon: "accessibility", title: "Accessibility First", description: "Designed for all readers")
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Features Step
struct FeaturesStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Text(viewModel.currentStep.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(viewModel.currentStep.description)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                FeatureCard(
                    icon: "camera.fill",
                    title: "OCR Technology",
                    description: "Extract text from images and scanned documents",
                    color: .blue
                )
                
                FeatureCard(
                    icon: "wand.and.stars",
                    title: "AI Generation",
                    description: "Create summaries, questions, and explanations",
                    color: .purple
                )
                
                FeatureCard(
                    icon: "person.2.fill",
                    title: "Interactive Learning",
                    description: "Ask questions and get detailed answers",
                    color: .green
                )
                
                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Tracking",
                    description: "Monitor your reading progress and comprehension",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Preferences Step
struct PreferencesStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private let availableTopics = [
        "Science", "History", "Technology", "Art", "Literature",
        "Health", "Business", "Education", "Travel", "Music",
        "Philosophy", "Mathematics", "Psychology", "Economics", "Politics"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Text(viewModel.currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.currentStep.description)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Student status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Are you a student?")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Button(action: { viewModel.isStudent = true }) {
                                HStack {
                                    Image(systemName: viewModel.isStudent ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(viewModel.isStudent ? .cyan : .secondary)
                                    Text("Yes")
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(viewModel.isStudent ? Color.cyan.opacity(0.1) : Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            
                            Button(action: { viewModel.isStudent = false }) {
                                HStack {
                                    Image(systemName: !viewModel.isStudent ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(!viewModel.isStudent ? .cyan : .secondary)
                                    Text("No")
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(!viewModel.isStudent ? Color.cyan.opacity(0.1) : Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Topic selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What topics interest you?")
                            .font(.headline)
                        
                        Text("Select topics to personalize your experience")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(availableTopics, id: \.self) { topic in
                                TopicChip(
                                    title: topic,
                                    isSelected: viewModel.selectedTopics.contains(topic),
                                    onTap: {
                                        if viewModel.selectedTopics.contains(topic) {
                                            viewModel.selectedTopics.remove(topic)
                                        } else {
                                            viewModel.selectedTopics.insert(topic)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Accessibility Step
struct AccessibilityStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Text(viewModel.currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.currentStep.description)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 24) {
                    // Font size
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Font Size")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.accessibilityPreferences.fontSize))pt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.accessibilityPreferences.fontSize, in: 12...24, step: 1)
                            .accentColor(.cyan)
                    }
                    
                    // Font family
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Font Family")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            FontOption(
                                name: "OpenDyslexic-Regular",
                                displayName: "OpenDyslexic",
                                isSelected: viewModel.accessibilityPreferences.fontFamily == "OpenDyslexic-Regular",
                                action: { viewModel.accessibilityPreferences.fontFamily = "OpenDyslexic-Regular" }
                            )
                            
                            FontOption(
                                name: "SF Pro",
                                displayName: "System",
                                isSelected: viewModel.accessibilityPreferences.fontFamily == "SF Pro",
                                action: { viewModel.accessibilityPreferences.fontFamily = "SF Pro" }
                            )
                        }
                    }
                    
                    // Line spacing
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Line Spacing")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1f", viewModel.accessibilityPreferences.lineSpacing))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.accessibilityPreferences.lineSpacing, in: 1.0...2.0, step: 0.1)
                            .accentColor(.cyan)
                    }
                    
                    // Accessibility options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Accessibility Options")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            Toggle("High Contrast", isOn: $viewModel.accessibilityPreferences.highContrast)
                                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                            
                            Toggle("Reduce Motion", isOn: $viewModel.accessibilityPreferences.reduceMotion)
                                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                            
                            Toggle("Screen Reader Support", isOn: $viewModel.accessibilityPreferences.screenReader)
                                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Complete Step
struct CompleteStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text(viewModel.currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.currentStep.description)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 16) {
                Text("Your preferences have been saved:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    if !viewModel.selectedTopics.isEmpty {
                        Text("• \(viewModel.selectedTopics.count) topics selected")
                    }
                    Text("• Font: \(viewModel.accessibilityPreferences.fontFamily)")
                    Text("• Font size: \(Int(viewModel.accessibilityPreferences.fontSize))pt")
                    if viewModel.isStudent {
                        Text("• Student mode enabled")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.cyan)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FontOption: View {
    let name: String
    let displayName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("Aa")
                    .font(.custom(name, size: 24))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.cyan : Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

#Preview {
    OnboardingView()
}
