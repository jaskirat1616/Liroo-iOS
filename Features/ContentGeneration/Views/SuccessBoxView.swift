import SwiftUI

struct SuccessBoxView: View {
    let info: ContentGenerationViewModel.SuccessBoxInfo
    
    var body: some View {
        Button(action: info.action) {
            HStack(spacing: 16) {
                Image(systemName: info.iconName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content Ready!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Tap to view your new \(info.contentType) in full reading mode.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(BlurView(style: .systemThickMaterial))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
        .padding(.horizontal)
    }
} 