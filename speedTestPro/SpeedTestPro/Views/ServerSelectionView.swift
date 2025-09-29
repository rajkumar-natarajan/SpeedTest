import SwiftUI
import CoreLocation

struct ServerSelectionView: View {
    @StateObject private var serverService = ServerSelectionService()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCriteria: ServerSelectionCriteria = .automatic
    @State private var showingServerDetails = false
    @State private var selectedServerForDetails: SpeedTestServer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selection Criteria
                selectionCriteriaSection
                
                Divider()
                
                // Server List
                serverListSection
            }
            .navigationTitle("Select Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        serverService.selectionCriteria = selectedCriteria
                        serverService.selectBestServer()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedServerForDetails) { server in
                ServerDetailView(server: server)
            }
        }
        .task {
            await serverService.fetchServersFromAPI()
            await serverService.testServerPerformance()
        }
    }
    
    private var selectionCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selection Method")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                SelectionCriteriaRow(
                    title: "Automatic",
                    subtitle: "Best balance of speed and distance",
                    icon: "wand.and.stars",
                    isSelected: isSelected(.automatic)
                ) {
                    selectedCriteria = .automatic
                }
                
                SelectionCriteriaRow(
                    title: "Nearest",
                    subtitle: "Closest server to your location",
                    icon: "location",
                    isSelected: isSelected(.nearest)
                ) {
                    selectedCriteria = .nearest
                }
                
                SelectionCriteriaRow(
                    title: "Fastest",
                    subtitle: "Server with lowest ping time",
                    icon: "bolt",
                    isSelected: isSelected(.fastest)
                ) {
                    selectedCriteria = .fastest
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var serverListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Servers")
                    .font(.headline)
                
                Spacer()
                
                if serverService.isLoadingServers {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            
            if serverService.availableServers.isEmpty {
                ContentUnavailableView(
                    "No Servers Available",
                    systemImage: "server.rack",
                    description: Text("Pull to refresh to load servers")
                )
            } else {
                List(serverService.availableServers) { server in
                    ServerRow(
                        server: server,
                        performance: serverService.serverPerformance[server.id],
                        isSelected: isManuallySelected(server)
                    ) {
                        if case .manual(let currentServer) = selectedCriteria,
                           currentServer.id == server.id {
                            selectedCriteria = .automatic
                        } else {
                            selectedCriteria = .manual(server)
                        }
                    } onShowDetails: {
                        selectedServerForDetails = server
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func isSelected(_ criteria: ServerSelectionCriteria) -> Bool {
        switch (selectedCriteria, criteria) {
        case (.automatic, .automatic),
             (.nearest, .nearest),
             (.fastest, .fastest):
            return true
        default:
            return false
        }
    }
    
    private func isManuallySelected(_ server: SpeedTestServer) -> Bool {
        if case .manual(let selectedServer) = selectedCriteria {
            return selectedServer.id == server.id
        }
        return false
    }
}

struct SelectionCriteriaRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ServerRow: View {
    let server: SpeedTestServer
    let performance: ServerPerformance?
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowDetails: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Flag or icon
                    Image(systemName: "server.rack")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("\(server.location), \(server.country)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            if let distance = server.distance {
                                Label("\(Int(distance)) km", systemImage: "location")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let ping = performance?.averagePing {
                                Label("\(Int(ping)) ms", systemImage: "timer")
                                    .font(.caption2)
                                    .foregroundColor(ping < 50 ? .green : ping < 100 ? .orange : .red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onShowDetails) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

struct ServerDetailView: View {
    let server: SpeedTestServer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Server Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Server Information")
                            .font(.headline)
                        
                        InfoRow(label: "Name", value: server.name)
                        InfoRow(label: "Location", value: "\(server.location), \(server.country)")
                        InfoRow(label: "Sponsor", value: server.sponsor)
                        InfoRow(label: "Host", value: server.host)
                        InfoRow(label: "Port", value: "\(server.port)")
                        
                        if let distance = server.distance {
                            InfoRow(label: "Distance", value: "\(String(format: "%.1f", distance)) km")
                        }
                    }
                    
                    Divider()
                    
                    // Performance Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance")
                            .font(.headline)
                        
                        if let ping = server.ping {
                            InfoRow(label: "Ping", value: "\(Int(ping)) ms")
                        } else {
                            Text("Performance data not available")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Server Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ServerSelectionView()
}
