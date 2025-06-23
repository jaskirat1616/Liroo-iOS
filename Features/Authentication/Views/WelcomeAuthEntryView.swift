import SwiftUI

struct WelcomeAuthEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showLogin = false
    @State private var showSignup = false
    
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
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Welcome to Liroo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Already have an account or new to Liroo?")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 20) {
                        NavigationLink(destination: LoginView(), isActive: $showLogin) {
                            Button(action: { showLogin = true }) {
                                Text("Already have an account?")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(colorScheme == .dark ? .white : .black)
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .cornerRadius(22)
                            }
                        }
                        
                        NavigationLink(destination: SignupView(), isActive: $showSignup) {
                            Button(action: { showSignup = true }) {
                                Text("New to Liroo?")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(22)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WelcomeAuthEntryView()
} 