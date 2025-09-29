import Foundation
import CoreLocation

/// Represents a speed test server
struct SpeedTestServer: Codable, Identifiable, Equatable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
    let location: String
    let country: String
    let latitude: Double
    let longitude: Double
    let sponsor: String
    let distance: Double?
    let ping: Double?
    
    /// Calculate distance from user location
    func distanceFrom(userLocation: CLLocation) -> Double {
        let serverLocation = CLLocation(latitude: latitude, longitude: longitude)
        return userLocation.distance(from: serverLocation) / 1000 // Convert to kilometers
    }
    
    /// Server URL for testing
    var baseURL: String {
        return "https://\(host):\(port)"
    }
    
    static func == (lhs: SpeedTestServer, rhs: SpeedTestServer) -> Bool {
        lhs.id == rhs.id
    }
}

/// Server selection criteria
enum ServerSelectionCriteria {
    case automatic
    case nearest
    case fastest
    case manual(SpeedTestServer)
}

/// Server performance metrics
struct ServerPerformance: Codable {
    let serverId: UUID
    let averagePing: Double
    let reliability: Double // 0.0 to 1.0
    let lastTested: Date
    let testCount: Int
}
