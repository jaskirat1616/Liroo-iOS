import SwiftUI

struct SettingsView: View {
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
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
