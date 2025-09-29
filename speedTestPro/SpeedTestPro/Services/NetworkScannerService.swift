//
//  NetworkScannerService.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import Foundation
import Network
import SystemConfiguration
import UIKit
import os.log
import Darwin

/// Service for scanning and discovering devices on the local network
@MainActor
class NetworkScannerService: ObservableObject {
    @Published var isScanning = false
    @Published var lastScanResult: NetworkScanResult?
    @Published var scanProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "SpeedTestPro", category: "NetworkScanner")
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "LastNetworkScan"
    
    // Network scanning parameters
    private let scanTimeout: TimeInterval = 1.0 // Reduced from 2.0
    private let maxConcurrentScans = 20 // Reduced from 50
    
    init() {
        loadCachedScanResult()
    }
    
    // MARK: - Public Methods
    
    /// Test method to generate sample devices for demonstration
    func generateSampleDevices() {
        let sampleDevices = [
            ConnectedDevice(
                ipAddress: "192.168.1.1",
                macAddress: nil,
                hostname: "TP-Link Router",
                deviceType: .router,
                manufacturer: "TP-Link",
                isCurrentDevice: false,
                lastSeen: Date(),
                responseTime: 0.003
            ),
            ConnectedDevice(
                ipAddress: "192.168.1.25",
                macAddress: nil,
                hostname: "MacBook Pro",
                deviceType: .laptop,
                manufacturer: "Apple",
                isCurrentDevice: false,
                lastSeen: Date(),
                responseTime: 0.012
            ),
            ConnectedDevice(
                ipAddress: "192.168.1.105",
                macAddress: nil,
                hostname: "iPhone 15",
                deviceType: .smartphone,
                manufacturer: "Apple",
                isCurrentDevice: true,
                lastSeen: Date(),
                responseTime: 0.008
            ),
            ConnectedDevice(
                ipAddress: "192.168.1.180",
                macAddress: nil,
                hostname: "Samsung Smart TV",
                deviceType: .smartTV,
                manufacturer: "Samsung",
                isCurrentDevice: false,
                lastSeen: Date(),
                responseTime: 0.045
            ),
            ConnectedDevice(
                ipAddress: "192.168.1.210",
                macAddress: nil,
                hostname: "HP Printer",
                deviceType: .printer,
                manufacturer: "HP",
                isCurrentDevice: false,
                lastSeen: Date(),
                responseTime: 0.025
            )
        ]
        
        self.lastScanResult = NetworkScanResult(
            scanDate: Date(),
            scanTime: Date(),
            networkName: "Demo WiFi Network",
            networkSSID: "Demo WiFi",
            routerIP: "192.168.1.1",
            subnet: "192.168.1",
            connectedDevices: sampleDevices,
            scanDuration: 2.5
        )
    }
    
    /// Scan the local network for connected devices
    func scanNetwork() async {
        guard !isScanning else { 
            logger.info("Scan already in progress, ignoring request")
            return 
        }
        
        isScanning = true
        scanProgress = 0.0
        errorMessage = nil
        
        logger.info("Starting network scan...")
        
        do {
            let scanResult = try await performNetworkScan()
            lastScanResult = scanResult
            cacheScanResult(scanResult)
            logger.info("Network scan completed. Found \(scanResult.deviceCount) devices")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Network scan failed: \(error.localizedDescription)")
        }
        
        isScanning = false
        scanProgress = 1.0
    }
    
    /// Get current WiFi network information
    func getCurrentNetworkInfo() -> (ssid: String?, routerIP: String?) {
        var ssid: String?
        var routerIP: String?
        
        // Get WiFi SSID (requires entitlements in real app)
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject] {
                    ssid = info[kCNNetworkInfoKeySSID as String] as? String
                }
            }
        }
        
        // Get router IP (gateway)
        routerIP = getGatewayIP()
        
        return (ssid, routerIP)
    }
    
    // MARK: - Private Methods
    
    private func performNetworkScan() async throws -> NetworkScanResult {
        let startTime = Date()
        let networkInfo = getCurrentNetworkInfo()
        
        // Get local IP and subnet
        guard let localIP = getLocalIPAddress(),
              let subnet = getSubnetFromIP(localIP) else {
            throw NetworkScanError.noLocalNetwork
        }
        
        logger.info("Scanning subnet: \(subnet)")
        
        // Generate IP addresses to scan
        let ipAddresses = generateIPAddresses(for: subnet)
        let totalIPs = ipAddresses.count
        
        var discoveredDevices: [ConnectedDevice] = []
        var scannedCount = 0
        
        // Scan IPs in batches to avoid overwhelming the network
        let batchSize = min(maxConcurrentScans, totalIPs)
        
        for batch in ipAddresses.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: ConnectedDevice?.self) { group in
                var results: [ConnectedDevice] = []
                
                for ip in batch {
                    group.addTask {
                        return await self.scanDevice(at: ip, isCurrentDevice: ip == localIP)
                    }
                }
                
                for await device in group {
                    if let device = device {
                        results.append(device)
                    }
                    scannedCount += 1
                    self.scanProgress = Double(scannedCount) / Double(totalIPs)
                }
                
                return results
            }
            
            discoveredDevices.append(contentsOf: batchResults)
        }
        
        let scanDuration = Date().timeIntervalSince(startTime)
        
        return NetworkScanResult(
            scanDate: Date(),
            scanTime: Date(),
            networkName: networkInfo.ssid ?? "Local Network",
            networkSSID: networkInfo.ssid ?? "Local WiFi",
            routerIP: networkInfo.routerIP ?? "192.168.1.1",
            subnet: subnet,
            connectedDevices: discoveredDevices.sorted { $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending },
            scanDuration: scanDuration
        )
    }
    
    private func scanDevice(at ipAddress: String, isCurrentDevice: Bool) async -> ConnectedDevice? {
        // Try to ping the device
        let responseTime = await pingDevice(at: ipAddress)
        
        guard responseTime != nil else { return nil }
        
        // Try multiple methods to get device name
        let deviceInfo = await getDeviceInfo(for: ipAddress, isCurrentDevice: isCurrentDevice)
        
        return ConnectedDevice(
            ipAddress: ipAddress,
            macAddress: nil, // MAC address requires root privileges
            hostname: deviceInfo.name,
            deviceType: deviceInfo.type,
            manufacturer: deviceInfo.manufacturer,
            isCurrentDevice: isCurrentDevice,
            lastSeen: Date(),
            responseTime: responseTime
        )
    }
    
    private func getDeviceInfo(for ipAddress: String, isCurrentDevice: Bool) async -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        if isCurrentDevice {
            let currentDeviceName = UIDevice.current.name
            logger.info("Current device: \(currentDeviceName)")
            return (
                name: currentDeviceName,
                type: .smartphone,
                manufacturer: "Apple"
            )
        }
        
        logger.info("Resolving device info for IP: \(ipAddress)")
        
        // Try multiple resolution methods
        var deviceName: String?
        var detectedType: ConnectedDevice.DeviceType = .unknown
        var manufacturer: String?
        
        // Method 1: Enhanced device fingerprinting through service detection
        let deviceFingerprint = await detectDeviceByServices(for: ipAddress)
        if deviceFingerprint.type != .unknown {
            detectedType = deviceFingerprint.type
            manufacturer = deviceFingerprint.manufacturer
            deviceName = deviceFingerprint.name
            logger.info("Service fingerprint for \(ipAddress): \(deviceName ?? "nil"), type: \(String(describing: detectedType))")
        }
        
        // Method 2: Try hostname resolution
        if deviceName == nil || deviceName!.isEmpty {
            deviceName = await resolveHostname(for: ipAddress)
            logger.info("Hostname resolution for \(ipAddress): \(deviceName ?? "nil")")
        }
        
        // Method 3: Try Bonjour/mDNS resolution if hostname failed
        if deviceName == nil || deviceName!.isEmpty {
            deviceName = await resolveBonjourName(for: ipAddress)
            logger.info("Bonjour resolution for \(ipAddress): \(deviceName ?? "nil")")
        }
        
        // Method 4: Try enhanced HTTP probing with multiple ports
        if deviceName == nil || deviceName!.isEmpty {
            let httpInfo = await getEnhancedDeviceInfoFromHTTP(for: ipAddress)
            deviceName = httpInfo.name
            if detectedType == .unknown && httpInfo.type != .unknown {
                detectedType = httpInfo.type
                manufacturer = httpInfo.manufacturer
            }
            logger.info("Enhanced HTTP resolution for \(ipAddress): \(deviceName ?? "nil"), type: \(String(describing: detectedType))")
        }
        
        // Estimate device type and manufacturer from the resolved name
        if let name = deviceName, !name.isEmpty {
            let typeAndManufacturer = estimateDeviceTypeAndManufacturer(from: name, ip: ipAddress)
            if detectedType == .unknown {
                detectedType = typeAndManufacturer.type
            }
            if manufacturer == nil {
                manufacturer = typeAndManufacturer.manufacturer
            }
            logger.info("Detected type for \(ipAddress) (\(name)): \(String(describing: detectedType)), manufacturer: \(manufacturer ?? "nil")")
        } else {
            // Generate a smart name based on IP, type and detected services
            if detectedType == .unknown {
                detectedType = estimateDeviceType(ip: ipAddress, hostname: nil, isCurrentDevice: false)
            }
            deviceName = generateSmartDeviceName(for: ipAddress, type: detectedType, manufacturer: manufacturer)
            logger.info("Generated smart name for \(ipAddress): \(deviceName ?? "nil"), type: \(String(describing: detectedType))")
        }
        
        // Ensure we always have a name - final fallback
        if deviceName == nil || deviceName!.isEmpty {
            detectedType = estimateDeviceType(ip: ipAddress, hostname: nil, isCurrentDevice: false)
            deviceName = generateSmartDeviceName(for: ipAddress, type: detectedType, manufacturer: manufacturer)
            logger.info("Final fallback name for \(ipAddress): \(deviceName ?? "nil"), type: \(String(describing: detectedType))")
        }
        
        // Double-check we have a valid name (should never be nil now)
        let finalName = deviceName ?? generateSmartDeviceName(for: ipAddress, type: detectedType, manufacturer: manufacturer)
        logger.info("Final device info for \(ipAddress): name='\(finalName)', type=\(String(describing: detectedType)), manufacturer=\(manufacturer ?? "nil")")
        
        return (name: finalName, type: detectedType, manufacturer: manufacturer)
    }
    
    private func pingDevice(at ipAddress: String) async -> TimeInterval? {
        let startTime = Date()
        
        // Use async/await URLSession API instead of continuation to avoid misuse
        guard let url = URL(string: "http://\(ipAddress)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = scanTimeout
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            // If we get any response, the device is reachable
            if response is HTTPURLResponse {
                return responseTime
            }
            return nil
        } catch {
            // Check if it's a connection error vs timeout
            if let nsError = error as? NSError {
                // Some errors still indicate the device is reachable (like 404, 403, etc)
                if nsError.code != NSURLErrorCannotConnectToHost && 
                   nsError.code != NSURLErrorTimedOut &&
                   nsError.code != NSURLErrorNetworkConnectionLost {
                    let responseTime = Date().timeIntervalSince(startTime)
                    return responseTime
                }
            }
            return nil
        }
    }
    
    private func resolveHostname(for ipAddress: String) async -> String? {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(ipAddress, nil, &hints, &result)
                
                defer {
                    if let result = result {
                        freeaddrinfo(result)
                    }
                }
                
                if status == 0, let result = result {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let status = getnameinfo(result.pointee.ai_addr, result.pointee.ai_addrlen,
                                           &hostname, socklen_t(hostname.count),
                                           nil, 0, NI_NAMEREQD)
                    
                    if status == 0 {
                        let name = String(cString: hostname)
                        continuation.resume(returning: name.isEmpty ? nil : name)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func resolveBonjourName(for ipAddress: String) async -> String? {
        // Try to resolve using Bonjour/mDNS
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                // Simplified Bonjour resolution - in a real implementation,
                // you might use Network.framework or DNSServiceRef
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func resolveNetBIOSName(for ipAddress: String) async -> String? {
        // Try NetBIOS name resolution (for Windows devices)
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                // This would require more complex implementation
                // For now, return nil as NetBIOS is less common on modern networks
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func getDeviceInfoFromHTTP(for ipAddress: String) async -> (name: String?, type: ConnectedDevice.DeviceType) {
        // Try to get device information from HTTP responses
        guard let url = URL(string: "http://\(ipAddress)") else {
            return (nil, .unknown)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.setValue("SpeedTestPro/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            var deviceName: String?
            var deviceType: ConnectedDevice.DeviceType = .unknown
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check for device-specific headers
                if let server = httpResponse.allHeaderFields["Server"] as? String {
                    deviceName = extractDeviceNameFromServer(server)
                    deviceType = extractDeviceTypeFromServer(server)
                }
                
                // Check for other identifying headers
                if deviceName == nil {
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyStr = key as? String,
                           let valueStr = value as? String {
                            if keyStr.lowercased().contains("device") ||
                               keyStr.lowercased().contains("model") ||
                               keyStr.lowercased().contains("product") {
                                deviceName = valueStr
                                break
                            }
                        }
                    }
                }
            }
            
            // Try to extract device info from HTML content
            if deviceName == nil, let html = String(data: data, encoding: .utf8) {
                deviceName = extractDeviceNameFromHTML(html)
                if deviceType == .unknown {
                    deviceType = extractDeviceTypeFromHTML(html)
                }
            }
            
            return (deviceName, deviceType)
        } catch {
            return (nil, .unknown)
        }
    }
    
    private func estimateDeviceTypeAndManufacturer(from name: String, ip: String) -> (type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let lowercaseName = name.lowercased()
        
        // Device type estimation based on hostname patterns
        var deviceType: ConnectedDevice.DeviceType = .unknown
        var manufacturer: String?
        
        if lowercaseName.contains("router") || lowercaseName.contains("gateway") || lowercaseName.contains("modem") {
            deviceType = .router
        } else if lowercaseName.contains("iphone") {
            deviceType = .smartphone
            manufacturer = "Apple"
        } else if lowercaseName.contains("android") || lowercaseName.contains("mobile") {
            deviceType = .smartphone
        } else if lowercaseName.contains("ipad") {
            deviceType = .tablet
            manufacturer = "Apple"
        } else if lowercaseName.contains("tablet") {
            deviceType = .tablet
        } else if lowercaseName.contains("macbook") {
            deviceType = .laptop
            manufacturer = "Apple"
        } else if lowercaseName.contains("laptop") {
            deviceType = .laptop
        } else if lowercaseName.contains("imac") {
            deviceType = .desktop
            manufacturer = "Apple"
        } else if lowercaseName.contains("desktop") || lowercaseName.contains("pc") {
            deviceType = .desktop
        } else if lowercaseName.contains("tv") || lowercaseName.contains("roku") || lowercaseName.contains("chromecast") {
            deviceType = .smartTV
        } else if lowercaseName.contains("xbox") {
            deviceType = .gameConsole
            manufacturer = "Microsoft"
        } else if lowercaseName.contains("playstation") {
            deviceType = .gameConsole
            manufacturer = "Sony"
        } else if lowercaseName.contains("nintendo") {
            deviceType = .gameConsole
            manufacturer = "Nintendo"
        } else if lowercaseName.contains("printer") || lowercaseName.contains("canon") || lowercaseName.contains("hp") || lowercaseName.contains("epson") {
            deviceType = .printer
        } else if lowercaseName.contains("echo") || lowercaseName.contains("homepod") || lowercaseName.contains("speaker") {
            deviceType = .speaker
        } else if lowercaseName.contains("thermostat") || lowercaseName.contains("camera") || lowercaseName.contains("sensor") {
            deviceType = .iotDevice
        }
        
        // Try to extract manufacturer if not already set
        if manufacturer == nil {
            manufacturer = extractManufacturer(from: lowercaseName)
        }
        
        // If still unknown, try to guess from IP patterns
        if deviceType == .unknown {
            deviceType = estimateDeviceType(ip: ip, hostname: name, isCurrentDevice: false)
        }
        
        return (type: deviceType, manufacturer: manufacturer)
    }
    
    private func extractManufacturer(from name: String) -> String? {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("apple") || lowercaseName.contains("iphone") || lowercaseName.contains("ipad") || lowercaseName.contains("macbook") || lowercaseName.contains("imac") {
            return "Apple"
        } else if lowercaseName.contains("samsung") {
            return "Samsung"
        } else if lowercaseName.contains("google") || lowercaseName.contains("chromecast") {
            return "Google"
        } else if lowercaseName.contains("amazon") || lowercaseName.contains("echo") {
            return "Amazon"
        } else if lowercaseName.contains("microsoft") || lowercaseName.contains("xbox") {
            return "Microsoft"
        } else if lowercaseName.contains("sony") || lowercaseName.contains("playstation") {
            return "Sony"
        } else if lowercaseName.contains("nintendo") {
            return "Nintendo"
        } else if lowercaseName.contains("roku") {
            return "Roku"
        } else if lowercaseName.contains("hp") {
            return "HP"
        } else if lowercaseName.contains("canon") {
            return "Canon"
        } else if lowercaseName.contains("epson") {
            return "Epson"
        }
        
        return nil
    }
    
    nonisolated private func extractDeviceNameFromServer(_ server: String) -> String? {
        let lowercaseServer = server.lowercased()
        
        // Common device identifiers in server headers
        if lowercaseServer.contains("router") {
            return "Router"
        } else if lowercaseServer.contains("printer") {
            return "Network Printer"
        } else if lowercaseServer.contains("camera") {
            return "IP Camera"
        } else if lowercaseServer.contains("nas") {
            return "NAS Device"
        }
        
        return nil
    }
    
    nonisolated private func extractDeviceTypeFromServer(_ server: String) -> ConnectedDevice.DeviceType {
        let lowercaseServer = server.lowercased()
        
        if lowercaseServer.contains("router") {
            return .router
        } else if lowercaseServer.contains("printer") {
            return .printer
        } else if lowercaseServer.contains("camera") {
            return .iotDevice
        } else if lowercaseServer.contains("nas") {
            return .iotDevice
        }
        
        return .unknown
    }
    
    nonisolated private func extractDeviceNameFromHTML(_ html: String) -> String? {
        let lowercaseHTML = html.lowercased()
        
        // Look for common device identification patterns in HTML
        if lowercaseHTML.contains("<title>") {
            let titleRange = lowercaseHTML.range(of: "<title>")
            let endTitleRange = lowercaseHTML.range(of: "</title>")
            
            if let start = titleRange?.upperBound, let end = endTitleRange?.lowerBound {
                let title = String(html[start..<end])
                if !title.isEmpty && title.count < 50 { // Reasonable title length
                    return title
                }
            }
        }
        
        return nil
    }
    
    nonisolated private func extractDeviceTypeFromHTML(_ html: String) -> ConnectedDevice.DeviceType {
        let lowercaseHTML = html.lowercased()
        
        if lowercaseHTML.contains("router") || lowercaseHTML.contains("gateway") {
            return .router
        } else if lowercaseHTML.contains("printer") {
            return .printer
        } else if lowercaseHTML.contains("camera") {
            return .iotDevice
        } else if lowercaseHTML.contains("thermostat") {
            return .iotDevice
        }
        
        return .unknown
    }
    
    // MARK: - Enhanced Device Detection Methods
    
    private func detectDeviceByServices(for ipAddress: String) async -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        var detectedType: ConnectedDevice.DeviceType = .unknown
        var manufacturer: String?
        var deviceName: String?
        
        // Try HTTP first (most common)
        let httpInfo = await getEnhancedDeviceInfoFromHTTP(for: ipAddress)
        if httpInfo.name != nil || httpInfo.type != .unknown {
            return httpInfo
        }
        
        // Basic service detection without socket scanning for now
        // This avoids socket permission issues in iOS simulator
        
        return (name: deviceName, type: detectedType, manufacturer: manufacturer)
    }
    
    private func isPortOpen(ipAddress: String, port: Int) async -> Bool {
        // Simplified port check using URLSession for HTTP ports only
        guard port == 80 || port == 443 || port == 8080 || port == 8443 else {
            return false
        }
        
        let scheme = port == 443 || port == 8443 ? "https" : "http"
        let urlString = port == 80 || port == 443 ? "\(scheme)://\(ipAddress)" : "\(scheme)://\(ipAddress):\(port)"
        
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response != nil
        } catch {
            return false
        }
    }
    
    private func getEnhancedDeviceInfoFromHTTP(for ipAddress: String) async -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        // Try multiple common HTTP ports
        let httpPorts = [80, 8080, 443, 8443, 8000, 8888]
        
        for port in httpPorts {
            let info = await getDeviceInfoFromHTTPPort(for: ipAddress, port: port)
            if info.name != nil || info.type != .unknown {
                return info
            }
        }
        
        return (nil, .unknown, nil)
    }
    
    private func getDeviceInfoFromHTTPPort(for ipAddress: String, port: Int) async -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let scheme = port == 443 || port == 8443 ? "https" : "http"
        let urlString = port == 80 || port == 443 ? "\(scheme)://\(ipAddress)" : "\(scheme)://\(ipAddress):\(port)"
        
        guard let url = URL(string: urlString) else {
            return (nil, .unknown, nil)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.httpMethod = "GET" // Use GET instead of HEAD to get more info
        request.setValue("SpeedTestPro/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            var deviceName: String?
            var deviceType: ConnectedDevice.DeviceType = .unknown
            var manufacturer: String?
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check for device-specific headers
                if let server = httpResponse.allHeaderFields["Server"] as? String {
                    let serverInfo = analyzeServerHeader(server)
                    deviceName = serverInfo.name
                    deviceType = serverInfo.type
                    manufacturer = serverInfo.manufacturer
                }
                
                // Check for router/device-specific headers
                for (key, value) in httpResponse.allHeaderFields {
                    if let keyStr = key as? String, let valueStr = value as? String {
                        let headerInfo = analyzeHTTPHeader(key: keyStr, value: valueStr)
                        if headerInfo.type != .unknown {
                            deviceType = headerInfo.type
                            if deviceName == nil { deviceName = headerInfo.name }
                            if manufacturer == nil { manufacturer = headerInfo.manufacturer }
                        }
                    }
                }
            }
            
            // Analyze HTML content for device info
            if let html = String(data: data, encoding: .utf8) {
                let htmlInfo = analyzeHTMLContent(html)
                if deviceName == nil && htmlInfo.name != nil {
                    deviceName = htmlInfo.name
                }
                if deviceType == .unknown && htmlInfo.type != .unknown {
                    deviceType = htmlInfo.type
                }
                if manufacturer == nil && htmlInfo.manufacturer != nil {
                    manufacturer = htmlInfo.manufacturer
                }
            }
            
            return (deviceName, deviceType, manufacturer)
        } catch {
            return (nil, .unknown, nil)
        }
    }
    
    nonisolated private func analyzeServerHeader(_ server: String) -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let lowercaseServer = server.lowercased()
        
        if lowercaseServer.contains("nginx") || lowercaseServer.contains("apache") {
            return ("Web Server", .desktop, nil)
        } else if lowercaseServer.contains("lighttpd") || lowercaseServer.contains("httpd") {
            return ("Linux Server", .desktop, nil)
        } else if lowercaseServer.contains("router") || lowercaseServer.contains("gateway") {
            return ("Router", .router, nil)
        } else if lowercaseServer.contains("upnp") {
            return ("UPnP Device", .smartTV, nil)
        } else if lowercaseServer.contains("plex") {
            return ("Plex Server", .smartTV, nil)
        } else if lowercaseServer.contains("airplay") {
            return ("Apple TV", .smartTV, "Apple")
        } else if lowercaseServer.contains("iot") || lowercaseServer.contains("smart") {
            return ("Smart Device", .iotDevice, nil)
        }
        
        return (nil, .unknown, nil)
    }
    
    nonisolated private func analyzeHTTPHeader(key: String, value: String) -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let lowercaseKey = key.lowercased()
        let lowercaseValue = value.lowercased()
        
        if lowercaseKey.contains("device") && lowercaseValue.contains("apple") {
            return ("Apple Device", .smartphone, "Apple")
        } else if lowercaseValue.contains("android") {
            return ("Android Device", .smartphone, "Google")
        } else if lowercaseValue.contains("roku") {
            return ("Roku", .smartTV, "Roku")
        } else if lowercaseValue.contains("samsung") && lowercaseValue.contains("tv") {
            return ("Samsung TV", .smartTV, "Samsung")
        } else if lowercaseValue.contains("lg") && lowercaseValue.contains("tv") {
            return ("LG TV", .smartTV, "LG")
        }
        
        return (nil, .unknown, nil)
    }
    
    nonisolated private func analyzeHTMLContent(_ html: String) -> (name: String?, type: ConnectedDevice.DeviceType, manufacturer: String?) {
        let lowercaseHTML = html.lowercased()
        
        // Look for common device indicators in HTML
        if lowercaseHTML.contains("router") && (lowercaseHTML.contains("admin") || lowercaseHTML.contains("login")) {
            if lowercaseHTML.contains("tp-link") {
                return ("TP-Link Router", .router, "TP-Link")
            } else if lowercaseHTML.contains("netgear") {
                return ("Netgear Router", .router, "Netgear")
            } else if lowercaseHTML.contains("linksys") {
                return ("Linksys Router", .router, "Linksys")
            } else if lowercaseHTML.contains("asus") {
                return ("ASUS Router", .router, "ASUS")
            }
            return ("Router", .router, nil)
        } else if lowercaseHTML.contains("printer") || lowercaseHTML.contains("print") {
            if lowercaseHTML.contains("hp") {
                return ("HP Printer", .printer, "HP")
            } else if lowercaseHTML.contains("canon") {
                return ("Canon Printer", .printer, "Canon")
            } else if lowercaseHTML.contains("epson") {
                return ("Epson Printer", .printer, "Epson")
            }
            return ("Printer", .printer, nil)
        } else if lowercaseHTML.contains("smart tv") || lowercaseHTML.contains("television") {
            return ("Smart TV", .smartTV, nil)
        } else if lowercaseHTML.contains("plex") {
            return ("Plex Server", .smartTV, nil)
        } else if lowercaseHTML.contains("nas") || lowercaseHTML.contains("network attached storage") {
            return ("NAS Device", .desktop, nil)
        }
        
        return (nil, .unknown, nil)
    }
    
    private func generateSmartDeviceName(for ipAddress: String, type: ConnectedDevice.DeviceType, manufacturer: String?) -> String {
        let lastOctet = ipAddress.components(separatedBy: ".").last ?? "X"
        
        // Try to detect router/gateway by common IP patterns
        let isLikelyRouter = ipAddress.hasSuffix(".1") || ipAddress.hasSuffix(".254") || 
                            ipAddress.contains("192.168.1.1") || ipAddress.contains("192.168.0.1") ||
                            ipAddress.contains("10.0.0.1")
        
        if isLikelyRouter {
            return manufacturer != nil ? "\(manufacturer!) Router" : "Home Router"
        }
        
        let manufacturerPrefix = manufacturer != nil ? "\(manufacturer!) " : ""
        
        switch type {
        case .router:
            return "\(manufacturerPrefix)Router"
        case .smartphone:
            if manufacturer == "Apple" {
                return "iPhone (\(lastOctet))"
            } else if manufacturer == "Google" {
                return "Android (\(lastOctet))"
            }
            return "Smartphone (\(lastOctet))"
        case .tablet:
            if manufacturer == "Apple" {
                return "iPad (\(lastOctet))"
            }
            return "\(manufacturerPrefix)Tablet (\(lastOctet))"
        case .laptop:
            if manufacturer == "Apple" {
                return "MacBook (\(lastOctet))"
            }
            return "\(manufacturerPrefix)Laptop (\(lastOctet))"
        case .desktop:
            if manufacturer == "Apple" {
                return "Mac (\(lastOctet))"
            }
            return "\(manufacturerPrefix)Computer (\(lastOctet))"
        case .smartTV:
            return "\(manufacturerPrefix)Smart TV (\(lastOctet))"
        case .gameConsole:
            return "\(manufacturerPrefix)Game Console (\(lastOctet))"
        case .iotDevice:
            return "\(manufacturerPrefix)Smart Device (\(lastOctet))"
        case .printer:
            return "\(manufacturerPrefix)Printer (\(lastOctet))"
        case .speaker:
            return "\(manufacturerPrefix)Speaker (\(lastOctet))"
        case .unknown:
            // Provide smarter unknown device names based on IP patterns  
            let octet = Int(lastOctet) ?? 0
            if octet <= 5 {
                return "Router/Gateway (\(lastOctet))"
            } else if octet <= 50 {
                return "Computer (\(lastOctet))"
            } else if octet <= 200 {
                return "Mobile Device (\(lastOctet))"
            } else {
                return "Smart Device (\(lastOctet))"
            }
        }
    }
    
    // MARK: - Network Utility Methods
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi interfaces
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        return address
    }
    
    private func getGatewayIP() -> String? {
        // This is a simplified implementation
        // In a real app, you'd need to parse routing table
        guard let localIP = getLocalIPAddress() else { return nil }
        
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return nil }
        
        // Assume gateway is .1 in the subnet
        return "\(components[0]).\(components[1]).\(components[2]).1"
    }
    
    private func getSubnetFromIP(_ ip: String) -> String? {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else { return nil }
        
        // Assume /24 subnet (255.255.255.0)
        return "\(components[0]).\(components[1]).\(components[2])"
    }
    
    private func generateIPAddresses(for subnet: String) -> [String] {
        var addresses: [String] = []
        
        // Scan common IP ranges (skip .0 and .255)
        for i in 1...254 {
            addresses.append("\(subnet).\(i)")
        }
        
        return addresses
    }
    
    // MARK: - Caching
    
    private func cacheScanResult(_ result: NetworkScanResult) {
        do {
            let data = try JSONEncoder().encode(result)
            userDefaults.set(data, forKey: cacheKey)
        } catch {
            logger.error("Failed to cache scan result: \(error)")
        }
    }
    
    private func loadCachedScanResult() {
        guard let data = userDefaults.data(forKey: cacheKey) else { return }
        
        do {
            let result = try JSONDecoder().decode(NetworkScanResult.self, from: data)
            // Only use cache if it's less than 1 hour old
            if Date().timeIntervalSince(result.scanDate) < 3600 {
                lastScanResult = result
            }
        } catch {
            logger.error("Failed to load cached scan result: \(error)")
        }
    }
}

