import SwiftUI
import PhotosUI // Import PhotosUI for PhotosPicker

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isShowingEditView = false
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isIPadLandscape: Bool {
        isIPad && UIDevice.current.orientation.isLandscape
    }
    
    // State for showing an edit screen, if you choose to implement it
    // @State private var isShowingEditView = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: isIPad ? 32 : 24) {
                    // Top Card: Avatar, Name, Email
                    topProfileCard
                    // Edit Profile Button
                    HStack(spacing: isIPad ? 16 : 12) {
                        Button(action: { isShowingEditView = true }) {
                            HStack(spacing: isIPad ? 10 : 8) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(.purple)
                                Text("Edit Profile")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, isIPad ? 12 : 8)
                            .padding(.horizontal, isIPad ? 14 : 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Help Button
                        NavigationLink(destination: HelpView()) {
                            HStack(spacing: isIPad ? 10 : 8) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(.cyan)
                                Text("Help")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.vertical, isIPad ? 12 : 8)
                            .padding(.horizontal, isIPad ? 14 : 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.cyan.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Settings Button
                        NavigationLink(destination: SettingsView()) {
                            HStack(spacing: isIPad ? 10 : 8) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                                    .foregroundColor(.purple)
                                Text("Settings")
                                    .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, isIPad ? 12 : 8)
                            .padding(.horizontal, isIPad ? 14 : 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, isIPad ? 24 : 16)
                    // About Card
                    if let profile = viewModel.profile {
                        aboutCard(profile: profile)
                        if let fontPrefs = profile.fontPreferences {
                            fontPreferencesCard(fontPrefs: fontPrefs)
                        }
                        accountDetailsCard(profile: profile)
                    } else if let errorMessage = viewModel.errorMessage {
                        errorCard(message: errorMessage)
                    } else {
                        loadingCard
                    }
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                .padding(.top, isIPad ? 32 : 24)
                
                Spacer(minLength: isIPad ? 80 : 100)
            }
        }
        .background(
                   LinearGradient(
                       gradient: Gradient(
                           colors: colorScheme == .dark ?
                           [.cyan.opacity(0.15), .cyan.opacity(0.15), Color(.systemBackground), Color(.systemBackground)] :
                           [.cyan.opacity(0.2), .cyan.opacity(0.1),  .white, .white]
                       ),
                       startPoint: .top,
                       endPoint: .bottom
                   )
                   .ignoresSafeArea()
               )
        .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.endEditing() })
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingEditView) {
            EditProfileView(viewModel: viewModel)
        }
        .onAppear {
            // Clear any lingering selections if the view reappears
            selectedImage = nil
            selectedImageData = nil
            viewModel.loadProfile()
        }
        // Show an alert for errors from the ViewModel
        .alert("Profile Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil // Clear the error
            }
        }, message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        })
    }
    
    // MARK: - Top Card
    private var topProfileCard: some View {
        Group {
            if let profile = viewModel.profile {
                VStack(spacing: isIPad ? 16 : 12) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarView(urlString: profile.avatarURL)
                        PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "camera.fill")
                                .padding(isIPad ? 10 : 8)
                                .clipShape(Circle())
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: isIPad ? 10 : 8, y: isIPad ? 10 : 8)
                        .onChange(of: selectedImage) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }
                    if selectedImageData != nil {
                        Button("Upload New Picture") {
                            if let data = selectedImageData {
                                Task {
                                    await viewModel.updateProfileImage(imageData: data)
                                    selectedImageData = nil
                                    selectedImage = nil
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isIPad ? 16 : 14)
                        .padding(.horizontal, isIPad ? 24 : 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.purple)
                        .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                    }
                    Text(profile.name)
                        .font(isIPad ? .title : .title2).fontWeight(.bold)
                    Text(profile.email)
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(isIPad ? 24 : 16)
                .frame(maxWidth: .infinity)
               
            }
        }
    }
    
    private func avatarView(urlString: String?) -> some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: isIPad ? 120 : 90, height: isIPad ? 120 : 90)
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: isIPad ? 120 : 90, height: isIPad ? 120 : 90)
                            .clipShape(Circle())
                            
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().frame(width: isIPad ? 120 : 90, height: isIPad ? 120 : 90)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().frame(width: isIPad ? 120 : 90, height: isIPad ? 120 : 90)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - About Card
    private func aboutCard(profile: ProfileViewModel.UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About You").font(.headline)
            Divider()
            if let topics = profile.interestedTopics, !topics.isEmpty {
                HStack {
                    Text("Topics:").fontWeight(.semibold)
                    Spacer()
                    Text(topics.joined(separator: ", ")).multilineTextAlignment(.trailing)
                }
            } else {
                HStack {
                    Text("Topics:").fontWeight(.semibold)
                    Spacer()
                    Text("Not set").foregroundColor(.gray)
                }
            }
            HStack {
                Text("Student:").fontWeight(.semibold)
                Spacer()
                Text(profile.isStudent == true ? "Yes" : "No")
            }
            if let info = profile.additionalInfo, !info.isEmpty {
                HStack(alignment: .top) {
                    Text("Info:").fontWeight(.semibold)
                    Spacer()
                    Text(info).multilineTextAlignment(.trailing)
                }
            } else {
                HStack {
                    Text("Info:").fontWeight(.semibold)
                    Spacer()
                    Text("Not set").foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
    }
    
    // MARK: - Font Preferences Card
    private func fontPreferencesCard(fontPrefs: ProfileViewModel.UserProfile.FontPreferences) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Font Preferences").font(.headline)
            Divider()
            HStack {
                Text("Font:").fontWeight(.semibold)
                Spacer()
                Text(fontPrefs.fontFamily)
            }
            HStack {
                Text("Size:").fontWeight(.semibold)
                Spacer()
                Text("\(fontPrefs.fontSize, specifier: "%.1f")")
            }
            HStack {
                Text("Bold:").fontWeight(.semibold)
                Spacer()
                Text(fontPrefs.isBold ? "Yes" : "No")
            }
            HStack {
                Text("Italic:").fontWeight(.semibold)
                Spacer()
                Text(fontPrefs.isItalic ? "Yes" : "No")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
    }
    
    // MARK: - Account Details Card
    private func accountDetailsCard(profile: ProfileViewModel.UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account Details").font(.headline)
            Divider()
            HStack {
                Text("User ID:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(profile.userId)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let createdAt = profile.createdAt { 
                HStack {
                    Text("Created:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(12)
    }
    
    // MARK: - Error Card
    private func errorCard(message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(message).foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(16)
    }
    
    // MARK: - Loading Card
    private var loadingCard: some View {
        VStack {
            ProgressView()
            Text("Loading Profile...")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(16)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
