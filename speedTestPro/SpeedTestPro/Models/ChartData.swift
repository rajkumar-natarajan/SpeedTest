import Foundation

/// Data point for real-time speed measurements
struct SpeedDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let speed: Double // Mbps
    let phase: TestPhase
    
    /// Time offset from start of test in seconds
    var timeOffset: Double {
        timestamp.timeIntervalSince1970
    }
}

/// Historical chart data for different time ranges
struct ChartTimeRange {
    let title: String
    let days: Int
    
    static let ranges = [
        ChartTimeRange(title: "24H", days: 1),
        ChartTimeRange(title: "7D", days: 7),
        ChartTimeRange(title: "30D", days: 30),
        ChartTimeRange(title: "90D", days: 90)
    ]
}

/// Chart data aggregation
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let downloadSpeed: Double
    let uploadSpeed: Double
    let ping: Double
    let timestamp: String
    
    init(from result: SpeedTestResult) {
        self.date = result.timestamp
        self.downloadSpeed = result.downloadSpeed
        self.uploadSpeed = result.uploadSpeed
        self.ping = result.ping
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.timestamp = formatter.string(from: result.timestamp)
    }
}

/// Real-time measurement tracking
@MainActor
class RealTimeChartData: ObservableObject {
    @Published var downloadDataPoints: [SpeedDataPoint] = []
    @Published var uploadDataPoints: [SpeedDataPoint] = []
    @Published var pingDataPoints: [SpeedDataPoint] = []
    @Published var isRecording = false
    
    private var testStartTime: Date?
    
    /// Start recording real-time data
    func startRecording() {
        isRecording = true
        testStartTime = Date()
        clearData()
    }
    
    /// Stop recording and clear data
    func stopRecording() {
        isRecording = false
        testStartTime = nil
    }
    
    /// Add new data point
    func addDataPoint(speed: Double, phase: TestPhase) {
        guard isRecording else { return }
        
        let dataPoint = SpeedDataPoint(
            timestamp: Date(),
            speed: speed,
            phase: phase
        )
        
        switch phase {
        case .download:
            downloadDataPoints.append(dataPoint)
            // Keep only last 100 points for performance
            if downloadDataPoints.count > 100 {
                downloadDataPoints.removeFirst()
            }
        case .upload:
            uploadDataPoints.append(dataPoint)
            if uploadDataPoints.count > 100 {
                uploadDataPoints.removeFirst()
            }
        case .ping:
            pingDataPoints.append(dataPoint)
            if pingDataPoints.count > 50 {
                pingDataPoints.removeFirst()
            }
        default:
            break
        }
    }
    
    /// Clear all data points
    func clearData() {
        downloadDataPoints.removeAll()
        uploadDataPoints.removeAll()
        pingDataPoints.removeAll()
    }
    
    /// Get maximum speed for chart scaling
    var maxDownloadSpeed: Double {
        downloadDataPoints.map(\.speed).max() ?? 100
    }
    
    var maxUploadSpeed: Double {
        uploadDataPoints.map(\.speed).max() ?? 50
    }
    
    var maxPing: Double {
        pingDataPoints.map(\.speed).max() ?? 100
    }
}
