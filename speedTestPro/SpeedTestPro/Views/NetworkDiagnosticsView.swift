import SwiftUI

struct NetworkDiagnosticsView: View {
    @StateObject private var diagnosticsService = NetworkDiagnosticsService()
    @State private var selectedTab = 0
    
    private let tabs = ["Overview", "Technical", "History"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Tab", selection: $selectedTab) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Text(tabs[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    overviewTab.tag(0)
                    technicalTab.tag(1)
                    historyTab.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Network Diagnostics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Run Diagnostics") {
                        Task {
                            await diagnosticsService.runComprehensiveDiagnostics()
                        }
                    }
                    .disabled(diagnosticsService.isRunningDiagnostics)
                }
            }
            .overlay {
                if diagnosticsService.isRunningDiagnostics {
                    diagnosticsProgressView
                }
            }
        }
    }
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let diagnostics = diagnosticsService.currentDiagnostics {
                    networkStatusCard(diagnostics)
                    qualityOverviewCard(diagnostics)
                    quickMetricsCard(diagnostics)
                    securityStatusCard(diagnostics)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
    }
    
    private var technicalTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let diagnostics = diagnosticsService.currentDiagnostics {
                    networkConfigCard(diagnostics)
                    performanceMetricsCard(diagnostics)
                    dnsConfigCard(diagnostics)
                    advancedMetricsCard(diagnostics)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
    }
    
    private var historyTab: some View {
        List {
            ForEach(diagnosticsService.diagnosticsHistory, id: \.timestamp) { diagnostics in
                DiagnosticsHistoryRow(diagnostics: diagnostics)
            }
            .onDelete(perform: deleteHistoryItems)
        }
        .listStyle(PlainListStyle())
        .overlay {
            if diagnosticsService.diagnosticsHistory.isEmpty {
                ContentUnavailableView(
                    "No Diagnostic History",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Run diagnostics to see historical data")
                )
            }
        }
    }
    
    private var diagnosticsProgressView: some View {
        VStack(spacing: 16) {
            ProgressView(value: diagnosticsService.diagnosticsProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Running Network Diagnostics...")
                .font(.headline)
            
            Text("\(Int(diagnosticsService.diagnosticsProgress * 100))% Complete")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Diagnostics Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap 'Run Diagnostics' to analyze your network")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func networkStatusCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: connectionIcon(diagnostics.connectionType))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(diagnostics.connectionType)
                        .font(.headline)
                    
                    Text(diagnostics.interfaceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                QualityBadge(rating: diagnostics.networkQuality.overall)
            }
            
            if let ipAddress = diagnostics.ipAddress {
                HStack {
                    Text("IP Address:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(ipAddress)
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            if let signalStrength = diagnostics.signalStrength {
                HStack {
                    Text("Signal Strength:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(signalStrength) dBm")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func qualityOverviewCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Quality")
                .font(.headline)
            
            VStack(spacing: 8) {
                QualityRow(title: "Overall", rating: diagnostics.networkQuality.overall)
                QualityRow(title: "Stability", rating: diagnostics.networkQuality.stability)
                QualityRow(title: "Speed", rating: diagnostics.networkQuality.speed)
                QualityRow(title: "Latency", rating: diagnostics.networkQuality.latency)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func quickMetricsCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Metrics")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                if let packetLoss = diagnostics.packetLoss {
                    MetricTile(title: "Packet Loss", value: "\(String(format: "%.1f", packetLoss))%", color: packetLoss < 1 ? .green : .red)
                }
                
                if let jitter = diagnostics.jitter {
                    MetricTile(title: "Jitter", value: "\(String(format: "%.1f", jitter)) ms", color: jitter < 10 ? .green : .orange)
                }
                
                if let mtu = diagnostics.mtu {
                    MetricTile(title: "MTU", value: "\(mtu)", color: .blue)
                }
                
                MetricTile(title: "DNS Servers", value: "\(diagnostics.dnsServers.count)", color: .purple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func securityStatusCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security Status")
                .font(.headline)
            
            VStack(spacing: 8) {
                SecurityRow(
                    title: "Connection Security",
                    status: diagnostics.securityInfo.isSecure ? "Secure" : "Unsecured",
                    isSecure: diagnostics.securityInfo.isSecure
                )
                
                if let encryption = diagnostics.securityInfo.encryptionType {
                    SecurityRow(
                        title: "Encryption",
                        status: encryption,
                        isSecure: true
                    )
                }
                
                SecurityRow(
                    title: "VPN Status",
                    status: diagnostics.securityInfo.vpnStatus.rawValue,
                    isSecure: diagnostics.securityInfo.vpnStatus == .active
                )
                
                SecurityRow(
                    title: "DNS over HTTPS",
                    status: diagnostics.securityInfo.dnsOverHttps ? "Enabled" : "Disabled",
                    isSecure: diagnostics.securityInfo.dnsOverHttps
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func networkConfigCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Configuration")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let ip = diagnostics.ipAddress {
                    ConfigRow(label: "IP Address", value: ip)
                }
                
                if let subnet = diagnostics.subnetMask {
                    ConfigRow(label: "Subnet Mask", value: subnet)
                }
                
                if let gateway = diagnostics.gateway {
                    ConfigRow(label: "Gateway", value: gateway)
                }
                
                if let mtu = diagnostics.mtu {
                    ConfigRow(label: "MTU", value: "\(mtu)")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func performanceMetricsCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
            
            VStack(spacing: 8) {
                ConfigRow(
                    label: "Throughput Variability",
                    value: String(format: "%.3f", diagnostics.performanceMetrics.throughputVariability)
                )
                
                ConfigRow(
                    label: "Connection Stability",
                    value: "\(String(format: "%.1f", diagnostics.performanceMetrics.connectionStability))%"
                )
                
                ConfigRow(
                    label: "Response Consistency",
                    value: "\(String(format: "%.1f", diagnostics.performanceMetrics.responseTimeConsistency)) ms"
                )
                
                ConfigRow(
                    label: "Error Rate",
                    value: "\(String(format: "%.2f", diagnostics.performanceMetrics.errorRate))%"
                )
                
                ConfigRow(
                    label: "Retransmission Rate",
                    value: "\(String(format: "%.2f", diagnostics.performanceMetrics.retransmissionRate))%"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func dnsConfigCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DNS Configuration")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(diagnostics.dnsServers, id: \.self) { server in
                    HStack {
                        Text("DNS Server")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(server)
                            .font(.system(.body, design: .monospaced))
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
    
    private func advancedMetricsCard(_ diagnostics: NetworkDiagnostics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Metrics")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let latencyVar = diagnostics.latencyVariation {
                    ConfigRow(label: "Latency Variation", value: "\(String(format: "%.1f", latencyVar)) ms")
                }
                
                if let bandwidth = diagnostics.bandwidth {
                    ConfigRow(label: "Interface Bandwidth", value: bandwidth)
                }
                
                ConfigRow(label: "Timestamp", value: DateFormatter.medium.string(from: diagnostics.timestamp))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func connectionIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "wifi": return "wifi"
        case "cellular": return "antenna.radiowaves.left.and.right"
        case "ethernet": return "cable.connector"
        default: return "network"
        }
    }
    
    private func deleteHistoryItems(at offsets: IndexSet) {
        // Note: This would remove items from the history
        // Implementation depends on the service architecture
    }
}

struct QualityBadge: View {
    let rating: NetworkQuality.QualityRating
    
    var body: some View {
        Text(rating.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(badgeColor)
            )
            .foregroundColor(.white)
    }
    
    private var badgeColor: Color {
        switch rating {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

struct QualityRow: View {
    let title: String
    let rating: NetworkQuality.QualityRating
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            QualityBadge(rating: rating)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

struct SecurityRow: View {
    let title: String
    let status: String
    let isSecure: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSecure ? "checkmark.shield" : "exclamationmark.shield")
                .foregroundColor(isSecure ? .green : .red)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(status)
                .fontWeight(.medium)
                .foregroundColor(isSecure ? .green : .red)
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct DiagnosticsHistoryRow: View {
    let diagnostics: NetworkDiagnostics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(diagnostics.connectionType)
                    .font(.headline)
                
                Spacer()
                
                QualityBadge(rating: diagnostics.networkQuality.overall)
            }
            
            HStack {
                Text(DateFormatter.medium.string(from: diagnostics.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let ip = diagnostics.ipAddress {
                    Text(ip)
                        .font(.caption)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NetworkDiagnosticsView()
}
