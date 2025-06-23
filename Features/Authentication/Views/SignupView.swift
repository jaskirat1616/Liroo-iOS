import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var interestedTopicsString = ""
    @State private var isStudent = false
    @State private var additionalInfo = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
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
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)
                        
                        VStack(spacing: 16) {
                            Text("Sign up")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Create your Liroo account")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 24)
                        
                        VStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 8) {
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
                            
                            VStack(alignment: .leading, spacing: 8) {
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
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                SecureField("Create a password", text: $password)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                SecureField("Re-enter your password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Topics you're interested in (comma-separated)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                TextField("e.g., history, science, art", text: $interestedTopicsString)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                            
                            Toggle("Are you a student?", isOn: $isStudent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("A little about yourself (Optional)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $additionalInfo)
                                    .frame(height: 80)
                                    .padding(4)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
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
                        
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Button("Sign In") {
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 16)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
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
        }
    }
}

#Preview {
    SignupView()
        .environmentObject(AuthViewModel())
}
