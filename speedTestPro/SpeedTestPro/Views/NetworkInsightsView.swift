//
//  NetworkInsightsView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI
import MapKit
import CoreLocation

/// Network insights and community mapping view
struct NetworkInsightsView: View {
    @StateObject private var analyticsService = NetworkAnalyticsService()
    @StateObject private var communityService = CommunityMappingService()
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedTab = 0
    @State private var showingConsentDialog = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Insights Type", selection: $selectedTab) {
                    Text("AI Insights").tag(0)
                    Text("Community").tag(1)
                    Text("Devices").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    // AI Insights Tab
                    AIInsightsTab(analyticsService: analyticsService)
                        .tag(0)
                    
                    // Community Mapping Tab
                    CommunityMappingTab(
                        communityService: communityService,
                        locationManager: locationManager,
                        showingConsentDialog: $showingConsentDialog
                    )
                    .tag(1)
                    
                    // Connected Devices Tab
                    ConnectedDevicesView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Network Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadInsights()
            }
            .sheet(isPresented: $showingConsentDialog) {
                CommunityConsentView(communityService: communityService)
            }
        }
    }
    
    private func loadInsights() {
        Task {
            let history = TestHistory.shared.getAllResults()
            await analyticsService.generatePredictions(from: history)
            analyticsService.detectAnomalies(from: history)
            
            if let location = locationManager.location {
                await communityService.loadCommunityInsights(for: location)
            }
        }
    }
}

// MARK: - AI Insights Tab

struct AIInsightsTab: View {
    @ObservedObject var analyticsService: NetworkAnalyticsService
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Predictions Section
                if !analyticsService.predictions.isEmpty {
                    PredictionsSection(predictions: analyticsService.predictions)
                }
                
                // Anomalies Section
                if !analyticsService.detectedAnomalies.isEmpty {
                    AnomaliesSection(anomalies: analyticsService.detectedAnomalies)
                }
                
                // Performance Insights Section
                if !analyticsService.performanceInsights.isEmpty {
                    Section("Performance Insights") {
                        ForEach(analyticsService.performanceInsights, id: \.self) { insight in
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text(insight)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Loading State
                if analyticsService.isAnalyzing {
                    AnalyzingView()
                }
                
                // Empty State
                if analyticsService.predictions.isEmpty && !analyticsService.isAnalyzing {
                    EmptyInsightsView()
                }
            }
            .padding()
        }
    }
}

// MARK: - Community Mapping Tab

struct CommunityMappingTab: View {
    @ObservedObject var communityService: CommunityMappingService
    @ObservedObject var locationManager: LocationManager
    @Binding var showingConsentDialog: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Consent Status
                ConsentStatusCard(
                    isConsented: communityService.userConsent,
                    onToggleConsent: {
                        if communityService.userConsent {
                            communityService.revokeCommunityParticipation()
                        } else {
                            showingConsentDialog = true
                        }
                    }
                )
                
                if communityService.userConsent {
                    // Current Area Performance
                    CurrentAreaCard(
                        rating: communityService.currentAreaRating,
                        isLoading: communityService.isLoadingCommunityData
                    )
                    
                    // Nearby Areas Performance
                    if !communityService.nearbyPerformance.isEmpty {
                        NearbyAreasSection(areas: communityService.nearbyPerformance)
                    }
                    
                    // Provider Insights
                    if !communityService.providerInsights.isEmpty {
                        ProvidersSection(providers: communityService.providerInsights)
                    }
                    
                    // Area Comparison
                    if let location = locationManager.location {
                        AreaComparisonSection(
                            comparisons: communityService.getAreaComparison(for: location)
                        )
                    }
                } else {
                    // Encourage Participation
                    CommunityBenefitsView(onJoin: { showingConsentDialog = true })
                }
            }
            .padding()
        }
    }
}

// MARK: - Predictions Section

struct PredictionsSection: View {
    let predictions: [NetworkPrediction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI Predictions", icon: "brain.head.profile")
            
            ForEach(predictions, id: \.timeframe) { prediction in
                PredictionCard(prediction: prediction)
            }
        }
    }
}

