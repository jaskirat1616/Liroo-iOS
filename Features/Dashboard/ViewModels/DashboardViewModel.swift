import SwiftUI
import Combine
import CoreData

class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var overallStats: ReadingStats?
    @Published var dailyReadingActivity: [ReadingActivityDataPoint] = []
    @Published var recentlyReadItems: [RecentlyReadItem] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var selectedTimeRange: ActivityTimeRange = .last7Days {
        didSet {
            if oldValue != selectedTimeRange {
                fetchDailyActivityData()
            }
        }
    }

    // Computed property for display
    var totalReadingTimeDisplay: String {
        formatTimeInterval(overallStats?.totalReadingTime ?? 0)
    }
    var currentStreakDisplay: String {
        "\(overallStats?.currentStreakInDays ?? 0) days"
    }
    var totalWordsReadDisplay: String {
        "\(overallStats?.totalWordsRead ?? 0) words"
    }

    // MARK: - Private Properties
    private let dataService: DashboardDataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var activityCancellable: AnyCancellable? 

    // MARK: - Initialization
    init(dataService: DashboardDataServiceProtocol = CoreDataDashboardService(context: PersistenceController.shared.container.viewContext)) {
        self.dataService = dataService
        fetchAllDashboardData() 
    }

    // MARK: - Data Fetching
    
    private func fetchInitialData() {
        isLoading = true 
        errorMessage = nil
        
        let statsPublisher = dataService.fetchOverallStats()
            .receive(on: DispatchQueue.main)
            .share() 

        let recentItemsPublisher = dataService.fetchRecentlyReadItems(limit: 3)
            .receive(on: DispatchQueue.main)
            .share()

        statsPublisher
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError("Failed to load stats", error)
                }
            }, receiveValue: { [weak self] stats in
                self?.overallStats = stats
            })
            .store(in: &cancellables)

        recentItemsPublisher
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleError("Failed to load recent items", error)
                }
            }, receiveValue: { [weak self] items in
                self?.recentlyReadItems = items
            })
            .store(in: &cancellables)
            
        Publishers.Zip(statsPublisher, recentItemsPublisher)
            .map { _, _ in } 
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(_) = completion {
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func fetchDailyActivityData() {
        isLoading = true 

        activityCancellable?.cancel() 

        activityCancellable = dataService.fetchDailyReadingActivity(forLastDays: selectedTimeRange.dayCount)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false 
                if case .failure(let error) = completion {
                    self?.handleError("Failed to load daily activity", error)
                }
            }, receiveValue: { [weak self] activity in
                self?.dailyReadingActivity = activity
            })
    }

    private func handleError(_ messagePrefix: String, _ error: Error) {
        let newErrorMessage = "\(messagePrefix): \(error.localizedDescription)"
        if self.errorMessage == nil {
            self.errorMessage = newErrorMessage
        } else {
            self.errorMessage?.append("\n\(newErrorMessage)")
        }
    }
    
    func fetchAllDashboardData() {
        cancellables.removeAll() 
        fetchInitialData() 
        fetchDailyActivityData() 
    }
    
    func refreshData() {
        fetchAllDashboardData()
    }
}
