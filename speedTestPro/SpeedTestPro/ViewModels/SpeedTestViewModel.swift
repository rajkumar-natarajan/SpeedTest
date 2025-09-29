//
//  SpeedTestViewModel.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI
import Network
import Combine

/// Test phases during speed test execution
enum TestPhase: String, CaseIterable {
    case idle = "Ready"
    case connecting = "Connecting"
    case ping = "Testing Ping"
    case download = "Testing Download"
    case upload = "Testing Upload"
    case complete = "Complete"
}

/// Network connection types
enum ConnectionType {
    case wifi
    case cellular
    case unavailable
}

/// Connection quality categories based on speed thresholds
enum ConnectionQuality: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    /// Determine quality based on download speed
    static func from(downloadSpeed: Double) -> ConnectionQuality {
        switch downloadSpeed {
        case 50...:
            return .excellent
        case 25..<50:
            return .good
        case 10..<25:
            return .fair
        default:
            return .poor
        }
    }
}

/// Speed test result model
struct SpeedTestResult: Codable, Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let downloadSpeed: Double // Mbps
    let uploadSpeed: Double // Mbps
    let ping: Double // milliseconds
    let jitter: Double // milliseconds
    let connectionQuality: ConnectionQuality
    let connectionType: String
    let serverLocation: String
    
    /// Initialize with default values
    init(downloadSpeed: Double = 0, uploadSpeed: Double = 0, ping: Double = 0, jitter: Double = 0, connectionType: String = "Unknown", serverLocation: String = "Unknown") {
        self.timestamp = Date()
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.ping = ping
        self.jitter = jitter
        self.connectionQuality = ConnectionQuality.from(downloadSpeed: downloadSpeed)
        self.connectionType = connectionType
        self.serverLocation = serverLocation
    }
    
    static func == (lhs: SpeedTestResult, rhs: SpeedTestResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// Main ViewModel for speed test functionality
@MainActor
class SpeedTestViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isTestingInProgress = false
    @Published var currentTestPhase: TestPhase = .idle
    @Published var testProgress: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    @Published var connectionType: ConnectionType = .unavailable
    @Published var latestResult: SpeedTestResult?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let speedTestManager = SpeedTestManager()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private var testTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {
        startNetworkMonitoring()
        setupSpeedTestManager()
    }
    
    deinit {
        networkMonitor.cancel()
        testTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start the speed test process
    func startSpeedTest() async {
        guard !isTestingInProgress else { return }
        
        // Check network connectivity
        guard connectionType != .unavailable else {
            errorMessage = "No internet connection available"
            return
        }
        
        // Reset state
        resetTestState()
        
        // Start testing process
        testTask = Task {
            await performSpeedTest()
        }
    }
    
    /// Cancel the current speed test
    func cancelTest() {
        testTask?.cancel()
        speedTestManager.cancelTest()
        resetTestState()
    }
    
    // MARK: - Private Methods
    
    /// Reset test state to initial values
    private func resetTestState() {
        isTestingInProgress = false
        currentTestPhase = .idle
        testProgress = 0.0
        currentSpeed = 0.0
        errorMessage = nil
    }
    
    /// Setup speed test manager with callbacks
    private func setupSpeedTestManager() {
        speedTestManager.onProgressUpdate = { [weak self] phase, progress, speed in
            Task { @MainActor in
                self?.currentTestPhase = phase
                self?.testProgress = progress
                self?.currentSpeed = speed
            }
        }
    }
    
    /// Perform the complete speed test
    private func performSpeedTest() async {
        isTestingInProgress = true
        currentTestPhase = .connecting
        
        do {
            // Test ping latency
            currentTestPhase = .ping
            testProgress = 0.2
            let pingResult = try await speedTestManager.testPing()
            
            // Test download speed
            currentTestPhase = .download
            testProgress = 0.4
            let downloadResult = try await speedTestManager.testDownloadSpeed()
            
            // Test upload speed
            currentTestPhase = .upload
            testProgress = 0.8
            let uploadResult = try await speedTestManager.testUploadSpeed()
            
            // Complete test
            currentTestPhase = .complete
            testProgress = 1.0
            
            // Create result
            let result = SpeedTestResult(
                downloadSpeed: downloadResult.speed,
                uploadSpeed: uploadResult.speed,
                ping: pingResult.ping,
                jitter: pingResult.jitter,
                connectionType: connectionTypeString,
                serverLocation: downloadResult.serverLocation
            )
            
            // Save result
            TestHistory.shared.addResult(result)
            latestResult = result
            
            // Delay before resetting state
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            resetTestState()
            
        } catch {
            errorMessage = error.localizedDescription
            resetTestState()
        }
    }
    
    /// Start monitoring network connectivity
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionType(from: path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Update connection type based on network path
    private func updateConnectionType(from path: NWPath) {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else {
                connectionType = .wifi // Default for other connection types
            }
        } else {
            connectionType = .unavailable
        }
    }
    
    /// Get connection type as string
    private var connectionTypeString: String {
        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .unavailable:
            return "Unavailable"
        }
    }
}
