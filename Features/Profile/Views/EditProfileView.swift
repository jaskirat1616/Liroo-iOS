import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel // Assuming you pass this in

    // State variables to hold edits
    @State private var name: String = ""
    @State private var interestedTopicsString: String = "" // Comma-separated
    @State private var isStudent: Bool = false
    @State private var additionalInfo: String = ""

    // Font Preferences (if editable)
    @State private var fontSize: Double = 16.0
    @State private var fontFamily: String = "System"
    @State private var isFontBold: Bool = false
    @State private var isFontItalic: Bool = false
    
    // For handling topics array
    private var interestedTopicsArray: [String] {
        interestedTopicsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    @State private var selectedAvatarItem: PhotosPickerItem? = nil
    @State private var selectedAvatarData: Data? = nil
    @State private var showSuccessBanner: Bool = false
    @State private var isUploadingAvatar: Bool = false

    var body: some View {
        ZStack {
            // Subtle gradient background, matching Welcome/Login screens
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.cyan.opacity(0.12),
                    Color(.systemBackground),
                    Color(.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 40) {
                    // Centered Avatar Section
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarView(urlString: viewModel.profile?.avatarURL, imageData: selectedAvatarData)
                                .frame(width: 110, height: 110)
                                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                            PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                                Image(systemName: "camera.fill")
                                    .padding(10)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .offset(x: 10, y: 10)
                            .onChange(of: selectedAvatarItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        selectedAvatarData = data
                                    }
                                }
                            }
                        }
                        if selectedAvatarData != nil {
                            Button(action: {
                                if let data = selectedAvatarData {
                                    isUploadingAvatar = true
                                    Task {
                                        await viewModel.updateProfileImage(imageData: data)
                                        selectedAvatarData = nil
                                        selectedAvatarItem = nil
                                        isUploadingAvatar = false
                                        showSuccessBanner = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccessBanner = false }
                                    }
                                }
                            }) {
                                if isUploadingAvatar {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Upload New Picture")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.08)))
                            .foregroundColor(.purple)
                            .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    // Personal Info Section
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Personal Information")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Name", text: $name)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .submitLabel(.done)
                            Text("Interested Topics (comma-separated)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Interested Topics (comma-separated)", text: $interestedTopicsString)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .autocapitalization(.none)
                                .submitLabel(.done)
                            Toggle("Are you a student?", isOn: $isStudent)
                                .font(.system(size: 16))
                                .padding(.top, 8)
                            Text("Additional Info (Optional):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $additionalInfo)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                    // Divider above buttons
                    Divider()
                        .padding(.vertical, 8)
                    // Save/Cancel Buttons
                    HStack {
                        Button("Cancel") { dismiss() }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button(action: {
                            saveProfile()
                            showSuccessBanner = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccessBanner = false }
                        }) {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .navigationTitle("Edit Profile")
            }
        }
        .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.endEditing() })
        .onAppear {
            // Load existing data when the view appears
            if let profile = viewModel.profile {
                name = profile.name
                interestedTopicsString = profile.interestedTopics?.joined(separator: ", ") ?? ""
                isStudent = profile.isStudent ?? false
                additionalInfo = profile.additionalInfo ?? ""
                if let fontPrefs = profile.fontPreferences {
                    fontSize = fontPrefs.fontSize
                    fontFamily = fontPrefs.fontFamily
                    isFontBold = fontPrefs.isBold
                    isFontItalic = fontPrefs.isItalic
                }
            }
        }
        .overlay(
            Group {
                if showSuccessBanner {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Profile updated!")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 4))
                        Spacer()
                    }
                    .padding(.top, 40)
                }
            }, alignment: .top
        )
    }

    private func saveProfile() {
        let updatedFontPrefs = ProfileViewModel.UserProfile.FontPreferences(
            fontSize: fontSize,
            fontFamily: fontFamily,
            isBold: isFontBold,
            isItalic: isFontItalic
        )
        
        Task {
            do {
                try await viewModel.updateProfile(
                    name: name,
                    // avatarURL is not handled here, only other fields
                    fontPreferences: updatedFontPrefs,
                    interestedTopics: interestedTopicsArray.isEmpty ? nil : interestedTopicsArray, // Store nil if empty after trimming
                    isStudent: isStudent,
                    additionalInfo: additionalInfo.isEmpty ? nil : additionalInfo // Store nil if empty
                )
                print("Profile updated successfully.")
            } catch {
                print("Error updating profile: \(error)")
                // Optionally, show an alert to the user
            }
        }
    }

    private func avatarView(urlString: String?, imageData: Data?) -> some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: 100, height: 100)
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().foregroundColor(.gray)
            }
        }
    }
}

// Preview (optional, for development)
// struct EditProfileView_Previews: PreviewProvider {
// static var previews: some View {
// // You'd need a mock ProfileViewModel or a way to instantiate one
// EditProfileView(viewModel: ProfileViewModel())
//     .environmentObject(ProfileViewModel()) // if viewModel is EnvironmentObject
// }
// }

