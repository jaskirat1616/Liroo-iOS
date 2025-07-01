import SwiftUI

struct HelpView: View {
    @StateObject private var viewModel = HelpViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.cyan)
                            
                            Text("Help & Support")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("Find answers to your questions and get the help you need")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Search bar
                        SearchBar(text: $viewModel.searchText)
                            .padding(.horizontal)
                        
                        // Quick actions
                        QuickActionsSection(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        // FAQ Categories
                        FAQCategoriesSection(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        // FAQ List
                        FAQListSection(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        // Support options
                        SupportOptionsSection(viewModel: viewModel)
                            .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showingContactForm) {
                ContactFormView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.incrementHelpViewed()
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search help topics...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @ObservedObject var viewModel: HelpViewModel
    
    private let quickActions = [
        QuickAction(
            title: "Contact Support",
            description: "Get help from our team",
            icon: "envelope.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(quickActions, id: \.title) { action in
                    QuickActionCard(action: action) {
                        handleQuickAction(action)
                    }
                }
            }
        }
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        switch action.title {
        case "Contact Support":
            viewModel.showingContactForm = true
        default:
            break
        }
    }
}

// MARK: - FAQ Categories Section
struct FAQCategoriesSection: View {
    @ObservedObject var viewModel: HelpViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HelpCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - FAQ List Section
struct FAQListSection: View {
    @ObservedObject var viewModel: HelpViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Frequently Asked Questions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.filteredFAQs.count) questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.filteredFAQs.isEmpty {
                EmptyFAQView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredFAQs) { faq in
                        FAQCard(faq: faq)
                    }
                }
            }
        }
    }
}

// MARK: - Support Options Section
struct SupportOptionsSection: View {
    @ObservedObject var viewModel: HelpViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Need More Help?")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                SupportOptionCard(
                    title: "Contact Support",
                    description: "Get personalized help from our team",
                    icon: "envelope.fill",
                    color: .blue
                ) {
                    viewModel.showingContactForm = true
                }
                
                SupportOptionCard(
                    title: "Community Forum",
                    description: "Connect with other Liroo users",
                    icon: "person.3.fill",
                    color: .purple
                ) {
                    // Navigate to community forum
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(action.color)
                
                VStack(spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)
        }
    }
}

struct CategoryChip: View {
    let category: HelpCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? category.color : Color(.tertiarySystemBackground))
            .cornerRadius(20)
        }
    }
}

struct FAQCard: View {
    let faq: FAQItem
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(faq.question)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct EmptyFAQView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No questions found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms or browse different categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct SupportOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
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

// MARK: - Contact Form View
struct ContactFormView: View {
    @ObservedObject var viewModel: HelpViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var subject = ""
    @State private var message = ""
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.cyan)
                        
                        Text("Contact Support")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We're here to help! Send us a message and we'll get back to you as soon as possible.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.headline)
                            
                            TextField("Brief description of your issue", text: $subject)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                            
                            TextField("Your email address", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.headline)
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Message")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isSubmitting || !isFormValid)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your message has been sent. We'll get back to you soon!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitFeedback() {
        guard isFormValid else { return }
        
        isSubmitting = true
        
        Task {
            do {
                try await viewModel.submitFeedback(
                    subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    HelpView()
}
