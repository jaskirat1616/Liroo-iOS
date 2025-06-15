# Liroo

Liroo is an iOS application designed to help users with reading and learning through various interactive features.

## Project Structure

The project follows a feature-based architecture with clear separation of concerns:

### Application
Contains app entry points and configuration files.

### Features
Each feature is organized into its own module with Views and ViewModels:
- Authentication
- Onboarding
- Dashboard
- Profile
- Reading
- History
- Flashcards
- Dialogue
- Slideshow
- Settings
- Help

### Core
Shared components and utilities:
- Navigation
- Models
- Data (Networking, Caching, Firebase)
- Services
- Utilities
- UIComponents
- Extensions

### Resources
Contains all static resources:
- Assets
- Fonts
- Media
- Localization files

## Getting Started

1. Clone the repository
2. Install dependencies
3. Open `Liroo.xcodeproj`
4. Build and run the project

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Dependencies

- Firebase
- SwiftUI
- Combine

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 