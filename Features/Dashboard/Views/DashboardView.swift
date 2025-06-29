import SwiftUI
import Charts
import CoreData

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var profileViewModel = ProfileViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                dashboardHeader
                weeklyReadingProgressSection
                dashboardGridSection
                streaksSection
                recentReadingsSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
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
    }
    
    // MARK: - Dashboard Header
    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if let urlString = profileViewModel.profile?.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 44, height: 44)
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.customPrimary, lineWidth: 2))
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.customPrimary, lineWidth: 2))
                    .foregroundColor(.gray)
            }
            Text("Hello, \(profileViewModel.profile?.name ?? "Jessica")")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.purple)
                    .padding(8)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Weekly Reading Progress Section
    private var weeklyReadingProgressSection: some View {
        let dailyGoal: TimeInterval = 20 * 60 // 20 minutes in seconds
        let weekStart = startOfCurrentWeek()
        let calendar = Calendar.current
        return VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.system(size: 26, weight: .regular, design: .default))

                .padding(.bottom, 2)
            HStack(spacing: 12) {
                ForEach(0..<7) { offset in
                    let dayDate = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                    let totalDuration = viewModel.dailyReadingActivity
                        .filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
                        .reduce(0) { $0 + $1.duration }
                    let progress = min(totalDuration / dailyGoal, 1.0)
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 6)
                            .frame(width: 40, height: 40)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progress >= 1.0 ? Color.purple : Color.customPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 40)
                        Text("\(Int(totalDuration/60))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(progress >= 1.0 ? .purple : .customPrimary)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // Helper: Start of current week (Sunday)
    private func startOfCurrentWeek() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return calendar.date(from: components) ?? today
    }
    
    // MARK: - Dashboard Grid Section (Modern Minimalistic)
    private var dashboardGridSection: some View {
        let metrics: [(title: String, value: String, icon: String, color: Color)] = [
            ("Current Streak", "\(viewModel.overallStats?.currentStreakInDays ?? 0)", "flame.fill", .orange),
            ("Active Days", "\(activeDaysThisMonth())", "calendar", .customPrimary),
            ("Lectures", viewModel.totalLecturesDisplay, "mic.fill", .purple),
            ("Total Content", viewModel.totalContentDisplay, "books.vertical.fill", .indigo)
        ]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<metrics.count, id: \.self) { i in
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(metrics[i].color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: metrics[i].icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(metrics[i].color)
                    }
                    Text(metrics[i].value)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(metrics[i].title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Challenges Section (Modern Minimalistic)
    private var streaksSection: some View {
        VStack(alignment: .leading) {
            Text("Challenges")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)
            if let stats = viewModel.challengeStats {
                VStack(alignment: .leading) {
                    ForEach(sortedChallenges(stats.challenges)) { challenge in
                        ChallengeRow(challenge: challenge)
                    }
                    if stats.challenges.isEmpty {
                        Text("No challenges available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
                .background(Color.clear)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                    .frame(height: 120)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
        }
        .padding(.bottom, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent readings")
                .font(.title2)
                .fontWeight(.regular)
                .padding(.top, 8)
            if viewModel.recentlyReadItems.isEmpty {
                Text("No recent reading activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentlyReadItems.prefix(5)) { item in
                            if item.type == .lecture {
                                NavigationLink(
                                    destination: LectureDestinationView(
                                        lectureID: item.itemID ?? "",
                                        lectureTitle: item.title
                                    )
                                ) {
                                    RecentlyReadRow(item: item)
                                        .frame(width: 180)
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
                                        .frame(width: 180)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
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
            ZStack {
                Circle()
                    .fill(Color(challenge.iconColor).opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: challenge.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(challenge.iconColor))
            }
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
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.title2)
                .fontWeight(.semibold)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Total Time", value: viewModel.totalReadingTimeDisplay, iconName: "timer", iconColor: .customPrimary)
                StatCard(title: "Words Read", value: viewModel.totalWordsReadDisplay, iconName: "text.book.closed.fill", iconColor: .purple)
                StatCard(title: "Books Read", value: viewModel.totalBooksReadDisplay, iconName: "books.vertical.fill", iconColor: .indigo)
                StatCard(title: "Active Days This Month", value: "\(activeDaysThisMonth())", iconName: "calendar", iconColor: .orange)
            }
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
        VStack(alignment: .leading, spacing: 6) {
            // Title and type icon
            HStack(spacing: 6) {
                Image(systemName: item.type.iconName)
                    .foregroundColor(item.type.color)
                    .font(.caption)
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Author (if available)
            if let author = item.author {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Lecture-specific info (compact layout)
            if item.type == .lecture {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        if let sectionCount = item.sectionCount {
                            Text("\(sectionCount) sections")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let duration = item.duration {
                            Text(formatTimeInterval(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let level = item.level {
                        Text(level)
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }
            
            // Bottom row: date and status
            HStack {
                Text(item.lastReadDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if item.type == .lecture {
                    // For lectures, show completion status
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Complete")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                } else {
                    // For books/stories, show progress
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(item.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        ProgressView(value: item.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                            .frame(width: 40, height: 2)
                    }
                }
            }
        }
        .padding(8)
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
