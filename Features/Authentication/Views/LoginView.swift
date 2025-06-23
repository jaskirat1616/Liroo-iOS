import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var isPasswordVisible = false
    
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
                
                VStack {
                    Spacer(minLength: 60)
                    
                    VStack( spacing: 16) {
                        Text("Sign in")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Sign in to your Liroo account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 24)
                    
                    VStack(spacing: 20) {
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
                            ZStack(alignment: .trailing) {
                                Group {
                                    if isPasswordVisible {
                                        TextField("Enter your password", text: $password)
                                            .textContentType(.password)
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .textContentType(.password)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Text(isPasswordVisible ? "Hide" : "Show")
                                        .font(.footnote)
                                        .foregroundColor(.accentColor)
                                        .padding(.trailing, 12)
                                }
                            }
                        }
                        Button(action: signIn) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? .cyan : .black)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .cornerRadius(22)
                        .shadow(color: Color.accentColor.opacity(0.15), radius: 8, x: 0, y: 4)
                        .disabled(authViewModel.isLoading)
                        
                        HStack {
                            Spacer()
                            NavigationLink(destination: ForgotPasswordView()) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        NavigationLink(destination: SignupView()) {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.top, 24)
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func signIn() {
        authViewModel.errorMessage = nil
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            authViewModel.errorMessage = "Please enter your email"
            showError = true
            return
        }
        guard !password.isEmpty else {
            authViewModel.errorMessage = "Please enter your password"
            showError = true
            return
        }
        Task {
            do {
                try await authViewModel.signIn(email: email, password: password)
            } catch {
                showError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
