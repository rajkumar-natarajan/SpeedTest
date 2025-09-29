//
//  AppSettings.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import SwiftUI
import UserNotifications
import os.log

/// Speed unit options for display
enum SpeedUnit: String, CaseIterable {
    case mbps = "Mbps"
    case kbps = "Kbps"
    case mbytes = "MB/s"
    
    /// Convert Mbps to the selected unit
    func convert(from mbps: Double) -> Double {
        switch self {
        case .mbps:
            return mbps
        case .kbps:
            return mbps * 1000
        case .mbytes:
            return mbps / 8
        }
    }
}

/// App settings manager using UserDefaults with SwiftUI integration
class AppSettings: ObservableObject {
    private let logger = Logger(subsystem: "SpeedTestPro", category: "AppSettings")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Settings Keys
    private enum Keys: String {
        case isDarkMode = "isDarkMode"
        case speedUnit = "speedUnit"
        case useLocationForServer = "useLocationForServer"
        case autoTestOnLaunch = "autoTestOnLaunch"
        case lowSpeedNotifications = "lowSpeedNotifications"
        case lowSpeedThreshold = "lowSpeedThreshold"
        case notificationsEnabled = "notificationsEnabled"
        case firstLaunch = "firstLaunch"
        case lastNotificationPermissionRequest = "lastNotificationPermissionRequest"
    }
    
    // MARK: - Published Properties
    
    /// Dark mode toggle
    @Published var isDarkMode: Bool {
        didSet {
            userDefaults.set(isDarkMode, forKey: Keys.isDarkMode.rawValue)
            logger.debug("Dark mode set to: \(self.isDarkMode)")
        }
    }
    
    /// Speed unit preference
    @Published var speedUnit: SpeedUnit {
        didSet {
            userDefaults.set(speedUnit.rawValue, forKey: Keys.speedUnit.rawValue)
            logger.debug("Speed unit set to: \(self.speedUnit.rawValue)")
        }
    }
    
    /// Use location for server selection
    @Published var useLocationForServer: Bool {
        didSet {
            userDefaults.set(useLocationForServer, forKey: Keys.useLocationForServer.rawValue)
            logger.debug("Use location for server set to: \(self.useLocationForServer)")
        }
    }
    
    /// Auto-test on app launch
    @Published var autoTestOnLaunch: Bool {
        didSet {
            userDefaults.set(autoTestOnLaunch, forKey: Keys.autoTestOnLaunch.rawValue)
            logger.debug("Auto-test on launch set to: \(self.autoTestOnLaunch)")
        }
    }
    
    /// Enable low speed notifications
    @Published var lowSpeedNotifications: Bool {
        didSet {
            userDefaults.set(lowSpeedNotifications, forKey: Keys.lowSpeedNotifications.rawValue)
            logger.debug("Low speed notifications set to: \(self.lowSpeedNotifications)")
            
            if lowSpeedNotifications && !notificationsEnabled {
                requestNotificationPermissions()
            }
        }
    }
    
    /// Threshold for low speed notifications (in Mbps)
    @Published var lowSpeedThreshold: Double {
        didSet {
            userDefaults.set(lowSpeedThreshold, forKey: Keys.lowSpeedThreshold.rawValue)
            logger.debug("Low speed threshold set to: \(self.lowSpeedThreshold) Mbps")
        }
    }
    
