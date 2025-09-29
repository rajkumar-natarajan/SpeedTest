//
//  ConnectedDevice.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import Network

/// Represents a device connected to the local network
struct ConnectedDevice: Identifiable, Equatable, Codable {
    let id = UUID()
    let ipAddress: String
    let macAddress: String?
    let hostname: String?
    let deviceType: DeviceType
    let manufacturer: String?
    let isCurrentDevice: Bool
    let lastSeen: Date
    let responseTime: TimeInterval?
    
    /// Estimated device type based on network characteristics
    enum DeviceType: String, CaseIterable, Codable {
        case router = "Router"
        case smartphone = "Smartphone"
        case tablet = "Tablet"
        case laptop = "Laptop"
        case desktop = "Desktop"
        case smartTV = "Smart TV"
        case gameConsole = "Game Console"
        case iotDevice = "IoT Device"
        case printer = "Printer"
        case speaker = "Smart Speaker"
        case unknown = "Unknown"
        
        var iconName: String {
            switch self {
            case .router: return "wifi.router"
            case .smartphone: return "iphone"
            case .tablet: return "ipad"
            case .laptop: return "laptopcomputer"
            case .desktop: return "desktopcomputer"
            case .smartTV: return "tv"
            case .gameConsole: return "gamecontroller"
            case .iotDevice: return "sensor"
            case .printer: return "printer"
            case .speaker: return "homepod"
            case .unknown: return "questionmark.circle"
            }
        }
        
        var color: String {
            switch self {
            case .router: return "blue"
            case .smartphone, .tablet: return "green"
            case .laptop, .desktop: return "purple"
            case .smartTV: return "orange"
            case .gameConsole: return "red"
            case .iotDevice: return "gray"
            case .printer: return "brown"
            case .speaker: return "pink"
            case .unknown: return "gray"
            }
        }
    }
}

/// Network scan result containing all discovered devices
struct NetworkScanResult: Codable {
    let scanDate: Date
    let networkName: String?
    let networkSSID: String?
    let routerIP: String?
    let subnet: String
    let connectedDevices: [ConnectedDevice]
    let scanDuration: TimeInterval
    
    var deviceCount: Int {
        connectedDevices.count
    }
    
    var devicesByType: [ConnectedDevice.DeviceType: [ConnectedDevice]] {
        Dictionary(grouping: connectedDevices, by: { $0.deviceType })
    }
}
