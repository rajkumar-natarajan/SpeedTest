import Foundation
import Network
import SystemConfiguration

/// Advanced network diagnostic information
struct NetworkDiagnostics: Codable {
    let timestamp: Date
    let connectionType: String
    let interfaceName: String
    let ipAddress: String?
    let subnetMask: String?
    let gateway: String?
    let dnsServers: [String]
    let signalStrength: Int? // For WiFi (dBm) or Cellular (bars)
    let bandwidth: String?
    let mtu: Int?
    let packetLoss: Double? // Percentage
    let jitter: Double? // ms
    let latencyVariation: Double? // ms
    let networkQuality: NetworkQuality
    let securityInfo: NetworkSecurityInfo
    let performanceMetrics: NetworkPerformanceMetrics
}

/// Network quality assessment
struct NetworkQuality: Codable {
    let overall: QualityRating
    let stability: QualityRating
    let speed: QualityRating
    let latency: QualityRating
    
    enum QualityRating: String, Codable, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case unknown = "Unknown"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            case .unknown: return "gray"
            }
        }
    }
}

/// Network security information
struct NetworkSecurityInfo: Codable {
    let isSecure: Bool
    let encryptionType: String?
    let certificateInfo: String?
    let vpnStatus: VPNStatus
    let dnsOverHttps: Bool
    
    enum VPNStatus: String, Codable {
        case active = "Active"
        case inactive = "Inactive"
        case unknown = "Unknown"
    }
}

/// Network performance metrics
struct NetworkPerformanceMetrics: Codable {
    let throughputVariability: Double // Coefficient of variation
    let connectionStability: Double // Percentage uptime
    let responseTimeConsistency: Double // Standard deviation of response times
    let errorRate: Double // Percentage of failed requests
    let retransmissionRate: Double // Percentage of retransmitted packets
}

/// Advanced network diagnostics service
@MainActor
class NetworkDiagnosticsService: ObservableObject {
    @Published var currentDiagnostics: NetworkDiagnostics?
    @Published var diagnosticsHistory: [NetworkDiagnostics] = []
    @Published var isRunningDiagnostics = false
    @Published var diagnosticsProgress: Double = 0.0
    
    private let networkMonitor = NWPathMonitor()
    private let diagnosticsQueue = DispatchQueue(label: "diagnostics", qos: .userInitiated)
    private var continuousMonitoring = false
    
    init() {
        loadDiagnosticsHistory()
        startNetworkMonitoring()
    }
    
