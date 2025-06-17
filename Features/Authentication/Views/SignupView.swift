import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var interestedTopicsString = ""
    @State private var isStudent = false
    @State private var additionalInfo = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 40)
                
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SecureField("", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SecureField("", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Interested Topics Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topics you're interested in (comma-separated)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., history, science, art", text: $interestedTopicsString)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Student Status Toggle
                Toggle("Are you a student?", isOn: $isStudent)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Additional Info TextEditor
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little about yourself (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $additionalInfo)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Sign Up Button
                Button(action: signUp) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading)
                
                // Sign In Link
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign In") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                }
                .padding(.top, 20)
            }
            .padding(.bottom, 50)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signUp() {
        // Validate inputs
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            showError = true
            return
        }
        
        guard !email.isEmpty else {
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
        
        isLoading = true
        
        Task {
            do {
                // Convert interestedTopicsString to array
                let topicsArray = interestedTopicsString.split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }

                try await authViewModel.signUp(
                    email: email,
                    password: password,
                    name: name,
                    interestedTopics: topicsArray.isEmpty ? nil : topicsArray,
                    isStudent: isStudent,
                    additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo
                )
                dismiss()
            } catch {
                errorMessage = authViewModel.errorMessage ?? "An error occurred"
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationView {
        SignupView()
            .environmentObject(AuthViewModel())
    }
}
