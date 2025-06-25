import SwiftUI
import PhotosUI // Import PhotosUI for PhotosPicker

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isShowingEditView = false
    // State for showing an edit screen, if you choose to implement it
    // @State private var isShowingEditView = false

    var body: some View {
        Form {
            if let profile = viewModel.profile {
                Section(header: Text("User Information")) {
                    // Avatar Display and Picker
                    HStack {
                        Text("Avatar:")
                        Spacer()
                        if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 60, height: 60)
                                case .success(let image):
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "photo.circle.fill") // Fallback icon on load failure
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    PhotosPicker(
                        selection: $selectedImage,
                        matching: .images, // Only allow images
                        photoLibrary: .shared()
                    ) {
                        Text(viewModel.profile?.avatarURL == nil && selectedImageData == nil ? "Select Profile Picture" : "Change Profile Picture")
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            // Load the data from the selected item
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }

                    // Show upload button only if new image data is present
                    if selectedImageData != nil {
                        Button("Upload New Picture") {
                            if let data = selectedImageData {
                                Task {
                                    await viewModel.updateProfileImage(imageData: data)
                                    // Clear selection after attempting upload
                                    selectedImageData = nil
                                    selectedImage = nil
                                    // Profile should refresh if viewModel.profile is updated
                                    // or call viewModel.loadProfile() if necessary
                                }
                            }
                        }
                        .foregroundColor(.accentColor) // Use app's accent color
                    }
                    
                    HStack {
                        Text("Name:")
                        Spacer()
                        Text(profile.name)
                    }
                    HStack {
                        Text("Email:")
                        Spacer()
                        Text(profile.email)
                    }
                }

                Section(header: Text("About You")) {
                    if let interestedTopics = profile.interestedTopics, !interestedTopics.isEmpty {
                        HStack(alignment: .top) {
                            Text("Interested Topics:")
                            Spacer()
                            Text(interestedTopics.joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text("Interested Topics:")
                            Spacer()
                            Text("Not set")
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        Text("Student Status:")
                        Spacer()
                        if let isStudent = profile.isStudent {
                            Text(isStudent ? "Yes" : "No")
                        } else {
                            Text("Not set")
                                .foregroundColor(.gray)
                        }
                    }

                    if let additionalInfo = profile.additionalInfo, !additionalInfo.isEmpty {
                        HStack(alignment: .top) {
                            Text("Additional Info:")
                            Spacer()
                            Text(additionalInfo)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text("Additional Info:")
                            Spacer()
                            Text("Not set")
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text("Font Preferences")) {
                    if let fontPrefs = profile.fontPreferences {
                        HStack {
                            Text("Font Family:")
                            Spacer()
                            Text(fontPrefs.fontFamily)
                        }
                        HStack {
                            Text("Font Size:")
                            Spacer()
                            Text("\(fontPrefs.fontSize, specifier: "%.1f")")
                        }
                        HStack {
                            Text("Bold:")
                            Spacer()
                            Text(fontPrefs.isBold ? "Yes" : "No")
                        }
                        HStack {
                            Text("Italic:")
                            Spacer()
                            Text(fontPrefs.isItalic ? "Yes" : "No")
                        }
                    } else {
                        Text("No font preferences set.")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Account Details")) {
                    HStack {
                        Text("User ID:")
                        Spacer()
                        Text(profile.userId)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    HStack {
                        Text("Created At:")
                        Spacer()
                        if let createdAt = profile.createdAt {
                            Text(createdAt, style: .date)
                        } else {
                            Text("N/A")
                        }
                    }
                    HStack {
                        Text("Last Updated:")
                        Spacer()
                        if let updatedAt = profile.updatedAt {
                            Text(updatedAt, style: .date)
                        } else {
                            Text("N/A")
                        }
                    }
                }

            } else if let errorMessage = viewModel.errorMessage {
                Section { // Wrap error in a section for better layout in Form
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            } else {
                Section { // Wrap ProgressView for consistency
                    ProgressView("Loading Profile...")
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isShowingEditView = true
                }
            }
        }
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
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