    /// Start continuous network monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: diagnosticsQueue)
    }
    
    /// Handle network path updates
    private func handleNetworkPathUpdate(_ path: NWPath) {
        if continuousMonitoring {
            Task {
                await runComprehensiveDiagnostics()
            }
        }
    }
    
    /// Run comprehensive network diagnostics
    func runComprehensiveDiagnostics() async {
        isRunningDiagnostics = true
        diagnosticsProgress = 0.0
        
        defer {
            Task { @MainActor in
                isRunningDiagnostics = false
                diagnosticsProgress = 0.0
            }
        }
        
        // Step 1: Basic network info (20%)
        await updateProgress(0.2)
        let basicInfo = await getBasicNetworkInfo()
        
        // Step 2: IP configuration (40%)
        await updateProgress(0.4)
        let ipConfig = await getIPConfiguration()
        
        // Step 3: DNS analysis (60%)
        await updateProgress(0.6)
        let dnsInfo = await analyzeDNSConfiguration()
        
        // Step 4: Performance testing (80%)
        await updateProgress(0.8)
        let performanceMetrics = await measureNetworkPerformance()
        
        // Step 5: Security analysis (100%)
        await updateProgress(1.0)
        let securityInfo = await analyzeNetworkSecurity()
        
        // Combine all diagnostics
        let diagnostics = NetworkDiagnostics(
            timestamp: Date(),
            connectionType: basicInfo.connectionType,
            interfaceName: basicInfo.interfaceName,
            ipAddress: ipConfig.ipAddress,
            subnetMask: ipConfig.subnetMask,
            gateway: ipConfig.gateway,
            dnsServers: dnsInfo.servers,
            signalStrength: basicInfo.signalStrength,
            bandwidth: basicInfo.bandwidth,
            mtu: ipConfig.mtu,
            packetLoss: performanceMetrics.packetLoss,
            jitter: performanceMetrics.jitter,
            latencyVariation: performanceMetrics.latencyVariation,
            networkQuality: assessNetworkQuality(performanceMetrics),
            securityInfo: securityInfo,
            performanceMetrics: performanceMetrics
        )
        
        await MainActor.run {
            currentDiagnostics = diagnostics
            diagnosticsHistory.insert(diagnostics, at: 0)
            
            // Keep only last 50 diagnostic reports
            if diagnosticsHistory.count > 50 {
                diagnosticsHistory = Array(diagnosticsHistory.prefix(50))
            }
            
            saveDiagnosticsHistory()
        }
    }
    
    /// Get basic network information
    private func getBasicNetworkInfo() async -> (connectionType: String, interfaceName: String, signalStrength: Int?, bandwidth: String?) {
        // Simulate network interface detection
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let path = networkMonitor.currentPath
        
        let connectionType: String
        let interfaceName: String
        
        if path.usesInterfaceType(.wifi) {
            connectionType = "WiFi"
            interfaceName = "en0"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Cellular"
            interfaceName = "pdp_ip0"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = "Ethernet"
            interfaceName = "en1"
        } else {
            connectionType = "Unknown"
            interfaceName = "unknown"
        }
        
        // Simulate signal strength measurement
        let signalStrength: Int? = connectionType == "WiFi" ? Int.random(in: -80...(-30)) : nil
        let bandwidth = "100 Mbps" // This would be detected from interface capabilities
        
        return (connectionType, interfaceName, signalStrength, bandwidth)
    }
    
    /// Get IP configuration
    private func getIPConfiguration() async -> (ipAddress: String?, subnetMask: String?, gateway: String?, mtu: Int?) {
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // In a real implementation, this would use SystemConfiguration framework
        // For now, we'll simulate the values
        let ipAddress = "192.168.1.\(Int.random(in: 100...200))"
        let subnetMask = "255.255.255.0"
        let gateway = "192.168.1.1"
        let mtu = 1500
        
        return (ipAddress, subnetMask, gateway, mtu)
    }
    
    /// Analyze DNS configuration
    private func analyzeDNSConfiguration() async -> (servers: [String]) {
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // This would typically read from system DNS configuration
        let dnsServers = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
        
        return (servers: dnsServers)
    }
    
    /// Measure network performance
    private func measureNetworkPerformance() async -> NetworkPerformanceMetrics {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulate performance measurements
        let throughputVariability = Double.random(in: 0.1...0.5)
        let connectionStability = Double.random(in: 85...99.9)
        let responseTimeConsistency = Double.random(in: 5...50)
        let errorRate = Double.random(in: 0...5)
        let retransmissionRate = Double.random(in: 0...3)
        
        return NetworkPerformanceMetrics(
            throughputVariability: throughputVariability,
            connectionStability: connectionStability,
            responseTimeConsistency: responseTimeConsistency,
            errorRate: errorRate,
            retransmissionRate: retransmissionRate
        )
    }
    
    /// Analyze network security
    private func analyzeNetworkSecurity() async -> NetworkSecurityInfo {
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Simulate security analysis
        let isSecure = Bool.random()
        let encryptionType = isSecure ? "WPA3" : nil
        let vpnStatus: NetworkSecurityInfo.VPNStatus = .inactive
        let dnsOverHttps = Bool.random()
        
        return NetworkSecurityInfo(
            isSecure: isSecure,
            encryptionType: encryptionType,
            certificateInfo: nil,
            vpnStatus: vpnStatus,
            dnsOverHttps: dnsOverHttps
        )
    }
    
    /// Assess overall network quality
    private func assessNetworkQuality(_ metrics: NetworkPerformanceMetrics) -> NetworkQuality {
        let stabilityRating: NetworkQuality.QualityRating
        if metrics.connectionStability > 95 {
            stabilityRating = .excellent
        } else if metrics.connectionStability > 85 {
            stabilityRating = .good
        } else if metrics.connectionStability > 70 {
            stabilityRating = .fair
        } else {
            stabilityRating = .poor
        }
        
        let speedRating: NetworkQuality.QualityRating
        if metrics.throughputVariability < 0.2 {
            speedRating = .excellent
        } else if metrics.throughputVariability < 0.3 {
            speedRating = .good
        } else if metrics.throughputVariability < 0.4 {
            speedRating = .fair
        } else {
            speedRating = .poor
        }
        
        let latencyRating: NetworkQuality.QualityRating
        if metrics.responseTimeConsistency < 15 {
            latencyRating = .excellent
        } else if metrics.responseTimeConsistency < 25 {
            latencyRating = .good
        } else if metrics.responseTimeConsistency < 40 {
            latencyRating = .fair
        } else {
            latencyRating = .poor
        }
        
        // Overall rating is the worst of all categories
        let allRatings = [stabilityRating, speedRating, latencyRating]
        let overallRating = allRatings.min { rating1, rating2 in
            let order: [NetworkQuality.QualityRating] = [.excellent, .good, .fair, .poor]
            return order.firstIndex(of: rating1) ?? 0 < order.firstIndex(of: rating2) ?? 0
        } ?? .unknown
        
        return NetworkQuality(
            overall: overallRating,
            stability: stabilityRating,
            speed: speedRating,
            latency: latencyRating
        )
    }
    
    /// Update progress
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            diagnosticsProgress = progress
        }
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    /// Enable/disable continuous monitoring
    func setContinuousMonitoring(_ enabled: Bool) {
        continuousMonitoring = enabled
    }
    
    /// Load diagnostics history from storage
    private func loadDiagnosticsHistory() {
        if let data = UserDefaults.standard.data(forKey: "diagnosticsHistory"),
           let history = try? JSONDecoder().decode([NetworkDiagnostics].self, from: data) {
            diagnosticsHistory = history
        }
    }
    
    /// Save diagnostics history to storage
    private func saveDiagnosticsHistory() {
        if let data = try? JSONEncoder().encode(diagnosticsHistory) {
            UserDefaults.standard.set(data, forKey: "diagnosticsHistory")
        }
    }
    
    /// Clear diagnostics history
    func clearHistory() {
        diagnosticsHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "diagnosticsHistory")
    }
}
