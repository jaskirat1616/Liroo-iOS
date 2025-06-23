
import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            // Replace 'splashImage' with your actual asset name
            Image("Splash")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text("Liroo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                withAnimation {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            WelcomeAuthEntryView()
        }
    }
}

#Preview {
    SplashScreenView()
}
