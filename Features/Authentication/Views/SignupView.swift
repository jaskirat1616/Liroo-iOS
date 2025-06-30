import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isStudent = false
    @State private var selectedTopics: Set<String> = []
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Streamlined topics - focused on most popular/accessible
    private let availableTopics = [
        "Science", "History", "Technology", "Art", "Literature",
        "Health", "Business", "Education", "Travel", "Music"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(
                        colors: colorScheme == .dark ? 
                            [.cyan.opacity(0.2), Color(.systemBackground), Color(.systemBackground)] :
                            [.cyan.opacity(0.4), .white, .white]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 30)
                        
                        VStack(spacing: 12) {
                            Text("Sign up")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Create your Liroo account")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 16) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Full Name")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                TextField("Enter your full name", text: $name)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                TextField("Enter your email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            // Password Fields
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                SecureField("Create a password", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirm Password")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                SecureField("Re-enter your password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            // Streamlined Topics Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What interests you? (Optional)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                
                                // Flexible flowing layout instead of rigid grid
                                FlowLayout(spacing: 8) {
                                    ForEach(availableTopics, id: \.self) { topic in
                                        TopicChip(
                                            title: topic,
                                            isSelected: selectedTopics.contains(topic),
                                            onTap: {
                                                if selectedTopics.contains(topic) {
                                                    selectedTopics.remove(topic)
                                                } else {
                                                    selectedTopics.insert(topic)
                                                }
                                            }
                                        )
                                    }
                                }
                                
                                if !selectedTopics.isEmpty {
                                    HStack {
                                        Text("\(selectedTopics.count) selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("Clear") {
                                            selectedTopics.removeAll()
                                        }
                                        .font(.caption)
                                        .foregroundColor(.customPrimary)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            
                            // Student Toggle
                            Toggle("I'm a student", isOn: $isStudent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Sign Up Button
                        Button(action: signUp) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? .white : .black)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .cornerRadius(22)
                        .padding(.horizontal)
                        .disabled(authViewModel.isLoading)
                        
                        // Sign In Link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Button("Sign In") {
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.customPrimary)
                        }
                        .padding(.top, 12)
                        
                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.endEditing() })
        }
    }
    
    private func signUp() {
        authViewModel.errorMessage = nil
        errorMessage = ""
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your name"
            showError = true
            return
        }
        
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }
        
        Task {
            do {
                let topicsArray = Array(selectedTopics)

                try await authViewModel.signUp(
                    email: email,
                    password: password,
                    name: name,
                    interestedTopics: topicsArray.isEmpty ? nil : topicsArray,
                    isStudent: isStudent,
                    additionalInfo: nil
                )
                dismiss()
            } catch {
                errorMessage = authViewModel.errorMessage ?? "An error occurred"
                showError = true
            }
        }
    }
}

// MARK: - Streamlined Topic Chip Component
struct TopicChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    // Very light, subtle color palette for selected chips
    private var chipColor: Color {
        let colors: [Color] = [
            Color(red: 0.95, green: 0.85, blue: 0.9), // Very light pink
            Color(red: 0.85, green: 0.9, blue: 0.95), // Very light blue
            Color(red: 0.9, green: 0.95, blue: 0.85), // Very light green
            Color(red: 0.95, green: 0.9, blue: 0.85), // Very light orange
            Color(red: 0.9, green: 0.85, blue: 0.95), // Very light purple
            Color(red: 0.95, green: 0.85, blue: 0.85), // Very light coral
            Color(red: 0.85, green: 0.95, blue: 0.9), // Very light mint
            Color(red: 0.95, green: 0.95, blue: 0.85), // Very light yellow
            Color(red: 0.9, green: 0.9, blue: 0.95), // Very light lavender
            Color(red: 0.95, green: 0.85, blue: 0.95)  // Very light magenta
        ]
        
        // Use the topic name to consistently assign colors
        let hash = abs(title.hashValue)
        return colors[hash % colors.count]
    }
    
    private var textColor: Color {
        if isSelected {
            // Slightly darker text for better contrast on very light backgrounds
            return Color(red: 0.3, green: 0.3, blue: 0.4)
        } else {
            return .primary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 80, minHeight: 32) // Fixed minimum size
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? chipColor : Color(.secondarySystemBackground))
                )
                .foregroundColor(textColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? chipColor.opacity(0.4) : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SignupView()
        .environmentObject(AuthViewModel())
}

// MARK: - FlowLayout Component
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
}

// MARK: - FlowResult Helper
struct FlowResult {
    let positions: [CGPoint]
    let size: CGSize
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var positions: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxWidthUsed: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // Check if this subview would exceed the max width
            if currentPosition.x + subviewSize.width > maxWidth && currentPosition.x > 0 {
                // Move to next line
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(currentPosition)
            
            // Update position for next subview
            currentPosition.x += subviewSize.width + spacing
            lineHeight = max(lineHeight, subviewSize.height)
            maxWidthUsed = max(maxWidthUsed, currentPosition.x - spacing)
        }
        
        self.positions = positions
        self.size = CGSize(
            width: maxWidthUsed,
            height: currentPosition.y + lineHeight
        )
    }
}