// MARK: - Error Types

enum NetworkScanError: Error, LocalizedError {
    case noLocalNetwork
    case scanTimeout
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noLocalNetwork:
            return "No local network connection found"
        case .scanTimeout:
            return "Network scan timed out"
        case .permissionDenied:
            return "Network access permission denied"
        }
    }
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Additional Helper Methods

extension NetworkScannerService {
    private func estimateDeviceType(ip: String, hostname: String?, isCurrentDevice: Bool) -> ConnectedDevice.DeviceType {
        if isCurrentDevice {
            return .smartphone // Assuming iOS device
        }
        
        // Try to guess from IP patterns if no hostname
        if hostname == nil {
            if ip.hasSuffix(".1") || ip.hasSuffix(".254") {
                return .router
            }
            
            // Common IP ranges for different device types
            let lastOctet = Int(ip.components(separatedBy: ".").last ?? "0") ?? 0
            
            // Router/Gateway range (typically .1-.5)
            if lastOctet >= 1 && lastOctet <= 5 {
                return .router
            }
            // Static IP range for computers/servers (typically .6-.50)
            else if lastOctet >= 6 && lastOctet <= 50 {
                return .desktop
            }
            // DHCP range for mobile devices (typically .51-.200)
            else if lastOctet >= 51 && lastOctet <= 200 {
                return .smartphone
            }
            // High range for IoT devices (typically .201+)
            else if lastOctet > 200 {
                return .iotDevice
            }
            
            return .unknown
        }
        
        // If we have a hostname, use the full analysis
        let result = estimateDeviceTypeAndManufacturer(from: hostname!, ip: ip)
        return result.type
    }
}

// Import for network info (requires adding SystemConfiguration.framework)
import SystemConfiguration.CaptiveNetwork
