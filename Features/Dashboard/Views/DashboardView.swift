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
            // Enhanced Stats Section
            enhancedStatsSection
            
            // Recently Read Section
            recentlyReadSection
            
            // Engagement Metrics
            engagementMetricsSection
            
            // Charts Section
            chartsSection
        }
    }
    
    // MARK: - Enhanced Stats Section
    private var enhancedStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Total Time", value: viewModel.totalReadingTimeDisplay, iconName: "timer", iconColor: .blue)
                StatCard(title: "Current Streak", value: viewModel.currentStreakDisplay, iconName: "flame.fill", iconColor: .orange)
                StatCard(title: "Words Read", value: viewModel.totalWordsReadDisplay, iconName: "text.book.closed.fill", iconColor: .green)
                StatCard(title: "Reading Speed", value: viewModel.averageReadingSpeedDisplay, iconName: "speedometer", iconColor: .purple)
                StatCard(title: "Books Read", value: viewModel.totalBooksReadDisplay, iconName: "books.vertical.fill", iconColor: .indigo)
                StatCard(title: "Total Sessions", value: viewModel.totalSessionsDisplay, iconName: "clock.arrow.circlepath", iconColor: .teal)
                StatCard(title: "Avg Session", value: viewModel.averageSessionLengthDisplay, iconName: "clock", iconColor: .pink)
                StatCard(title: "Longest Streak", value: viewModel.longestStreakDisplay, iconName: "trophy.fill", iconColor: .yellow)
            }
        }
    }
    
    // MARK: - Recently Read Section
    private var recentlyReadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Read")
                .font(.title2)
                .fontWeight(.semibold)
            
            if viewModel.recentlyReadItems.isEmpty {
                Text("No recent reading activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentlyReadItems) { item in
                    RecentlyReadRow(item: item)
                }
            }
        }
    }
    
    // MARK: - Engagement Metrics Section
    private var engagementMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Engagement")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let engagement = viewModel.engagementMetrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    EngagementCard(title: "AI Conversations", value: "\(engagement.dialogueInteractions)", iconName: "message.fill", color: .blue)
                    EngagementCard(title: "Content Created", value: "\(engagement.contentGenerated)", iconName: "pencil.and.outline", color: .orange)
                }
                
                // Engagement Score
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall Engagement")
                        .font(.headline)
                    
                    HStack {
                        ProgressView(value: viewModel.totalEngagementScore)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        
                        Text("\(Int(viewModel.totalEngagementScore * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Charts Section
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Reading Activity & Trends")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Time Range Selector for Daily Activity
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                ForEach(ActivityTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Daily Activity Chart (existing)
            Text("Daily Reading Duration")
                .font(.headline)
            if !viewModel.dailyReadingActivity.isEmpty {
                Chart {
                    ForEach(viewModel.dailyReadingActivity) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: .day),
                            y: .value("Duration", dataPoint.duration / 60) // Convert to minutes
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

            // New Analytics Charts
            if let analytics = viewModel.readingAnalytics {
                // Reading Speed Trend
                Divider().padding(.vertical, 8)
                Text("Reading Speed Trend (Last 7 Days)")
                    .font(.headline)
                if !analytics.readingSpeedTrend.isEmpty {
                    Chart {
                        ForEach(analytics.readingSpeedTrend) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("WPM", dataPoint.wordsPerMinute)
                            )
                            .foregroundStyle(Color.green.gradient)
                            PointMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("WPM", dataPoint.wordsPerMinute)
                            )
                            .foregroundStyle(Color.green)
                            .annotation(position: .top) {
                                Text("\(Int(dataPoint.wordsPerMinute))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let wpm = value.as(Double.self) {
                                    Text("\(Int(wpm)) WPM")
                                }
                            }
                        }
                    }
                } else {
                    standardNoDataView("reading speed trend")
                }

                // Time Distribution
                Divider().padding(.vertical, 8)
                Text("Reading Time by Hour of Day")
                    .font(.headline)
                if !analytics.readingTimeDistribution.isEmpty {
                    Chart {
                        ForEach(analytics.readingTimeDistribution) { dataPoint in
                            BarMark(
                                x: .value("Hour", "\(dataPoint.hourOfDay):00"), // Display hour as string
                                y: .value("Time Spent", dataPoint.totalTimeSpent / 60) // Minutes
                            )
                            .foregroundStyle(Color.orange.gradient)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks { value in // Simpler axis for discrete hours
                            AxisGridLine()
                            AxisValueLabel()
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
                    standardNoDataView("reading time distribution")
                }

                // Weekly Progress
                Divider().padding(.vertical, 8)
                Text("Weekly Reading Progress (Last 4 Weeks)")
                    .font(.headline)
                if !analytics.weeklyProgress.isEmpty {
                    Chart {
                        ForEach(analytics.weeklyProgress) { dataPoint in
                            BarMark(
                                x: .value("Week", dataPoint.weekStartDate, unit: .weekOfYear),
                                y: .value("Time Spent", dataPoint.totalTimeSpent / 3600) // Hours
                            )
                            .foregroundStyle(Color.purple.gradient)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let hours = value.as(Double.self) {
                                    Text("\(String(format: "%.1f", hours))h")
                                }
                            }
                        }
                    }
                } else {
                    standardNoDataView("weekly progress")
                }

                // Monthly Progress
                Divider().padding(.vertical, 8)
                Text("Monthly Reading Progress (Last 3 Months)")
                    .font(.headline)
                if !analytics.monthlyProgress.isEmpty {
                    Chart {
                        ForEach(analytics.monthlyProgress) { dataPoint in
                            BarMark(
                                x: .value("Month", dataPoint.month, unit: .month),
                                y: .value("Time Spent", dataPoint.totalTimeSpent / 3600) // Hours
                            )
                            .foregroundStyle(Color.red.gradient)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let hours = value.as(Double.self) {
                                    Text("\(String(format: "%.1f", hours))h")
                                }
                            }
                        }
                    }
                } else {
                    standardNoDataView("monthly progress")
                }
            } else if !viewModel.isLoading { // Only show if not loading and analytics is nil
                 standardNoDataView("detailed analytics trends")
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