struct PredictionCard: View {
    let prediction: NetworkPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prediction.timeframe.capitalized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ConfidenceBadge(confidence: prediction.confidence)
            }
            
            HStack(spacing: 20) {
                MetricPreview(
                    title: "Download",
                    value: "\(Int(prediction.expectedDownloadSpeed)) Mbps",
                    color: .blue
                )
                
                MetricPreview(
                    title: "Upload", 
                    value: "\(Int(prediction.expectedUploadSpeed)) Mbps",
                    color: .green
                )
                
                MetricPreview(
                    title: "Ping",
                    value: "\(Int(prediction.expectedPing)) ms",
                    color: .orange
                )
            }
            
            QualityIndicator(quality: prediction.predictedQuality)
            
            if !prediction.factors.isEmpty {
                FactorsView(factors: prediction.factors)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Anomalies Section

struct AnomaliesSection: View {
    let anomalies: [NetworkAnomaly]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Detected Issues", icon: "exclamationmark.triangle.fill")
            
            ForEach(anomalies, id: \.id) { anomaly in
                AnomalyCard(anomaly: anomaly)
            }
        }
    }
}

struct AnomalyCard: View {
    let anomaly: NetworkAnomaly
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(anomaly.severity.color))
                
                Text(anomaly.type.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(anomaly.severity.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(anomaly.severity.color).opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text(anomaly.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let action = anomaly.suggestedAction {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(action)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Community Sections

struct ConsentStatusCard: View {
    let isConsented: Bool
    let onToggleConsent: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Community Participation")
                    .font(.headline)
                
                Text(isConsented ? "Contributing anonymously" : "Not participating")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onToggleConsent) {
                Text(isConsented ? "Leave" : "Join")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isConsented ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CurrentAreaCard: View {
    let rating: PerformanceRating
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading area data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("Your Area Performance")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(rating.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(rating.color).opacity(0.2))
                        .cornerRadius(8)
                }
                
                Circle()
                    .fill(Color(rating.color))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(rating.rawValue.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

struct MetricPreview: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(Int(confidence * 100))% confident")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
    }
}

struct QualityIndicator: View {
    let quality: ConnectionQuality
    
    var body: some View {
        HStack {
            Text("Predicted Quality:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(quality.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(quality.color))
        }
    }
}

struct FactorsView: View {
    let factors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contributing Factors:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(factors, id: \.self) { factor in
                HStack {
                    Image(systemName: "dot.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text(factor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Empty and Loading States

struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing Network Patterns...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Our AI is examining your test history to generate insights")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("No Insights Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Run a few speed tests to get AI-powered insights about your network")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CommunityBenefitsView: View {
    let onJoin: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Join the Community")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(text: "See how your area performs")
                BenefitRow(text: "Compare ISP providers nearby")
                BenefitRow(text: "Help others with anonymous data")
                BenefitRow(text: "100% privacy protected")
            }
            
            Button(action: onJoin) {
                Text("Learn More & Join")
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BenefitRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Additional Sections (Simplified for space)

struct NearbyAreasSection: View {
    let areas: [AreaPerformance]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Nearby Areas", icon: "map")
            
            ForEach(areas.prefix(3), id: \.radius) { area in
                HStack {
                    VStack(alignment: .leading) {
                        Text("Within \(Int(area.radius/1000))km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(area.averageDownloadSpeed)) Mbps avg")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Text(area.performanceRating.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(area.performanceRating.color).opacity(0.2))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct ProvidersSection: View {
    let providers: [ProviderInsights]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ISP Performance", icon: "antenna.radiowaves.left.and.right")
            
            ForEach(providers.prefix(3), id: \.providerName) { provider in
                HStack {
                    VStack(alignment: .leading) {
                        Text(provider.providerName)
                            .font(.headline)
                        
                        Text("\(Int(provider.averageDownloadSpeed)) Mbps • \(Int(provider.marketShare))% share")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(provider.rating.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(provider.rating.color).opacity(0.2))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct AreaComparisonSection: View {
    let comparisons: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Area Comparison", icon: "chart.bar")
            
            ForEach(comparisons, id: \.self) { comparison in
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text(comparison)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension AnomalyType {
    var displayName: String {
        switch self {
        case .speedDegradation: return "Speed Degradation"
        case .latencySpike: return "Latency Spike"
        case .packetLoss: return "Packet Loss"
        case .inconsistentPerformance: return "Inconsistent Performance"
        case .unusualPattern: return "Unusual Pattern"
        }
    }
}

extension ConnectionQuality {
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

#if DEBUG
struct NetworkInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkInsightsView()
    }
}
#endif
