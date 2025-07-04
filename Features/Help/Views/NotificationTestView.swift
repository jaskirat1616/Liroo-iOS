import SwiftUI

struct NotificationTestView: View {
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isTesting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Notification Test Center")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Test and verify that your notifications are working properly")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Test Buttons
                VStack(spacing: 16) {
                    TestButton(
                        title: "🧪 Send Test Notification",
                        subtitle: "Send an immediate test notification",
                        icon: "bell.fill",
                        color: .blue
                    ) {
                        testImmediateNotification()
                    }
                    
                    TestButton(
                        title: "⏰ Send Delayed Test (5s)",
                        subtitle: "Schedule a test notification for 5 seconds from now",
                        icon: "clock.fill",
                        color: .purple
                    ) {
                        testDelayedNotification()
                    }
                    
                    TestButton(
                        title: "📊 Check Notification Status",
                        subtitle: "View current notification settings and scheduled notifications",
                        icon: "gear",
                        color: .green
                    ) {
                        checkNotificationStatus()
                    }
                    
                    TestButton(
                        title: "🔄 Reschedule Daily Notifications",
                        subtitle: "Clear and reschedule all daily notifications",
                        icon: "calendar.badge.plus",
                        color: .orange
                    ) {
                        rescheduleNotifications()
                    }
                    
                    TestButton(
                        title: "🎉 Test Achievement Notification",
                        subtitle: "Simulate an achievement notification",
                        icon: "trophy.fill",
                        color: .yellow
                    ) {
                        testAchievementNotification()
                    }
                    
                    TestButton(
                        title: "🔥 Test Streak Notification",
                        subtitle: "Simulate a streak milestone notification",
                        icon: "flame.fill",
                        color: .red
                    ) {
                        testStreakNotification()
                    }
                    
                    TestButton(
                        title: "📱 Show Device Time",
                        subtitle: "Display current device time and timezone",
                        icon: "clock.badge.fill",
                        color: .indigo
                    ) {
                        showDeviceTimeInfo()
                    }
                    
                    TestButton(
                        title: "📊 Check Live Activity Status",
                        subtitle: "Verify Live Activity permissions and settings",
                        icon: "chart.bar.fill",
                        color: .teal
                    ) {
                        checkLiveActivityStatus()
                    }
                }
                .padding(.horizontal)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Test:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Tap 'Send Test Notification' to send an immediate notification")
                        Text("2. Tap 'Send Delayed Test' to schedule a notification for 5 seconds")
                        Text("3. Check 'Notification Status' to see your current settings")
                        Text("4. Tap 'Show Device Time' to see your device's timezone")
                        Text("5. Try closing the app and waiting for scheduled notifications")
                        Text("6. Make sure notifications are enabled in iOS Settings")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Notification Test")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notification Test", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func testImmediateNotification() {
        isTesting = true
        
        Task {
            await NotificationManager.shared.sendTestNotification()
            
            await MainActor.run {
                alertMessage = "Test notification sent! Check your notification center or lock screen."
                showingAlert = true
                isTesting = false
            }
        }
    }
    
    private func testDelayedNotification() {
        Task {
            await NotificationManager.shared.sendTestNotification()
            
            await MainActor.run {
                alertMessage = "Delayed test notification scheduled for 5 seconds from now. Check your notification center after 5 seconds."
                showingAlert = true
            }
        }
    }
    
    private func checkNotificationStatus() {
        NotificationManager.shared.checkNotificationStatus()
        alertMessage = "Notification status checked! Check the console for detailed information."
        showingAlert = true
    }
    
    private func rescheduleNotifications() {
        Task {
            await NotificationManager.shared.rescheduleNotifications()
            
            await MainActor.run {
                alertMessage = "Daily notifications rescheduled! They will trigger at 8 AM, 12:30 PM, 5:30 PM, and 8 PM daily."
                showingAlert = true
            }
        }
    }
    
    private func testAchievementNotification() {
        let achievement = Achievement(
            id: "test_achievement",
            title: "Test Achievement",
            description: "This is a test achievement notification!",
            icon: "🏆",
            type: .firstContent
        )
        
        Task {
            await NotificationManager.shared.sendAchievementNotification(achievement: achievement)
            
            await MainActor.run {
                alertMessage = "Achievement notification sent! Check your notification center."
                showingAlert = true
            }
        }
    }
    
    private func testStreakNotification() {
        Task {
            await NotificationManager.shared.sendStreakNotification(streak: 7)
            
            await MainActor.run {
                alertMessage = "Streak notification sent! Check your notification center."
                showingAlert = true
            }
        }
    }
    
    private func showDeviceTimeInfo() {
        let timeInfo = NotificationManager.shared.getDeviceTimeInfo()
        alertMessage = timeInfo
        showingAlert = true
    }
    
    private func checkLiveActivityStatus() {
        let status = ContentGenerationLiveActivityManager.shared.checkLiveActivityStatus()
        alertMessage = status
        showingAlert = true
    }
}

struct TestButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationTestView()
    }
} 