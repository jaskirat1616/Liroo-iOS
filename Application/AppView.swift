import SwiftUI

struct AppView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // Main app content
                NavigationView {
                    VStack {
                        Text("Welcome to Liroo!")
                            .font(.title)
                            .padding()
                        
                        // Logout Button
                        Button(action: {
                            do {
                                try authViewModel.signOut()
                            } catch {
                                print("Error signing out: \(error.localizedDescription)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .padding()
                    }
                    .navigationTitle("Liroo")
                }
            } else {
                LoginView()
            }
        }
        .environmentObject(authViewModel)
    }
}

#Preview {
    AppView()
} 