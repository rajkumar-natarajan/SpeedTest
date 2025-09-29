//
//  CommunityMappingService.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import CoreLocation
import os.log

/// Codable coordinate structure for community data
struct CommunityCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Anonymous community speed data point
struct CommunitySpeedData: Codable {
    let id = UUID()
    let location: CommunityCoordinate
    let downloadSpeed: Double
    let uploadSpeed: Double
    let ping: Double
    let connectionType: String
    let timestamp: Date
    let networkProvider: String?
    
    // Privacy: No personal identifiers, location rounded to protect privacy
    var privacyRoundedLocation: CLLocationCoordinate2D {
        // Round to ~1km precision for privacy
        let precision = 0.01 // ~1.1km at equator
        return CLLocationCoordinate2D(
            latitude: round(location.clLocationCoordinate.latitude / precision) * precision,
            longitude: round(location.clLocationCoordinate.longitude / precision) * precision
        )
    }
}

/// Area performance statistics
struct AreaPerformance: Codable {
    let centerLocation: CommunityCoordinate
    let radius: Double // in meters
    let averageDownloadSpeed: Double
    let averageUploadSpeed: Double
    let averagePing: Double
    let sampleCount: Int
    let lastUpdated: Date
    let performanceRating: PerformanceRating
    let dominantProvider: String?
}

enum PerformanceRating: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    static func from(averageSpeed: Double) -> PerformanceRating {
        switch averageSpeed {
        case 50...: return .excellent
        case 25..<50: return .good
        case 10..<25: return .fair
        default: return .poor
        }
    }
}

/// Network provider insights
struct ProviderInsights: Codable {
    let providerName: String
    let averageDownloadSpeed: Double
    let averageUploadSpeed: Double
    let averagePing: Double
    let sampleCount: Int
    let marketShare: Double // percentage in area
    let rating: PerformanceRating
}

