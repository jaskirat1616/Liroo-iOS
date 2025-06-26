import SwiftUI

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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Personal Info Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Information").font(.headline)
                    Divider()
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Interested Topics (comma-separated)", text: $interestedTopicsString)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    Toggle("Are you a student?", isOn: $isStudent)
                    VStack(alignment: .leading) {
                        Text("Additional Info (Optional):")
                        TextEditor(text: $additionalInfo)
                            .frame(height: 80)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                // Font Preferences Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Preferences").font(.headline)
                    Divider()
                    Stepper("Font Size: \(fontSize, specifier: "%.1f")", value: $fontSize, in: 10...30, step: 0.5)
                    TextField("Font Family", text: $fontFamily)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Bold Text", isOn: $isFontBold)
                    Toggle("Italic Text", isOn: $isFontItalic)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                // Save/Cancel Buttons
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save Changes") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.customPrimary)
                }
            }
            .padding()
            .navigationTitle("Edit Profile")
        }
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
}

// Preview (optional, for development)
// struct EditProfileView_Previews: PreviewProvider {
// static var previews: some View {
// // You'd need a mock ProfileViewModel or a way to instantiate one
// EditProfileView(viewModel: ProfileViewModel())
//     .environmentObject(ProfileViewModel()) // if viewModel is EnvironmentObject
// }
// }

