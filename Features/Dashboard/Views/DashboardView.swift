import SwiftUI
import Charts // Ensure this is imported for Charts and advanced Date formatting

struct DashboardView: View { // Renamed to DashboardView
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.dailyReadingActivity.isEmpty {
                    ProgressView("Loading Dashboard...")
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.refreshData()
                        }
                        .padding(.top)
                    }
                    .padding()
                } else {
                    dashboardContentView
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.refreshData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    private var dashboardContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome Back!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Here's your reading progress.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)

                overallStatsSection
                    .padding(.bottom)
                
                recentlyReadSection
                    .padding(.bottom)

                chartsSection
                
                Spacer()
            }
            .padding()
        }
    }

    private var overallStatsSection: some View {
        VStack(alignment: .leading) {
            Text("Your Progress")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            HStack(spacing: 16) {
                StatCard(title: "Total Time", value: viewModel.totalReadingTimeDisplay, iconName: "timer", iconColor: .blue)
                StatCard(title: "Streak", value: viewModel.currentStreakDisplay, iconName: "flame.fill", iconColor: .orange)
                StatCard(title: "Words Read", value: viewModel.totalWordsReadDisplay, iconName: "text.book.closed.fill", iconColor: .green)
            }
        }
    }

    private var recentlyReadSection: some View {
        VStack(alignment: .leading) {
            Text("Recently Read")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            if viewModel.recentlyReadItems.isEmpty {
                Text("No recently read items yet. Start reading to see them here!")
                    .font(.callout)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            } else {
                ForEach(viewModel.recentlyReadItems) { item in
                    RecentlyReadRow(item: item)
                }
            }
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Reading Activity")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                // This Picker section is critical
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(ActivityTimeRange.allCases) { range in // ActivityTimeRange must be visible here
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.bottom, 8)

            if #available(iOS 16.0, macOS 13.0, *) { // Charts require iOS 16+
                if viewModel.isLoading && viewModel.dailyReadingActivity.isEmpty {
                     HStack {
                         Spacer()
                         ProgressView("Loading chart data...")
                         Spacer()
                     }
                     .frame(height: 400)
                } else if viewModel.dailyReadingActivity.isEmpty && !viewModel.isLoading {
                    Text("Not enough reading activity for the selected period to display charts.")
                        .font(.callout)
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 400)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                } else if !viewModel.dailyReadingActivity.isEmpty {
                    // Chart 1: Reading Duration (Bar Chart)
                    VStack(alignment: .leading) {
                        Text("Time Spent (Minutes)")
                            .font(.headline)
                        Chart(viewModel.dailyReadingActivity) { dataPoint in
                            BarMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Minutes Read", dataPoint.duration / 60)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: appropriateStrideUnit(for: viewModel.selectedTimeRange))) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: xAxisDateStyle(for: viewModel.selectedTimeRange), centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .automatic, position: .leading)
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // Chart 2: Words Read (Line Chart)
                    VStack(alignment: .leading) {
                        Text("Words Read")
                            .font(.headline)
                        Chart(viewModel.dailyReadingActivity) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Words Read", dataPoint.wordsRead)
                            )
                            .foregroundStyle(Color.green.gradient)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", dataPoint.date, unit: .day),
                                y: .value("Words Read", dataPoint.wordsRead)
                            )
                            .foregroundStyle(Color.green)
                            .symbolSize(CGSize(width: 5, height: 5))
                        }
                        .chartXAxis {
                           AxisMarks(values: .stride(by: appropriateStrideUnit(for: viewModel.selectedTimeRange))) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: xAxisDateStyle(for: viewModel.selectedTimeRange), centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .automatic, position: .leading)
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            } else {
                Text("Charts are available on iOS 16+ and macOS 13+.\nPlease update your OS to see your reading activity.")
                    .font(.callout)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    private func appropriateStrideUnit(for range: ActivityTimeRange) -> Calendar.Component {
        switch range { // ActivityTimeRange must be visible here
        case .last7Days:
            return .day
        case .last30Days:
            return .weekOfYear 
        case .last90Days:
            return .month
        }
    }

    // Corrected X-axis Date.FormatStyle
    private func xAxisDateStyle(for range: ActivityTimeRange) -> Date.FormatStyle { // ActivityTimeRange must be visible here
        switch range {
        case .last7Days:
            return Date.FormatStyle().weekday(.narrow)
        case .last30Days:
            return Date.FormatStyle().month(.abbreviated).day(.defaultDigits)
        case .last90Days:
            return Date.FormatStyle().month(.abbreviated)
        }
    }
}

// MARK: - Subviews (StatCard, RecentlyReadRow)
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
                Text(title)
                    .font(.caption) 
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.title3) 
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading) 
        .background(Color(.systemGray6)) 
        .cornerRadius(12)
    }
}

struct RecentlyReadRow: View {
    let item: RecentlyReadItem

    var body: some View {
        HStack {
            Image(systemName: "book.fill") 
                .font(.largeTitle)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .padding(.trailing, 8)

            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                if let author = item.author {
                    Text("by \(author)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                ProgressView(value: item.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                Text("Last read: \(item.lastReadDate, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground)) 
        .cornerRadius(10)
    }
}

// MARK: - Previews
struct DashboardView_Previews: PreviewProvider { // Updated preview name
    static var previews: some View {
        DashboardView()
            .preferredColorScheme(.light)
        DashboardView()
            .preferredColorScheme(.dark)
    }
}
