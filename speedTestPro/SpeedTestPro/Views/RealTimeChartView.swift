import SwiftUI
import Charts

struct RealTimeChartView: View {
    @StateObject private var chartData = RealTimeChartData()
    @ObservedObject var viewModel: SpeedTestViewModel
    
    @State private var selectedTab = 0
    private let tabs = ["Download", "Upload", "Ping"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab Selector
            Picker("Chart Type", selection: $selectedTab) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Text(tabs[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Chart
            chartView
                .frame(height: 200)
                .padding(.horizontal)
            
            // Current Values
            currentValuesView
        }
        .onChange(of: viewModel.isTestingInProgress) { _, isRunning in
            if isRunning {
                chartData.startRecording()
            } else {
                chartData.stopRecording()
            }
        }
        .onChange(of: viewModel.currentSpeed) { _, speed in
            if viewModel.isTestingInProgress {
                chartData.addDataPoint(speed: speed, phase: viewModel.currentTestPhase)
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch selectedTab {
        case 0: // Download
            downloadChart
        case 1: // Upload
            uploadChart
        case 2: // Ping
            pingChart
        default:
            EmptyView()
        }
    }
    
    private var downloadChart: some View {
        Chart(chartData.downloadDataPoints) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Speed", dataPoint.speed)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Speed", dataPoint.speed)
            )
            .foregroundStyle(.blue.opacity(0.2))
        }
        .chartYScale(domain: 0...max(chartData.maxDownloadSpeed * 1.1, 10))
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    Text("\(value.as(Double.self) ?? 0, specifier: "%.0f") Mbps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text("Download Speed")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(8)
        }
    }
    
    private var uploadChart: some View {
        Chart(chartData.uploadDataPoints) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Speed", dataPoint.speed)
            )
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Speed", dataPoint.speed)
            )
            .foregroundStyle(.green.opacity(0.2))
        }
        .chartYScale(domain: 0...max(chartData.maxUploadSpeed * 1.1, 10))
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    Text("\(value.as(Double.self) ?? 0, specifier: "%.0f") Mbps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text("Upload Speed")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .padding(8)
        }
    }
    
    private var pingChart: some View {
        Chart(chartData.pingDataPoints) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Ping", dataPoint.speed)
            )
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", dataPoint.timeOffset),
                y: .value("Ping", dataPoint.speed)
            )
            .foregroundStyle(.orange.opacity(0.2))
        }
        .chartYScale(domain: 0...max(chartData.maxPing * 1.1, 100))
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    Text("\(value.as(Double.self) ?? 0, specifier: "%.0f") ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text("Ping Time")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .padding(8)
        }
    }
    
    private var currentValuesView: some View {
        HStack(spacing: 20) {
            MetricCard(
                title: "Current",
                value: "\(viewModel.currentSpeed, specifier: "%.1f")",
                unit: viewModel.currentTestPhase == .ping ? "ms" : "Mbps",
                color: selectedTab == 0 ? .blue : selectedTab == 1 ? .green : .orange
            )
            
            MetricCard(
                title: "Peak",
                value: getPeakValue(),
                unit: viewModel.currentTestPhase == .ping ? "ms" : "Mbps",
                color: .secondary
            )
            
            MetricCard(
                title: "Average",
                value: getAverageValue(),
                unit: viewModel.currentTestPhase == .ping ? "ms" : "Mbps",
                color: .secondary
            )
        }
        .padding(.horizontal)
    }
    
    private func getPeakValue() -> String {
        switch selectedTab {
        case 0:
            return "\(chartData.maxDownloadSpeed, specifier: "%.1f")"
        case 1:
            return "\(chartData.maxUploadSpeed, specifier: "%.1f")"
        case 2:
            return "\(chartData.maxPing, specifier: "%.1f")"
        default:
            return "0.0"
        }
    }
    
    private func getAverageValue() -> String {
        switch selectedTab {
        case 0:
            let avg = chartData.downloadDataPoints.map(\.speed).reduce(0, +) / Double(max(chartData.downloadDataPoints.count, 1))
            return "\(avg, specifier: "%.1f")"
        case 1:
            let avg = chartData.uploadDataPoints.map(\.speed).reduce(0, +) / Double(max(chartData.uploadDataPoints.count, 1))
            return "\(avg, specifier: "%.1f")"
        case 2:
            let avg = chartData.pingDataPoints.map(\.speed).reduce(0, +) / Double(max(chartData.pingDataPoints.count, 1))
            return "\(avg, specifier: "%.1f")"
        default:
            return "0.0"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    RealTimeChartView(viewModel: SpeedTestViewModel())
}
