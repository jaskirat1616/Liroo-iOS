import SwiftUI

struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private let howToSteps = [
        HowToStep(
            title: "Import Your Documents",
            description: "Tap the + button to import PDFs, images, or text files. You can also take photos of documents using the camera.",
            icon: "plus.circle.fill",
            color: .blue
        ),
        HowToStep(
            title: "Read and Navigate",
            description: "Swipe to navigate through pages. Use pinch gestures to zoom in and out. Tap and hold text to select it.",
            icon: "hand.draw.fill",
            color: .green
        ),
        HowToStep(
            title: "Get AI Insights",
            description: "Tap the AI button to get summaries, ask questions, or generate practice questions about your content.",
            icon: "brain.head.profile",
            color: .purple
        ),
        HowToStep(
            title: "Customize Your Experience",
            description: "Go to Settings to adjust font size, family, line spacing, and other accessibility options.",
            icon: "slider.horizontal.3",
            color: .orange
        ),
        HowToStep(
            title: "Track Your Progress",
            description: "View your reading history and progress in the History tab. See what you've read and when.",
            icon: "chart.line.uptrend.xyaxis",
            color: .red
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.cyan)
                            
                            Text("How to Use Liroo")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("Follow these simple steps to get the most out of your reading experience")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Steps
                        VStack(spacing: 20) {
                            ForEach(Array(howToSteps.enumerated()), id: \.offset) { index, step in
                                HowToStepCard(step: step, stepNumber: index + 1)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Quick tips
                        VStack(spacing: 16) {
                            Text("Quick Tips")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 12) {
                                QuickTipRow(text: "Use the search bar to find specific content")
                                QuickTipRow(text: "Bookmark important pages for later reference")
                                QuickTipRow(text: "Share insights with friends and colleagues")
                                QuickTipRow(text: "Enable notifications for reading reminders")
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Support section
                        VStack(spacing: 16) {
                            Text("Need More Help?")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 12) {
                                SupportOption(
                                    title: "FAQ",
                                    description: "Find answers to common questions",
                                    icon: "questionmark.circle.fill",
                                    action: {
                                        // Navigate to FAQ
                                    }
                                )
                                
                                SupportOption(
                                    title: "Contact Support",
                                    description: "Get help from our team",
                                    icon: "envelope.fill",
                                    action: {
                                        // Open contact form
                                    }
                                )
                                
                                SupportOption(
                                    title: "Video Tutorials",
                                    description: "Watch step-by-step guides",
                                    icon: "play.circle.fill",
                                    action: {
                                        // Open video tutorials
                                    }
                                )
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HowToStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct HowToStepCard: View {
    let step: HowToStep
    let stepNumber: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(step.color)
                    .frame(width: 40, height: 40)
                
                Text("\(stepNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: step.icon)
                        .font(.title2)
                        .foregroundColor(step.color)
                    
                    Text(step.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(16)
    }
}

struct QuickTipRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct SupportOption: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

#Preview {
    HowToUseView()
}