    /// Whether notifications are enabled system-wide
    @Published var notificationsEnabled: Bool {
        didSet {
            userDefaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled.rawValue)
        }
    }
    
    // MARK: - Non-Published Properties
    
    /// First launch flag
    var isFirstLaunch: Bool {
        get {
            return userDefaults.bool(forKey: Keys.firstLaunch.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.firstLaunch.rawValue)
        }
    }
    
    /// Last notification permission request date
    var lastNotificationPermissionRequest: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastNotificationPermissionRequest.rawValue) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastNotificationPermissionRequest.rawValue)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Load saved settings or use defaults
        self.isDarkMode = userDefaults.object(forKey: Keys.isDarkMode.rawValue) as? Bool ?? false
        
        let speedUnitString = userDefaults.string(forKey: Keys.speedUnit.rawValue) ?? SpeedUnit.mbps.rawValue
        self.speedUnit = SpeedUnit(rawValue: speedUnitString) ?? .mbps
        
        self.useLocationForServer = userDefaults.object(forKey: Keys.useLocationForServer.rawValue) as? Bool ?? true
        self.autoTestOnLaunch = userDefaults.object(forKey: Keys.autoTestOnLaunch.rawValue) as? Bool ?? false
        self.lowSpeedNotifications = userDefaults.object(forKey: Keys.lowSpeedNotifications.rawValue) as? Bool ?? false
        self.lowSpeedThreshold = userDefaults.object(forKey: Keys.lowSpeedThreshold.rawValue) as? Double ?? 5.0
        self.notificationsEnabled = userDefaults.object(forKey: Keys.notificationsEnabled.rawValue) as? Bool ?? false
        
        // Set first launch flag if not set
        if !userDefaults.bool(forKey: Keys.firstLaunch.rawValue) {
            isFirstLaunch = true
            logger.info("First launch detected")
        }
        
        logger.info("App settings initialized")
        checkNotificationPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = false
        speedUnit = .mbps
        useLocationForServer = true
        autoTestOnLaunch = false
        lowSpeedNotifications = false
        lowSpeedThreshold = 5.0
        notificationsEnabled = false
        
        // Clear UserDefaults
        for key in [Keys.isDarkMode, Keys.speedUnit, Keys.useLocationForServer,
                   Keys.autoTestOnLaunch, Keys.lowSpeedNotifications,
                   Keys.lowSpeedThreshold, Keys.notificationsEnabled] {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        
        logger.info("Settings reset to defaults")
    }
    
    /// Request notification permissions from the user
    func requestNotificationPermissions() {
        // Don't request too frequently
        if let lastRequest = lastNotificationPermissionRequest,
           Date().timeIntervalSince(lastRequest) < 24 * 60 * 60 { // 24 hours
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                self?.lastNotificationPermissionRequest = Date()
                
                if let error = error {
                    self?.logger.error("Notification permission request failed: \(error.localizedDescription)")
                } else {
                    self?.logger.info("Notification permission granted: \(granted)")
                }
            }
        }
    }
    
    /// Check current notification permission status
    func checkNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Send a low speed notification
    func sendLowSpeedNotification(speed: Double, threshold: Double) {
        guard lowSpeedNotifications && notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Slow Internet Detected"
        content.body = "Your internet speed (\(String(format: "%.1f", speed)) Mbps) is below your threshold of \(String(format: "%.1f", threshold)) Mbps."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "lowSpeed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send low speed notification: \(error.localizedDescription)")
            } else {
                self?.logger.info("Low speed notification sent")
            }
        }
    }
    
    /// Get formatted speed value according to current unit
    func formattedSpeed(_ mbps: Double) -> String {
        let convertedSpeed = speedUnit.convert(from: mbps)
        
        switch speedUnit {
        case .mbps:
            return String(format: "%.1f %@", convertedSpeed, speedUnit.rawValue)
        case .kbps:
            return String(format: "%.0f %@", convertedSpeed, speedUnit.rawValue)
        case .mbytes:
            return String(format: "%.2f %@", convertedSpeed, speedUnit.rawValue)
        }
    }
    
    /// Get app color scheme based on dark mode setting
    var colorScheme: ColorScheme? {
        return isDarkMode ? .dark : .light
    }
    
    /// Export settings as dictionary for backup/restore
    func exportSettings() -> [String: Any] {
        return [
            Keys.isDarkMode.rawValue: isDarkMode,
            Keys.speedUnit.rawValue: speedUnit.rawValue,
            Keys.useLocationForServer.rawValue: useLocationForServer,
            Keys.autoTestOnLaunch.rawValue: autoTestOnLaunch,
            Keys.lowSpeedNotifications.rawValue: lowSpeedNotifications,
            Keys.lowSpeedThreshold.rawValue: lowSpeedThreshold
        ]
    }
    
    /// Import settings from dictionary for backup/restore
    func importSettings(_ settings: [String: Any]) {
        if let darkMode = settings[Keys.isDarkMode.rawValue] as? Bool {
            isDarkMode = darkMode
        }
        
        if let unit = settings[Keys.speedUnit.rawValue] as? String,
           let speedUnitEnum = SpeedUnit(rawValue: unit) {
            speedUnit = speedUnitEnum
        }
        
        if let location = settings[Keys.useLocationForServer.rawValue] as? Bool {
            useLocationForServer = location
        }
        
        if let autoTest = settings[Keys.autoTestOnLaunch.rawValue] as? Bool {
            autoTestOnLaunch = autoTest
        }
        
        if let notifications = settings[Keys.lowSpeedNotifications.rawValue] as? Bool {
            lowSpeedNotifications = notifications
        }
        
        if let threshold = settings[Keys.lowSpeedThreshold.rawValue] as? Double {
            lowSpeedThreshold = threshold
        }
        
        logger.info("Settings imported successfully")
    }
}
