import SwiftUI
import Charts
import CoreData

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // View Type Selector (simplified to only student view)
                    viewTypeSelector
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    } else {
                        // Main Dashboard Content
                        studentDashboardContent
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.refreshData()
            }
            .onAppear {
                viewModel.refreshData()
            }
        }
    }
    
    // MARK: - View Type Selector
    private var viewTypeSelector: some View {
        HStack {
            Text("Student View")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your reading data...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                viewModel.refreshData()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Student Dashboard Content
    private var studentDashboardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Gamified Streaks Section
            streaksSection
            // Achievements Section
            achievementsSection
            // Key Stats Section
            keyStatsSection
            // Recently Read Section (limit 3)
            recentlyReadSection
            // Daily Reading Duration Chart Only
            dailyReadingDurationSection
        }
    }

    // MARK: - Gamified Streaks Section
    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streaks")
                .font(.title2)
                .fontWeight(.bold)
            HStack(spacing: 24) {
                VStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.streakInfo?.currentStreak ?? 0) days")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                VStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.streakInfo?.longestStreak ?? 0) days")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                if let nextMilestone = viewModel.streakInfo?.nextMilestone, let daysLeft = viewModel.streakInfo?.daysUntilNextMilestone {
                    VStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Next Milestone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(nextMilestone) days")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(daysLeft) days left!")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            // Milestone Progress Bar
            if let streakInfo = viewModel.streakInfo, let nextMilestone = streakInfo.nextMilestone {
                let progress = Double(streakInfo.currentStreak) / Double(nextMilestone)
                ProgressView(value: progress) {
                    Text("Progress to next milestone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.title2)
                .fontWeight(.bold)
            if let achievements = viewModel.streakInfo?.achievements {
                ForEach(achievements) { achievement in
                    HStack(spacing: 12) {
                        Image(systemName: achievement.unlocked ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundColor(achievement.unlocked ? .green : .gray)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.name)
                                .font(.headline)
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if achievement.unlocked {
                            Text("Unlocked")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Locked")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            } else {
                Text("No achievements yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Key Stats Section
    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.title2)
                .fontWeight(.semibold)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Total Time", value: viewModel.totalReadingTimeDisplay, iconName: "timer", iconColor: .blue)
                StatCard(title: "Words Read", value: viewModel.totalWordsReadDisplay, iconName: "text.book.closed.fill", iconColor: .green)
                StatCard(title: "Books Read", value: viewModel.totalBooksReadDisplay, iconName: "books.vertical.fill", iconColor: .indigo)
            }
        }
    }
    
    // MARK: - Recently Read Section (limit 3)
    private var recentlyReadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Read")
                .font(.title2)
                .fontWeight(.semibold)
            if viewModel.recentlyReadItems.prefix(3).isEmpty {
                Text("No recent reading activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentlyReadItems.prefix(3)) { item in
                    NavigationLink(
                        destination: FullReadingView(
                            itemID: item.itemID ?? item.title,
                            collectionName: item.collectionName,
                            itemTitle: item.title
                        )
                    ) {
                        RecentlyReadRow(item: item)
                    }
                }
            }
        }
    }
    
    // MARK: - Daily Reading Duration Chart Only
    private var dailyReadingDurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Reading Duration")
                        .font(.headline)
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                ForEach(ActivityTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            if !viewModel.dailyReadingActivity.isEmpty {
                Chart {
                    ForEach(viewModel.dailyReadingActivity) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Duration", dataPoint.duration / 60)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes))m")
                            }
                        }
                    }
                }
            } else {
                standardNoDataView("daily reading activity")
            }
            }
        }
    }

    // Helper for consistent "No Data" messages
    private func standardNoDataView(_ dataDescription: String) -> some View {
        Text("No \(dataDescription) data available.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentlyReadRow: View {
    let item: RecentlyReadItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let author = item.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(item.lastReadDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(item.progress * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                ProgressView(value: item.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .frame(width: 60)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EngagementCard: View {
    let title: String
    let value: String
    let iconName: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
}
