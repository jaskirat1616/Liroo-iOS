import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Reset Password")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 40)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
                .padding(.top, 20)
                
                // Reset Button
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Reset Link")
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
                
                // Back to Sign In
                Button("Back to Sign In") {
                    dismiss()
                }
                .foregroundColor(.accentColor)
                .padding(.top, 20)
            }
            .padding(.bottom, 50)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authViewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Password reset link has been sent to your email")
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else {
            authViewModel.errorMessage = "Please enter your email"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authViewModel.resetPassword(email: email)
                showSuccess = true
            } catch {
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationView {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
