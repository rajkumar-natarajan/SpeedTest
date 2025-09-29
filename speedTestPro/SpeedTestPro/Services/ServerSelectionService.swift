import Foundation
import CoreLocation

/// Service for managing speed test servers
@MainActor
class ServerSelectionService: ObservableObject {
    @Published var availableServers: [SpeedTestServer] = []
    @Published var selectedServer: SpeedTestServer?
    @Published var selectionCriteria: ServerSelectionCriteria = .automatic
    @Published var isLoadingServers = false
    @Published var serverPerformance: [UUID: ServerPerformance] = [:]
    
    private let locationManager = CLLocationManager()
    private var userLocation: CLLocation?
    
    init() {
        loadDefaultServers()
        requestLocationPermission()
    }
    
    /// Load default servers from configuration
    private func loadDefaultServers() {
        availableServers = [
            SpeedTestServer(
                name: "Speedtest.net Global",
                host: "speedtest.net",
                port: 443,
                location: "Amsterdam",
                country: "Netherlands",
                latitude: 52.3676,
                longitude: 4.9041,
                sponsor: "Ookla",
                distance: nil,
                ping: nil
            ),
            SpeedTestServer(
                name: "Google Fiber",
                host: "storage.googleapis.com",
                port: 443,
                location: "Mountain View",
                country: "USA",
                latitude: 37.4419,
                longitude: -122.1430,
                sponsor: "Google",
                distance: nil,
                ping: nil
            ),
            SpeedTestServer(
                name: "Cloudflare",
                host: "speed.cloudflare.com",
                port: 443,
                location: "San Francisco",
                country: "USA",
                latitude: 37.7749,
                longitude: -122.4194,
                sponsor: "Cloudflare",
                distance: nil,
                ping: nil
            ),
            SpeedTestServer(
                name: "Amazon AWS",
                host: "aws.amazon.com",
                port: 443,
                location: "Virginia",
                country: "USA",
                latitude: 39.0458,
                longitude: -76.6413,
                sponsor: "Amazon",
                distance: nil,
                ping: nil
            ),
            SpeedTestServer(
                name: "Microsoft Azure",
                host: "azure.microsoft.com",
                port: 443,
                location: "Dublin",
                country: "Ireland",
                latitude: 53.3498,
                longitude: -6.2603,
                sponsor: "Microsoft",
                distance: nil,
                ping: nil
            )
        ]
    }
    
    /// Request location permission for distance calculation
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Fetch servers from remote API (placeholder for real implementation)
    func fetchServersFromAPI() async {
        isLoadingServers = true
        defer { isLoadingServers = false }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // In real implementation, this would fetch from speedtest.net API
        // For now, we'll use the default servers
        updateServerDistances()
    }
    
    /// Update server distances based on user location
    private func updateServerDistances() {
        guard let userLocation = userLocation else { return }
        
        for i in 0..<availableServers.count {
            let distance = availableServers[i].distanceFrom(userLocation: userLocation)
            availableServers[i] = SpeedTestServer(
                name: availableServers[i].name,
                host: availableServers[i].host,
                port: availableServers[i].port,
                location: availableServers[i].location,
                country: availableServers[i].country,
                latitude: availableServers[i].latitude,
                longitude: availableServers[i].longitude,
                sponsor: availableServers[i].sponsor,
                distance: distance,
                ping: availableServers[i].ping
            )
        }
    }
    
    /// Test ping to all servers and update performance
    func testServerPerformance() async {
        for server in availableServers {
            let ping = await measurePing(to: server)
            
            let performance = ServerPerformance(
                serverId: server.id,
                averagePing: ping,
                reliability: ping < 100 ? 0.9 : 0.7, // Simple reliability calculation
                lastTested: Date(),
                testCount: 1
            )
            
            serverPerformance[server.id] = performance
        }
    }
    
    /// Measure ping to a specific server
    private func measurePing(to server: SpeedTestServer) async -> Double {
        // Simulate ping measurement
        return Double.random(in: 10...150)
    }
    
    /// Select best server based on criteria
    func selectBestServer() {
        switch selectionCriteria {
        case .automatic:
            selectAutomaticServer()
        case .nearest:
            selectNearestServer()
        case .fastest:
            selectFastestServer()
        case .manual(let server):
            selectedServer = server
        }
    }
    
    private func selectAutomaticServer() {
        // Balanced selection considering both distance and performance
        let scored = availableServers.map { server in
            let distanceScore = (server.distance ?? 1000) / 1000 // Normalize distance
            let pingScore = (serverPerformance[server.id]?.averagePing ?? 100) / 100 // Normalize ping
            let totalScore = distanceScore + pingScore
            return (server, totalScore)
        }
        
        selectedServer = scored.min(by: { $0.1 < $1.1 })?.0
    }
    
    private func selectNearestServer() {
        selectedServer = availableServers.min(by: { 
            ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) 
        })
    }
    
    private func selectFastestServer() {
        selectedServer = availableServers.min(by: { server1, server2 in
            let ping1 = serverPerformance[server1.id]?.averagePing ?? Double.infinity
            let ping2 = serverPerformance[server2.id]?.averagePing ?? Double.infinity
            return ping1 < ping2
        })
    }
    
    /// Set user location
    func setUserLocation(_ location: CLLocation) {
        userLocation = location
        updateServerDistances()
    }
}
