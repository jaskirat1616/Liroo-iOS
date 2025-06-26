import SwiftUI
import Combine
import CoreData

class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var overallStats: ReadingStats?
    @Published var dailyReadingActivity: [ReadingActivityDataPoint] = []
    @Published var recentlyReadItems: [RecentlyReadItem] = []
    @Published var challengeStats: ChallengeStats?
    
    // Real collectible data
    @Published var engagementMetrics: EngagementMetrics?
    @Published var readingAnalytics: ReadingAnalytics?
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedViewType: DashboardViewType = .student
    
    @Published var selectedTimeRange: ActivityTimeRange = .last7Days {
        didSet {
            if oldValue != selectedTimeRange {
                fetchDailyActivityData()
            }
        }
    }

    // Computed properties for display
    var totalReadingTimeDisplay: String {
        formatTimeInterval(overallStats?.totalReadingTime ?? 0)
    }
    var currentStreakDisplay: String {
        "\(overallStats?.currentStreakInDays ?? 0) days"
    }
    var totalWordsReadDisplay: String {
        formatLargeNumber(overallStats?.totalWordsRead ?? 0)
    }
    var averageReadingSpeedDisplay: String {
        "\(Int(overallStats?.averageReadingSpeed ?? 0)) WPM"
    }
    var totalBooksReadDisplay: String {
        "\(overallStats?.totalBooksRead ?? 0) books"
    }
    var totalLecturesDisplay: String {
        let lectureCount = recentlyReadItems.filter { $0.type == .lecture }.count
        return "\(lectureCount) lectures"
    }
    var totalContentDisplay: String {
        let bookCount = overallStats?.totalBooksRead ?? 0
        let lectureCount = recentlyReadItems.filter { $0.type == .lecture }.count
        return "\(bookCount + lectureCount) items"
    }
    var totalSessionsDisplay: String {
        "\(overallStats?.totalSessions ?? 0) sessions"
    }
    var averageSessionLengthDisplay: String {
        formatTimeInterval(overallStats?.averageSessionLength ?? 0)
    }
    var longestStreakDisplay: String {
        "\(overallStats?.longestStreak ?? 0) days"
    }
    
    // Engagement stats
    var totalEngagementScore: Double {
        guard let engagement = engagementMetrics else { return 0 }
        let dialogueWeight = 0.6
        let generationWeight = 0.4
        
        let dialogueScore = min(Double(engagement.dialogueInteractions) / 10.0, 1.0)
        let generationScore = min(Double(engagement.contentGenerated) / 5.0, 1.0)
        
        return (dialogueScore * dialogueWeight) + (generationScore * generationWeight)
    }

    // MARK: - Private Properties
    private let dataService: DashboardDataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var activityCancellable: AnyCancellable? 

    // MARK: - Initialization
    init(dataService: DashboardDataServiceProtocol = CoreDataDashboardService(context: PersistenceController.shared.container.viewContext)) {
        self.dataService = dataService
        fetchAllDashboardData()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDashboardRefresh), name: .dashboardNeedsRefresh, object: nil)
    }

    @objc private func handleDashboardRefresh() {
        DispatchQueue.main.async {
            self.refreshData()
        }
    }

    // MARK: - Data Fetching
    
    func fetchAllDashboardData() {
        isLoading = true
        errorMessage = nil
        
        let overallStatsPublisher = dataService.fetchOverallStats()
            .receive(on: DispatchQueue.main)
            .share()

        overallStatsPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.appendErrorMessage(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] stats in
                    self?.overallStats = stats
                    self?.generateRealData()
                }
            )
            .store(in: &cancellables)
        
        // Fetch daily activity
        dataService.fetchDailyReadingActivity(forLastDays: selectedTimeRange.dayCount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.appendErrorMessage(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] activity in
                    self?.dailyReadingActivity = activity
                }
            )
            .store(in: &cancellables)
        
        // Fetch recently read items
        dataService.fetchRecentlyReadItems(limit: 5)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.appendErrorMessage(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] items in
                    self?.recentlyReadItems = items
                }
            )
            .store(in: &cancellables)

        // Fetch challenge stats
        let challengeStatsPublisher = dataService.fetchChallengeStats()
            .receive(on: DispatchQueue.main)
            .share()

        challengeStatsPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                         self?.appendErrorMessage("Failed to load challenge stats: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] newChallengeStats in
                    self?.challengeStats = newChallengeStats
                }
            )
            .store(in: &cancellables)

        // Combine primary publishers to set isLoading to false once all complete
        Publishers.CombineLatest3(
            overallStatsPublisher.map { _ in () }.catch { _ in Just(()) },
            dataService.fetchDailyReadingActivity(forLastDays: selectedTimeRange.dayCount).map { _ in () }.catch { _ in Just(()) },
            challengeStatsPublisher.map { _ in () }.catch { _ in Just(()) }
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] _, _, _ in
            self?.isLoading = false
        })
        .store(in: &cancellables)
    }
    
    func fetchDailyActivityData() {
        activityCancellable?.cancel()
        
        activityCancellable = dataService.fetchDailyReadingActivity(forLastDays: selectedTimeRange.dayCount)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] activity in
                    self?.dailyReadingActivity = activity
                }
            )
    }
    
    func refreshData() {
        fetchAllDashboardData()
    }
    
    // MARK: - Real Data Generation (Based on Collectible Data)
    
    private func generateRealData() {
        guard overallStats != nil else {
            // If overallStats are not yet available, we can't proceed with engagement metrics calculation
            // and analytics fetching that might logically follow them.
            return
        }
        
        // Generate engagement metrics based on real data
        engagementMetrics = calculateEngagementMetrics()
        
        // Fetch real analytics data
        let speedTrendPublisher = dataService.fetchReadingSpeedTrendData(forLastDays: 7)
        let timeDistributionPublisher = dataService.fetchTimeDistributionData()
        let weeklyProgressPublisher = dataService.fetchWeeklyProgressData(forLastWeeks: 4)
        let monthlyProgressPublisher = dataService.fetchMonthlyProgressData(forLastMonths: 3)

        Publishers.Zip4(
            speedTrendPublisher,
            timeDistributionPublisher,
            weeklyProgressPublisher,
            monthlyProgressPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            if case .failure(let error) = completion {
                let existingError = self?.errorMessage ?? ""
                let analyticsError = "Failed to load analytics trends: \(error.localizedDescription)"
                self?.errorMessage = existingError.isEmpty ? analyticsError : "\(existingError)\n\(analyticsError)"
                // Set readingAnalytics to an empty state so UI can handle it gracefully
                self?.readingAnalytics = ReadingAnalytics(readingSpeedTrend: [], readingTimeDistribution: [], weeklyProgress: [], monthlyProgress: [])
            }
        }, receiveValue: { [weak self] speedData, timeData, weeklyData, monthlyData in
            self?.readingAnalytics = ReadingAnalytics(
                readingSpeedTrend: speedData,
                readingTimeDistribution: timeData,
                weeklyProgress: weeklyData,
                monthlyProgress: monthlyData
            )
        })
        .store(in: &cancellables)
    }
    
    private func calculateEngagementMetrics() -> EngagementMetrics {
        // Get real dialogue interactions from UserDefaults
        let dialogueInteractions = UserDefaults.standard.integer(forKey: "dialogueInteractionsCount")
        
        // Get real content generation count from UserDefaults
        let contentGenerated = UserDefaults.standard.integer(forKey: "contentGenerationCount")
        
        // Calculate engagement based on real session data
        let totalSessions = overallStats?.totalSessions ?? 0
        let averageSessionEngagement = totalSessions > 0 ? min(1.0, Double(dialogueInteractions) / Double(totalSessions)) : 0.0
        
        return EngagementMetrics(
            dialogueInteractions: dialogueInteractions,
            contentGenerated: contentGenerated,
            averageSessionEngagement: averageSessionEngagement
        )
    }
    
    // Helper to append error messages
    private func appendErrorMessage(_ message: String) {
        if errorMessage == nil {
            errorMessage = message
        } else {
            errorMessage?.append("\n\(message)")
        }
    }
}