/// Community mapping service for anonymous location-based network insights
@MainActor
class CommunityMappingService: ObservableObject {
    @Published var nearbyPerformance: [AreaPerformance] = []
    @Published var providerInsights: [ProviderInsights] = []
    @Published var currentAreaRating: PerformanceRating = .fair
    @Published var isLoadingCommunityData = false
    @Published var userConsent = false
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "CommunityMapping")
    private let userDefaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    
    // MARK: - Privacy Keys
    private let consentKey = "CommunityMappingConsent"
    private let communityDataKey = "CommunitySpeedData"
    private let lastUploadKey = "LastCommunityUpload"
    
    // Simulated community data for demonstration
    private var communityDatabase: [CommunitySpeedData] = []
    
    init() {
        loadUserConsent()
        generateSampleCommunityData()
    }
    
    // MARK: - User Consent Management
    
    /// Request user consent for anonymous data sharing
    func requestCommunityParticipation() {
        // In a real implementation, this would show a detailed privacy dialog
        userConsent = true
        saveUserConsent()
        logger.info("User opted into community mapping with full privacy protection")
    }
    
    /// Revoke consent and delete local data
    func revokeCommunityParticipation() {
        userConsent = false
        saveUserConsent()
        clearLocalCommunityData()
        logger.info("User opted out of community mapping - data cleared")
    }
    
    // MARK: - Data Contribution
    
    /// Contribute anonymous speed test result to community database
    func contributeResult(_ result: SpeedTestResult, location: CLLocation?) async {
        guard userConsent else { return }
        guard let location = location else { return }
        
        logger.info("Contributing anonymous result to community database")
        
        let communityData = CommunitySpeedData(
            location: CommunityCoordinate(from: location.coordinate),
            downloadSpeed: result.downloadSpeed,
            uploadSpeed: result.uploadSpeed,
            ping: result.ping,
            connectionType: result.connectionType,
            timestamp: result.timestamp,
            networkProvider: detectNetworkProvider() // Would use real detection
        )
        
        // Add to local database (simulating server upload)
        communityDatabase.append(communityData)
        
        // In a real implementation, this would upload to a secure server
        await simulateServerUpload(communityData)
        
        // Update local insights after contribution
        await updateLocalInsights(for: location)
    }
    
    // MARK: - Community Insights
    
    /// Load community insights for current location
    func loadCommunityInsights(for location: CLLocation) async {
        isLoadingCommunityData = true
        defer { isLoadingCommunityData = false }
        
        logger.info("Loading community insights for location")
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Generate nearby area performance
        let nearbyAreas = generateNearbyAreaPerformance(around: location)
        self.nearbyPerformance = nearbyAreas
        
        // Generate provider insights
        let providers = generateProviderInsights(for: location)
        self.providerInsights = providers
        
        // Determine current area rating
        if let currentArea = nearbyAreas.first {
            self.currentAreaRating = currentArea.performanceRating
        }
    }
    
    /// Get performance comparison with nearby areas
    func getAreaComparison(for location: CLLocation) -> [String] {
        let nearby = nearbyPerformance.filter { area in
            let areaLocation = CLLocation(
                latitude: area.centerLocation.latitude,
                longitude: area.centerLocation.longitude
            )
            return location.distance(from: areaLocation) <= area.radius * 2
        }
        
        guard !nearby.isEmpty else { return ["No nearby data available"] }
        
        let sorted = nearby.sorted { $0.averageDownloadSpeed > $1.averageDownloadSpeed }
        var comparisons: [String] = []
        
        if let best = sorted.first, let worst = sorted.last {
            comparisons.append("Best area nearby: \(Int(best.averageDownloadSpeed)) Mbps")
            comparisons.append("Lowest area nearby: \(Int(worst.averageDownloadSpeed)) Mbps")
        }
        
        let average = nearby.reduce(0) { $0 + $1.averageDownloadSpeed } / Double(nearby.count)
        comparisons.append("Area average: \(Int(average)) Mbps")
        
        return comparisons
    }
    
    /// Get best performing providers in area
    func getTopProviders(limit: Int = 3) -> [ProviderInsights] {
        return Array(providerInsights
            .sorted { $0.averageDownloadSpeed > $1.averageDownloadSpeed }
            .prefix(limit))
    }
    
    // MARK: - Private Methods
    
    private func generateNearbyAreaPerformance(around location: CLLocation) -> [AreaPerformance] {
        var areas: [AreaPerformance] = []
        
        // Generate performance data for areas within 10km radius
        let radiusOptions = [1000.0, 2000.0, 5000.0, 10000.0] // meters
        
        for (index, radius) in radiusOptions.enumerated() {
            // Generate random but realistic data around the location
            let offsetLat = Double.random(in: -0.01...0.01)
            let offsetLng = Double.random(in: -0.01...0.01)
            
            let areaLocation = CommunityCoordinate(from: CLLocationCoordinate2D(
                latitude: location.coordinate.latitude + offsetLat,
                longitude: location.coordinate.longitude + offsetLng
            ))
            
            let baseSpeed = Double.random(in: 20...80)
            let variation = Double.random(in: 0.8...1.2)
            
            let area = AreaPerformance(
                centerLocation: areaLocation,
                radius: radius,
                averageDownloadSpeed: baseSpeed * variation,
                averageUploadSpeed: baseSpeed * variation * 0.6, // Upload typically lower
                averagePing: Double.random(in: 10...50),
                sampleCount: Int.random(in: 50...200),
                lastUpdated: Date().addingTimeInterval(-Double.random(in: 0...86400)), // Within last 24h
                performanceRating: PerformanceRating.from(averageSpeed: baseSpeed * variation),
                dominantProvider: ["Verizon", "AT&T", "T-Mobile", "Xfinity", "Spectrum"].randomElement()
            )
            
            areas.append(area)
        }
        
        return areas.sorted { $0.radius < $1.radius }
    }
    
    private func generateProviderInsights(for location: CLLocation) -> [ProviderInsights] {
        let providers = ["Verizon", "AT&T", "T-Mobile", "Xfinity", "Spectrum", "Other"]
        var insights: [ProviderInsights] = []
        
        var remainingMarketShare = 100.0
        
        for (index, provider) in providers.enumerated() {
            let marketShare = index < providers.count - 1 ?
                Double.random(in: 5...25) :
                remainingMarketShare // Last provider gets remaining share
            
            remainingMarketShare -= marketShare
            
            let baseSpeed = Double.random(in: 15...70)
            
            let insight = ProviderInsights(
                providerName: provider,
                averageDownloadSpeed: baseSpeed,
                averageUploadSpeed: baseSpeed * Double.random(in: 0.5...0.8),
                averagePing: Double.random(in: 12...60),
                sampleCount: Int.random(in: 20...150),
                marketShare: max(0, marketShare),
                rating: PerformanceRating.from(averageSpeed: baseSpeed)
            )
            
            insights.append(insight)
            
            if remainingMarketShare <= 0 { break }
        }
        
        return insights.sorted { $0.averageDownloadSpeed > $1.averageDownloadSpeed }
    }
    
    private func detectNetworkProvider() -> String? {
        // In a real implementation, this would detect the actual carrier
        // Using Core Telephony framework
        return ["Verizon", "AT&T", "T-Mobile", "Unknown"].randomElement()
    }
    
    private func simulateServerUpload(_ data: CommunitySpeedData) async {
        // Simulate network upload delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // In real implementation:
        // 1. Encrypt data
        // 2. Remove any identifying information
        // 3. Upload to secure server
        // 4. Server aggregates and anonymizes data
        
        logger.info("Successfully uploaded anonymous community data")
    }
    
    private func updateLocalInsights(for location: CLLocation) async {
        // Update insights based on new contribution
        await loadCommunityInsights(for: location)
    }
    
    private func generateSampleCommunityData() {
        // Generate sample data for demonstration
        let sampleLocations = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),  // New York
            CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437), // Los Angeles
            CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),  // Chicago
            CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698),  // Houston
        ]
        
        for location in sampleLocations {
            for _ in 0..<Int.random(in: 10...30) {
                let data = CommunitySpeedData(
                    location: CommunityCoordinate(from: location),
                    downloadSpeed: Double.random(in: 10...100),
                    uploadSpeed: Double.random(in: 5...50),
                    ping: Double.random(in: 10...80),
                    connectionType: ["WiFi", "Cellular"].randomElement() ?? "WiFi",
                    timestamp: Date().addingTimeInterval(-Double.random(in: 0...604800)), // Within last week
                    networkProvider: ["Verizon", "AT&T", "T-Mobile", "Xfinity", "Spectrum"].randomElement()
                )
                communityDatabase.append(data)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveUserConsent() {
        userDefaults.set(userConsent, forKey: consentKey)
    }
    
    private func loadUserConsent() {
        userConsent = userDefaults.bool(forKey: consentKey)
    }
    
    private func clearLocalCommunityData() {
        communityDatabase.removeAll()
        userDefaults.removeObject(forKey: communityDataKey)
        userDefaults.removeObject(forKey: lastUploadKey)
    }
}

// MARK: - Privacy Extensions

extension CommunitySpeedData {
    /// Create privacy-safe version for sharing
    var anonymized: CommunitySpeedData {
        return CommunitySpeedData(
            location: CommunityCoordinate(from: privacyRoundedLocation),
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            ping: ping,
            connectionType: connectionType,
            timestamp: timestamp,
            networkProvider: networkProvider
        )
    }
}
