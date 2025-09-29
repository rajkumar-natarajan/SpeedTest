//
//  ConnectedDevicesView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

/// View component for displaying connected devices on the network
struct ConnectedDevicesView: View {
    @StateObject private var scanner = NetworkScannerService()
    @State private var showingDeviceDetails = false
    @State private var selectedDevice: ConnectedDevice?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with scan button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected Devices")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Scan your network to find connected devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await scanner.scanNetwork()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Scan")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(scanner.isScanning)
                }
                .padding(.horizontal)
                
                // Scanning progress indicator
                if scanner.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Scanning network... Found \(scanner.lastScanResult?.connectedDevices.count ?? 0) devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Devices list
                if let scanResult = scanner.lastScanResult {
                    DevicesListView(
                        scanResult: scanResult,
                        onDeviceSelected: { device in
                            selectedDevice = device
                            showingDeviceDetails = true
                        }
                    )
                } else if !scanner.isScanning {
                    EmptyDevicesView()
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-scan on first appearance if no cached data
            if scanner.lastScanResult == nil {
                Task {
                    await scanner.scanNetwork()
                }
            }
        }
        .sheet(isPresented: $showingDeviceDetails) {
            if let device = selectedDevice {
                DeviceDetailsView(device: device)
            }
        }
    }
}

// MARK: - Devices List View

struct DevicesListView: View {
    let scanResult: NetworkScanResult
    let onDeviceSelected: (ConnectedDevice) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Network info card
            NetworkInfoCard(scanResult: scanResult)
            
            // Device type summary
            DeviceTypeSummaryView(scanResult: scanResult)
            
            // Devices list
            LazyVStack(spacing: 8) {
                ForEach(scanResult.connectedDevices) { device in
                    DeviceRowView(device: device) {
                        onDeviceSelected(device)
                    }
                }
            }
        }
    }
}

// MARK: - Network Info Card

struct NetworkInfoCard: View {
    let scanResult: NetworkScanResult
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Current network details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(spacing: 8) {
                InfoRow(label: "Network Name", value: scanResult.networkName)
                InfoRow(label: "Total Devices", value: "\(scanResult.connectedDevices.count)")
                InfoRow(label: "Scan Duration", value: String(format: "%.1f seconds", scanResult.scanDuration))
                InfoRow(label: "Last Scan", value: DateFormatter.localizedString(from: scanResult.scanTime, dateStyle: .none, timeStyle: .short))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Device Type Summary

struct DeviceTypeSummaryView: View {
    let scanResult: NetworkScanResult
    
    var deviceTypeCounts: [DeviceType: Int] {
        Dictionary(grouping: scanResult.connectedDevices, by: { $0.deviceType })
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Device Types")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array(deviceTypeCounts.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { deviceType in
                    HStack(spacing: 8) {
                        Image(systemName: deviceType.iconName)
                            .foregroundColor(deviceType.color)
                            .frame(width: 20)
                        Text("\(deviceType.displayName): \(deviceTypeCounts[deviceType] ?? 0)")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Device Row

struct DeviceRowView: View {
    let device: ConnectedDevice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: device.deviceType.iconName)
                    .foregroundColor(device.deviceType.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(device.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection indicator
                Circle()
                    .fill(device.isCurrentDevice ? Color.green : Color.blue)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State

struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Devices Found")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Tap 'Scan' to search for devices on your network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Device Details Modal

struct DeviceDetailsView: View {
    let device: ConnectedDevice
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Device header
                VStack(spacing: 12) {
                    Image(systemName: device.deviceType.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(device.deviceType.color)
                    
                    Text(device.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top)
                
                // Device details
                VStack(spacing: 12) {
                    DetailRow(label: "IP Address", value: device.ipAddress)
                    if let hostname = device.hostname {
                        DetailRow(label: "Hostname", value: hostname)
                    }
                    if let manufacturer = device.manufacturer {
                        DetailRow(label: "Manufacturer", value: manufacturer)
                    }
                    DetailRow(label: "Device Type", value: device.deviceType.displayName)
                    if device.isCurrentDevice {
                        DetailRow(label: "Status", value: "This Device", valueColor: .green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Device Details")
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

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConnectedDevicesView()
}

// MARK: - Device Display Name Helper

extension ConnectedDevice {
    /// Generate a smart display name for the device
    var displayName: String {
        // If we have a meaningful hostname, use it
        if let hostname = self.hostname, !hostname.isEmpty && hostname != "Network Device" {
            return hostname
        }
        
        // Otherwise, generate a smart name based on device type and IP
        let lastOctet = self.ipAddress.components(separatedBy: ".").last ?? "X"
        let manufacturerPrefix = self.manufacturer != nil ? "\(self.manufacturer!) " : ""
        
        // Check for router/gateway patterns
        if self.ipAddress.hasSuffix(".1") || self.ipAddress.hasSuffix(".254") || self.deviceType == .router {
            return manufacturerPrefix.isEmpty ? "Home Router" : "\(manufacturerPrefix)Router"
        }
        
        switch self.deviceType {
        case .router:
            return "\(manufacturerPrefix)Router"
        case .smartphone:
            if self.manufacturer == "Apple" {
                return self.isCurrentDevice ? "This iPhone" : "iPhone (\(lastOctet))"
            } else if self.manufacturer == "Google" {
                return "Android (\(lastOctet))"
            }
            return self.isCurrentDevice ? "This Phone" : "Smartphone (\(lastOctet))"
        case .tablet:
            if self.manufacturer == "Apple" {
                return self.isCurrentDevice ? "This iPad" : "iPad (\(lastOctet))"
            }
            return self.isCurrentDevice ? "This Tablet" : "\(manufacturerPrefix)Tablet (\(lastOctet))"
        case .laptop:
            if self.manufacturer == "Apple" {
                return "MacBook (\(lastOctet))"
            }
            return "\(manufacturerPrefix)Laptop (\(lastOctet))"
        case .desktop:
            if self.manufacturer == "Apple" {
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
            // Smart fallback based on IP patterns
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
}
