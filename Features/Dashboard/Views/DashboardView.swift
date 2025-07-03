import SwiftUI
import Charts
import CoreData

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var globalManager = GlobalBackgroundProcessingManager.shared
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var profileViewModel = ProfileViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showGlobalProcessingIndicator: Bool = true
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isIPadLandscape: Bool {
        isIPad && UIDevice.current.orientation.isLandscape
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: isIPad ? 20 : 12) {
                    dashboardHeader
                    weeklyReadingProgressSection
                    dashboardGridSection
                    streaksSection
                    recentReadingsSection
                    Spacer(minLength: isIPad ? 80 : 120)
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                .padding(.top, isIPad ? 16 : 8)
            }
            .refreshable {
                viewModel.refreshData()
            }
            .onAppear {
                viewModel.refreshData()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(
                        colors: colorScheme == .dark ?
                        [.cyan.opacity(0.15), .cyan.opacity(0.15), Color(.systemBackground), Color(.systemBackground)] :
                        [.cyan.opacity(0.2), .cyan.opacity(0.1),  .white, .white]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            
            // Global Background Processing Indicator
            if globalManager.isBackgroundProcessing && globalManager.isIndicatorVisible {
                VStack {
                    Spacer()
                    globalBackgroundProcessingIndicator(dismissAction: {
                        globalManager.dismissIndicator()
                    })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            globalManager.restoreFromUserDefaults()
        }
    }
    
    // MARK: - Dashboard Header
    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: isIPad ? 16 : 12) {
            if let urlString = profileViewModel.profile?.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.customPrimary, lineWidth: 2))
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.customPrimary, lineWidth: 2))
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.customPrimary, lineWidth: 2))
                    .foregroundColor(.gray)
            }
            Text("Hello, \(profileViewModel.profile?.name ?? "Jessica")")
                .font(isIPad ? .title2 : .headline)
                .foregroundColor(.primary)
            Spacer()
            NavigationLink(destination: HelpView()) {
                Image(systemName: "questionmark.circle")
                    .font(isIPad ? .title : .title2)
                    .foregroundColor(.cyan)
                    .padding(isIPad ? 12 : 8)
            }
            .accessibilityLabel("Help")
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(isIPad ? .title : .title2)
                    .foregroundColor(.purple)
                    .padding(isIPad ? 12 : 8)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.bottom, isIPad ? 8 : 4)
    }
    
    // MARK: - Weekly Reading Progress Section
    private var weeklyReadingProgressSection: some View {
        let dailyGoal: TimeInterval = 20 * 60 // 20 minutes in seconds
        let weekStart = startOfCurrentWeek()
        let calendar = Calendar.current
        return VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            Text("Progress")
                .font(.system(size: isIPad ? 32 : 26, weight: .regular, design: .default))
                .padding(.bottom, isIPad ? 4 : 2)
            HStack(spacing: isIPad ? 16 : 12) {
                ForEach(0..<7) { offset in
                    let dayDate = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                    let totalDuration = viewModel.dailyReadingActivity
                        .filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
                        .reduce(0) { $0 + $1.duration }
                    let progress = min(totalDuration / dailyGoal, 1.0)
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: isIPad ? 8 : 6)
                            .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 40)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progress >= 1.0 ? Color.purple : Color.customPrimary, style: StrokeStyle(lineWidth: isIPad ? 8 : 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: isIPad ? 48 : 40, height: isIPad ? 48 : 40)
                        Text("\(Int(totalDuration/60))")
                            .font(isIPad ? .subheadline : .caption)
                            .fontWeight(.bold)
                            .foregroundColor(progress >= 1.0 ? .purple : .customPrimary)
                    }
                }
            }
        }
        .padding(.bottom, isIPad ? 12 : 8)
    }
    
    // Helper: Start of current week (Sunday)
    private func startOfCurrentWeek() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return calendar.date(from: components) ?? today
    }
    
    // MARK: - Dashboard Grid Section (Modern Minimalistic with Line Charts)
    private var dashboardGridSection: some View {
        let columns = adaptiveGridColumns()
        return LazyVGrid(columns: columns, spacing: isIPad ? 16 : 8) {
            // Current Streak with Trend Chart
            MetricCardWithChart(
                title: "Current Streak",
                value: "\(viewModel.overallStats?.currentStreakInDays ?? 0)",
                subtitle: "days",
                icon: "flame.fill",
                iconColor: .orange,
                chartData: generateStreakTrendData(),
                chartType: .line,
                gradient: LinearGradient(
                    colors: [.orange.opacity(0.8), .orange.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Active Days with Activity Chart
            MetricCardWithChart(
                title: "Active Days",
                value: "\(activeDaysThisMonth())",
                subtitle: "this month",
                icon: "calendar",
                iconColor: .customPrimary,
                chartData: generateActivityTrendData(),
                chartType: .line,
                gradient: LinearGradient(
                    colors: [.customPrimary.opacity(0.8), .customPrimary.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Reading Speed with Speed Chart
            MetricCardWithChart(
                title: "Reading Speed",
                value: "\(Int(viewModel.overallStats?.averageReadingSpeed ?? 0))",
                subtitle: "WPM",
                icon: "speedometer",
                iconColor: .purple,
                chartData: generateSpeedTrendData(),
                chartType: .line,
                gradient: LinearGradient(
                    colors: [.purple.opacity(0.8), .purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Total Content with Progress Chart
            MetricCardWithChart(
                title: "Total Content",
                value: viewModel.totalContentDisplay,
                subtitle: "completed",
                icon: "books.vertical.fill",
                iconColor: .indigo,
                chartData: generateContentProgressData(),
                chartType: .line,
                gradient: LinearGradient(
                    colors: [.indigo.opacity(0.8), .indigo.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .padding(.horizontal, isIPad ? 4 : 2)
        .padding(.vertical, isIPad ? 8 : 4)
    }
    
    // MARK: - Adaptive Grid Columns
    private func adaptiveGridColumns() -> [GridItem] {
        if isIPad {
            if isIPadLandscape {
                return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
            } else {
                return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
            }
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        }
    }
    
    // MARK: - Chart Data Generators
    
    private func generateStreakTrendData() -> [ChartDataPoint] {
        // Generate streak trend data for the last 7 days
        let calendar = Calendar.current
        let today = Date()
        var dataPoints: [ChartDataPoint] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let hasActivity = viewModel.dailyReadingActivity.contains { 
                calendar.isDate($0.date, inSameDayAs: date) && $0.duration > 0 
            }
            
            // Simulate streak building up or breaking
            let streakValue = hasActivity ? Double(i + 1) : 0.0
            dataPoints.append(ChartDataPoint(date: date, value: streakValue))
        }
        
        return dataPoints.reversed()
    }
    
    private func generateActivityTrendData() -> [ChartDataPoint] {
        // Use actual daily reading activity data
        return viewModel.dailyReadingActivity.map { activity in
            ChartDataPoint(date: activity.date, value: activity.duration / 3600) // Convert to hours
        }.suffix(7).map { $0 } // Last 7 days
    }
    
    private func generateSpeedTrendData() -> [ChartDataPoint] {
        // Generate reading speed trend data
        let calendar = Calendar.current
        let today = Date()
        var dataPoints: [ChartDataPoint] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let dayActivity = viewModel.dailyReadingActivity.filter { 
                calendar.isDate($0.date, inSameDayAs: date) 
            }
            
            let averageSpeed = dayActivity.isEmpty ? 0.0 : 
                dayActivity.reduce(0.0) { $0 + Double($1.wordsRead) / ($1.duration / 60) } / Double(dayActivity.count)
            
            dataPoints.append(ChartDataPoint(date: date, value: averageSpeed))
        }
        
        return dataPoints.reversed()
    }
    
    private func generateContentProgressData() -> [ChartDataPoint] {
        // Generate content completion progress over time
        let calendar = Calendar.current
        let today = Date()
        var dataPoints: [ChartDataPoint] = []
        var cumulativeContent = 0.0
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let dayActivity = viewModel.dailyReadingActivity.filter { 
                calendar.isDate($0.date, inSameDayAs: date) 
            }
            
            // Add some content completion for days with activity
            if !dayActivity.isEmpty {
                cumulativeContent += Double(dayActivity.count) * 0.5 // Simulate content completion
            }
            
            dataPoints.append(ChartDataPoint(date: date, value: cumulativeContent))
        }
        
        return dataPoints.reversed()
    }
    
    // MARK: - Challenges Section (Modern Minimalistic)
    private var streaksSection: some View {
        VStack(alignment: .leading) {
            Text("Challenges")
                .font(isIPad ? .title : .title2)
                .fontWeight(.semibold)
                .padding(.top, isIPad ? 12 : 8)
            if let stats = viewModel.challengeStats {
                VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                    ForEach(sortedChallenges(stats.challenges)) { challenge in
                        ChallengeRow(challenge: challenge)
                    }
                    if stats.challenges.isEmpty {
                        Text("No challenges available")
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(.secondary)
                            .padding(isIPad ? 16 : 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
                .background(Color.clear)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                    .frame(height: isIPad ? 140 : 120)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
        }
        .padding(.bottom, isIPad ? 8 : 4)
    }
    
    // Helper: Sort challenges by status
    private func sortedChallenges(_ challenges: [Challenge]) -> [Challenge] {
        challenges.sorted {
            if $0.isCompleted != $1.isCompleted {
                return $0.isCompleted && !$1.isCompleted
            } else if $0.isLocked != $1.isLocked {
                return !$0.isLocked && $1.isLocked
            } else {
                return $0.displayName < $1.displayName
            }
        }
    }
    
    // MARK: - Recent Readings Section
    private var recentReadingsSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            Text("Recent readings")
                .font(isIPad ? .title : .title2)
                .fontWeight(.regular)
                .padding(.top, isIPad ? 12 : 8)
            if viewModel.recentlyReadItems.isEmpty {
                Text("No recent reading activity")
                    .font(isIPad ? .body : .subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(isIPad ? 24 : 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isIPad ? 16 : 12) {
                        ForEach(viewModel.recentlyReadItems.prefix(isIPad ? 6 : 5)) { item in
                            if item.type == .lecture {
                                NavigationLink(
                                    destination: LectureDestinationView(
                                        lectureID: item.itemID ?? "",
                                        lectureTitle: item.title
                                    )
                                ) {
                                    RecentlyReadRow(item: item)
                                        .frame(width: adaptiveCardWidth())
                                }
                            } else {
                                NavigationLink(
                                    destination: FullReadingView(
                                        itemID: item.itemID ?? item.title,
                                        collectionName: item.collectionName,
                                        itemTitle: item.title
                                    )
                                ) {
                                    RecentlyReadRow(item: item)
                                        .frame(width: adaptiveCardWidth())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isIPad ? 4 : 0)
                }
            }
            
            Spacer()
        }
        .padding(.bottom, isIPad ? 16 : 12)
    }
    
    // MARK: - Adaptive Card Width
    private func adaptiveCardWidth() -> CGFloat {
        if isIPad {
            return isIPadLandscape ? 220 : 200
        } else {
            return 180
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
                    if item.type == .lecture {
                        NavigationLink(
                            destination: LectureDestinationView(
                                lectureID: item.itemID ?? "",
                                lectureTitle: item.title
                            )
                        ) {
                            RecentlyReadRow(item: item)
                        }
                    } else {
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
            // Unified Challenges Section
            challengesSection
            // Key Stats Section
            keyStatsSection
            // Recently Read Section (limit 3)
            recentlyReadSection
            // Daily Reading Duration Chart Only
            dailyReadingDurationSection
        }
    }

    // MARK: - Unified Challenges Section
    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Challenges")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if let challengeStats = viewModel.challengeStats {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("\(challengeStats.completedChallenges)/\(challengeStats.totalChallenges)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            
                            // Level Badge
                            HStack(spacing: 4) {
                                let levelIconName = levelIcon(for: challengeStats.level)
                                let levelColorValue = levelColor(for: challengeStats.level)
                                
                                Image(systemName: levelIconName)
                                    .font(.caption)
                                    .foregroundColor(levelColorValue)
                                Text(challengeStats.level.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(levelColorValue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(levelColor(for: challengeStats.level).opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Points Progress
                        if challengeStats.canLevelUp {
                            Text("🎉 Ready to Level Up!")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        } else {
                            let pointsText = "\(challengeStats.totalPoints)/\(challengeStats.pointsNeededForNextLevel) points"
                            Text(pointsText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Current Streak Overview
            if let challengeStats = viewModel.challengeStats {
                HStack(spacing: 20) {
                    // Current Streak
                    VStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(challengeStats.currentStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Longest Streak
                    VStack {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)
                        Text("Longest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(challengeStats.longestStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Completion Rate
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(.customPrimary)
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let completionPercentage = Int(challengeStats.completionRate * 100)
                        Text("\(completionPercentage)%")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("complete")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                // Level Up Progress Bar
                if !challengeStats.canLevelUp {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Level Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            let progressText = "\(challengeStats.totalPoints)/\(challengeStats.pointsNeededForNextLevel)"
                            Text(progressText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let progressValue = Double(challengeStats.totalPoints) / Double(challengeStats.pointsNeededForNextLevel)
                        let progressColor = levelColor(for: challengeStats.level)
                        ProgressView(value: progressValue)
                            .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                            .frame(height: 6)
                    }
                    .padding(.vertical, 4)
                }
                
                // Active Challenges
                let activeChallenges = challengeStats.challenges.filter { $0.isInProgress }
                if !activeChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Challenges")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(activeChallenges) { challenge in
                            ChallengeRow(challenge: challenge)
                        }
                    }
                }
                
                // Recent Completions with Celebration
                if !challengeStats.recentCompletions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Achievements")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        
                        ForEach(challengeStats.recentCompletions) { challenge in
                            CompletedChallengeRow(challenge: challenge)
                        }
                    }
                }
                
                // Upcoming Challenges
                if !challengeStats.upcomingChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming Challenges")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(challengeStats.upcomingChallenges) { challenge in
                            ChallengeRow(challenge: challenge)
                        }
                    }
                }
                
                // Progressive Challenges (can be leveled up)
                let progressiveChallenges = challengeStats.challenges.filter { $0.canProgress }
                if !progressiveChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Level Up Opportunities")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(progressiveChallenges) { challenge in
                            ProgressiveChallengeRow(challenge: challenge)
                        }
                    }
                }
            } else {
                // Loading or no data state
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Loading challenges...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
    
    // MARK: - Enhanced Challenge Row Component (Modern Minimalistic)
    private func ChallengeRow(challenge: Challenge) -> some View {
        HStack() {
            
            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(challenge.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                if challenge.isInProgress {
                    ProgressView(value: challenge.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(challenge.iconColor)))
                        .frame(height: 4)
                    Text("\(challenge.currentProgress)/\(challenge.targetProgress)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if challenge.frequency != .oneTime {
                    Text(challenge.frequency.rawValue)
                        .font(.caption2)
                        .foregroundColor(.customPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.customPrimary.opacity(0.08))
                        .cornerRadius(4)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title3)
                } else if challenge.isInProgress {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(Color(challenge.iconColor))
                        .font(.title3)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                if let reward = challenge.reward {
                    Text(reward)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if challenge.points > 0 {
                    Text("+\(challenge.points)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Completed Challenge Row (Celebration Style)
    private func CompletedChallengeRow(challenge: Challenge) -> some View {
        HStack(spacing: 12) {
            // Celebration Icon
            ZStack {
                Image(systemName: challenge.iconName)
                    .font(.title2)
                    .foregroundColor(Color(challenge.iconColor))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .offset(x: 12, y: -12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                let timeInterval = challenge.completedDate?.timeIntervalSinceNow ?? 0
                let daysAgo = Int(abs(timeInterval / 86400)) // Convert to days
                let completionText = "Completed \(daysAgo) days ago"
                Text(completionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if challenge.completionCount > 1 {
                    let completionCountText = "Completed \(challenge.completionCount) times"
                    Text(completionCountText)
                        .font(.caption2)
                        .foregroundColor(.customPrimary)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
                
                Text("+\(challenge.points)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                if let reward = challenge.reward {
                    Text(reward)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Progressive Challenge Row (Can Level Up)
    private func ProgressiveChallengeRow(challenge: Challenge) -> some View {
        HStack(spacing: 12) {
            // Level Up Icon
            ZStack {
                Image(systemName: challenge.iconName)
                    .font(.title2)
                    .foregroundColor(Color(challenge.iconColor))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .offset(x: 12, y: -12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let displayName = challenge.nextLevelName ?? challenge.displayName
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                let nextLevel = ChallengeLevel(rawValue: challenge.level.rawValue + 1)
                let nextLevelName = nextLevel?.name ?? ""
                let levelUpText = "Level up to \(challenge.level.name) → \(nextLevelName)"
                Text(levelUpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let nextTarget = challenge.nextLevelTarget {
                    let targetText = "Next target: \(nextTarget)"
                    Text(targetText)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Level Up")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions for Level Colors and Icons
    private func levelColor(for level: ChallengeLevel) -> Color {
        switch level {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .platinum: return .customPrimary
        case .diamond: return .purple
        }
    }
    
    private func levelIcon(for level: ChallengeLevel) -> String {
        switch level {
        case .bronze: return "circle.fill"
        case .silver: return "circle.fill"
        case .gold: return "star.fill"
        case .platinum: return "crown.fill"
        case .diamond: return "diamond.fill"
        }
    }

    // MARK: - Key Stats Section
    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.title2)
                .fontWeight(.semibold)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                StatCard(title: "Total Time", value: viewModel.totalReadingTimeDisplay, iconName: "timer", iconColor: .customPrimary)
                StatCard(title: "Words Read", value: viewModel.totalWordsReadDisplay, iconName: "text.book.closed.fill", iconColor: .purple)
                StatCard(title: "Books Read", value: viewModel.totalBooksReadDisplay, iconName: "books.vertical.fill", iconColor: .indigo)
                StatCard(title: "Active Days This Month", value: "\(activeDaysThisMonth())", iconName: "calendar", iconColor: .orange)
            }
            .padding(.horizontal, 2)
        }
    }
    
    // Helper: Count active reading days in the current month
    private func activeDaysThisMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let days = Set(viewModel.dailyReadingActivity.filter { $0.date >= startOfMonth && $0.duration > 0 }.map { calendar.startOfDay(for: $0.date) })
        return days.count
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
                        .foregroundStyle(Color.customPrimary.gradient)
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

    // Helper for consistent "No Data" messages
    private func standardNoDataView(_ dataDescription: String) -> some View {
        Text("No \(dataDescription) data available.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    // MARK: - Global Background Processing Indicator
    private func globalBackgroundProcessingIndicator(dismissAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Generating \(globalManager.generationType)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(Int(globalManager.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 8)
                }
                .accessibilityLabel("Dismiss background processing indicator")
            }
            // Progress Bar
            ProgressView(value: globalManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(height: 3)
            if !globalManager.currentStep.isEmpty {
                Text(globalManager.currentStep)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: globalManager.isBackgroundProcessing)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(height: 75) // Slightly increased height for better proportions
        .padding(8) // Increased padding for better readability
        .background(Color(.systemGray6))
        .cornerRadius(10) // Slightly increased corner radius
    }
}

struct RecentlyReadRow: View {
    let item: RecentlyReadItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            // Chip for type
            Text(item.type.rawValue)
                .font(.caption2)
                .foregroundColor(.customPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.customPrimary.opacity(0.08))
                .cornerRadius(4)
            if let author = item.author {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                if item.type == .lecture {
                    Text("Complete")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    ProgressView(value: item.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .frame(width: 50, height: 2)
                }
                Spacer()
                Text(item.lastReadDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(width: 180, height: 90, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct EngagementCard: View {
    let title: String
    let value: String
    let iconName: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(height: 75) // Slightly increased height for better proportions
        .padding(8) // Increased padding for better readability
        .background(Color(.systemGray6))
        .cornerRadius(10) // Slightly increased corner radius
    }
}

// MARK: - Chart Data Structures
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum ChartType {
    case line
    case area
}

// MARK: - Metric Card with Chart Component
struct MetricCardWithChart: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let chartData: [ChartDataPoint]
    let chartType: ChartType
    let gradient: LinearGradient
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with title and value
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
       
            .padding(.bottom, 10)
            .padding(.bottom, 5)
            
            // Mini Chart
            if !chartData.isEmpty {
                Chart {
                    ForEach(chartData) { dataPoint in
                        if chartType == .line {
                            LineMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(gradient)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            
                            AreaMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(gradient.opacity(0.1))
                        } else {
                            AreaMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(gradient)
                        }
                    }
                }
                
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                            .foregroundStyle(.clear)
                        AxisValueLabel()
                            .foregroundStyle(.clear)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(.clear)
                        AxisValueLabel()
                            .foregroundStyle(.clear)
                    }
                }
                .frame(height: 55)
            } else {
                // Placeholder when no data
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 55)
                    .overlay(
                        Text("No data")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )
            }

        }

        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    DashboardView()
}
