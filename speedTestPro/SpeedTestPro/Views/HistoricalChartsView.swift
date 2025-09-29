import SwiftUI
import Charts

struct HistoricalChartsView: View {
    @ObservedObject var testHistory: TestHistory
    @State private var selectedTimeRange = ChartTimeRange.ranges[1] // 7 days default
    @State private var selectedMetric = 0
    
    private let metrics = ["Download", "Upload", "Ping"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Metric Selector
                    metricSelector
                    
                    // Main Chart
                    mainChart
                    
                    // Statistics Summary
                    statisticsSummary
                    
                    // Trend Analysis
                    trendAnalysis
                }
                .padding()
            }
            .navigationTitle("Speed History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Range")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChartTimeRange.ranges, id: \.title) { range in
                        Button(action: {
                            selectedTimeRange = range
                        }) {
                            Text(range.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedTimeRange.title == range.title ? Color.blue : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedTimeRange.title == range.title ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var metricSelector: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(0..<metrics.count, id: \.self) { index in
                Text(metrics[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chartTitle)
                .font(.headline)
            
            Chart(filteredResults) { result in
                LineMark(
                    x: .value("Date", result.date),
                    y: .value("Value", getMetricValue(result))
                )
                .foregroundStyle(chartColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Date", result.date),
                    y: .value("Value", getMetricValue(result))
                )
                .foregroundStyle(chartColor)
                .symbolSize(30)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel {
                        Text("\(value.as(Double.self) ?? 0, specifier: "%.0f")\(metricUnit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statisticsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "Average", value: averageValue, unit: metricUnit, color: .blue)
                StatCard(title: "Peak", value: maxValue, unit: metricUnit, color: .green)
                StatCard(title: "Lowest", value: minValue, unit: metricUnit, color: .orange)
                StatCard(title: "Tests", value: "\(filteredResults.count)", unit: "", color: .purple)
            }
        }
    }
    
    private var trendAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.headline)
            
            HStack {
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                
                Text(trendDescription)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(trendColor.opacity(0.1))
            )
        }
    }
    
    private var filteredResults: [ChartDataPoint] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return testHistory.allResults
            .filter { $0.timestamp >= cutoffDate }
            .map { ChartDataPoint(from: $0) }
            .sorted { $0.date < $1.date }
    }
    
    private var chartTitle: String {
        "\(metrics[selectedMetric]) Speed Over Time"
    }
    
    private var chartColor: Color {
        switch selectedMetric {
        case 0: return .blue
        case 1: return .green
        case 2: return .orange
        default: return .blue
        }
    }
    
    private var metricUnit: String {
        selectedMetric == 2 ? " ms" : " Mbps"
    }
    
    private func getMetricValue(_ result: ChartDataPoint) -> Double {
        switch selectedMetric {
        case 0: return result.downloadSpeed
        case 1: return result.uploadSpeed
        case 2: return result.ping
        default: return 0
        }
    }
    
    private var averageValue: String {
        let values = filteredResults.map { getMetricValue($0) }
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return String(format: "%.1f", average)
    }
    
    private var maxValue: String {
        let values = filteredResults.map { getMetricValue($0) }
        let max = values.max() ?? 0
        return String(format: "%.1f", max)
    }
    
    private var minValue: String {
        let values = filteredResults.map { getMetricValue($0) }
        let min = values.min() ?? 0
        return String(format: "%.1f", min)
    }
    
    private var trendIcon: String {
        let values = filteredResults.map { getMetricValue($0) }
        guard values.count >= 2 else { return "minus" }
        
        let recent = Array(values.suffix(max(values.count / 3, 1)))
        let earlier = Array(values.prefix(max(values.count / 3, 1)))
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.reduce(0, +) / Double(earlier.count)
        
        let change = recentAvg - earlierAvg
        let threshold = earlierAvg * 0.1 // 10% threshold
        
        if change > threshold {
            return "arrow.up.right"
        } else if change < -threshold {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    private var trendColor: Color {
        let icon = trendIcon
        switch icon {
        case "arrow.up.right": return .green
        case "arrow.down.right": return .red
        default: return .blue
        }
    }
    
    private var trendDescription: String {
        let values = filteredResults.map { getMetricValue($0) }
        guard values.count >= 2 else { return "Not enough data for trend analysis" }
        
        let recent = Array(values.suffix(max(values.count / 3, 1)))
        let earlier = Array(values.prefix(max(values.count / 3, 1)))
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.reduce(0, +) / Double(earlier.count)
        
        let change = recentAvg - earlierAvg
        let percentChange = abs(change / earlierAvg * 100)
        
        if change > earlierAvg * 0.1 {
            return "Improving trend: \(String(format: "%.1f", percentChange))% increase"
        } else if change < -earlierAvg * 0.1 {
            return "Declining trend: \(String(format: "%.1f", percentChange))% decrease"
        } else {
            return "Stable performance over time"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    HistoricalChartsView(testHistory: TestHistory.shared)
}
