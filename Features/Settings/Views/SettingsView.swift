import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    
    // Access the AppStorage variables
    @AppStorage("readingThemeName") private var selectedThemeName: String = ReadingTheme.light.rawValue
    @AppStorage("readingFontSize") private var selectedFontSize: Double = 17.0 // Default font size
    @AppStorage("readingFontStyleName") private var selectedFontStyleName: String = ReadingFontStyle.systemDefault.rawValue // Added

    // For the font size slider
    private let minFontSize: Double = 12.0
    private let maxFontSize: Double = 30.0

    // Computed property for easy access to current font style for preview
    private var currentFontStyle: ReadingFontStyle {
        ReadingFontStyle(rawValue: selectedFontStyleName) ?? .systemDefault
    }
    private var currentTheme: ReadingTheme {
        ReadingTheme(rawValue: selectedThemeName) ?? .light
    }

    var body: some View {
        NavigationView {
            Form {
                // User Account Section
                Section(header: Text("Account")) {
                    if let user = authViewModel.user {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email ?? "No email")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(user.uid.prefix(8) + "...")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button("Sign Out") {
                        showSignOutAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("Reading Preferences")) {
                    // Theme Picker
                    Picker("Theme", selection: $selectedThemeName) {
                        ForEach(ReadingTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }

                    // Font Style Picker
                    Picker("Font Style", selection: $selectedFontStyleName) { // Added
                        ForEach(ReadingFontStyle.allCases) { style in
                            Text(style.rawValue)
                                .font(style.getFont(size: 16)) // Preview font in picker
                                .tag(style.rawValue)
                        }
                    }

                    // Font Size Slider
                    VStack(alignment: .leading) {
                        Text("Font Size: \(Int(selectedFontSize))")
                        Slider(value: $selectedFontSize, in: minFontSize...maxFontSize, step: 1) {
                            Text("Font Size")
                        } minimumValueLabel: {
                            Text("\(Int(minFontSize))").font(.caption)
                        } maximumValueLabel: {
                            Text("\(Int(maxFontSize))").font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Current Preview")) {
                     VStack(alignment: .leading, spacing: 10) {
                         Text("Sample Title Text")
                             .font(currentFontStyle.getFont(size: CGFloat(selectedFontSize + 6), weight: .bold)) // Use selected font style
                         Text("This is some sample body text so you can preview the font size and theme. Adjust the settings above to see how your reading experience will change.")
                             .font(currentFontStyle.getFont(size: CGFloat(selectedFontSize))) // Use selected font style
                             .lineSpacing(CGFloat(selectedFontSize * 0.3))
                         Text("A smaller caption or secondary info.")
                             .font(currentFontStyle.getFont(size: CGFloat(selectedFontSize - 2))) // Use selected font style
                             .opacity(0.7)
                     }
                     .padding()
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(currentTheme.backgroundColor) // Use selected theme
                     .foregroundColor(currentTheme.primaryTextColor) // Use selected theme
                     .cornerRadius(8)
                }
                
                // Danger Zone Section
                Section(header: Text("Danger Zone")) {
                    Button("Delete Account") {
                        showDeleteAccountAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    do {
                        try authViewModel.signOut()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await authViewModel.deleteAccount()
                        } catch {
                            print("Error deleting account: \(error.localizedDescription)")
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data.")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
