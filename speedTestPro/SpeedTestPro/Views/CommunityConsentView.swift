//
//  CommunityConsentView.swift
//  SpeedTestPro
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import SwiftUI

/// Community consent and privacy information view
struct CommunityConsentView: View {
    @ObservedObject var communityService: CommunityMappingService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var hasReadPrivacyPolicy = false
    @State private var understandsAnonymization = false
    @State private var agreesToContribute = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Join the SpeedTest Community")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Help improve network insights for everyone while keeping your data completely private")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                    
                    // What We Collect Section
                    ConsentSection(
                        title: "What We Collect",
                        icon: "doc.text.fill",
                        color: .blue
                    ) {
                        ConsentBulletPoint(
                            icon: "speedometer",
                            text: "Speed test results (download, upload, ping)"
                        )
                        
                        ConsentBulletPoint(
                            icon: "location.fill",
                            text: "Approximate location (rounded to ~1km for privacy)"
                        )
                        
                        ConsentBulletPoint(
                            icon: "wifi",
                            text: "Connection type (WiFi or Cellular)"
                        )
                        
                        ConsentBulletPoint(
                            icon: "antenna.radiowaves.left.and.right",
                            text: "Network provider (if detectable)"
                        )
                    }
                    
                    // What We Don't Collect Section
                    ConsentSection(
                        title: "What We Don't Collect",
                        icon: "shield.fill",
                        color: .green
                    ) {
                        ConsentBulletPoint(
                            icon: "person.fill.xmark",
                            text: "No personal information or device identifiers",
                            color: .green
                        )
                        
                        ConsentBulletPoint(
                            icon: "location.slash.fill",
                            text: "No exact location - only general area",
                            color: .green
                        )
                        
                        ConsentBulletPoint(
                            icon: "eye.slash.fill",
                            text: "No browsing history or app usage data",
                            color: .green
                        )
                        
                        ConsentBulletPoint(
                            icon: "externaldrive.fill.badge.xmark",
                            text: "No data sold to third parties - ever",
                            color: .green
                        )
                    }
                    
                    // Privacy Protection Section
                    ConsentSection(
                        title: "Privacy Protection",
                        icon: "lock.shield.fill",
                        color: .purple
                    ) {
                        ConsentBulletPoint(
                            icon: "shuffle",
                            text: "Data is anonymized and aggregated before storage"
                        )
                        
                        ConsentBulletPoint(
                            icon: "map",
                            text: "Location rounded to protect your privacy (≈1km radius)"
                        )
                        
                        ConsentBulletPoint(
                            icon: "trash.fill",
                            text: "You can stop contributing and delete data anytime"
                        )
                        
                        ConsentBulletPoint(
                            icon: "checkmark.shield.fill",
                            text: "All data transmission is encrypted"
                        )
                    }
                    
                    // Benefits Section
                    ConsentSection(
                        title: "Community Benefits",
                        icon: "heart.fill",
                        color: .red
                    ) {
                        ConsentBulletPoint(
                            icon: "chart.line.uptrend.xyaxis",
                            text: "See how your area's network performance compares"
                        )
                        
                        ConsentBulletPoint(
                            icon: "building.2.fill",
                            text: "Compare ISP providers in your neighborhood"
                        )
                        
                        ConsentBulletPoint(
                            icon: "map.fill",
                            text: "Identify best and worst coverage areas nearby"
                        )
                        
                        ConsentBulletPoint(
                            icon: "hands.sparkles.fill",
                            text: "Help others make informed internet decisions"
                        )
                    }
                    
                    // Consent Checkboxes
                    VStack(spacing: 16) {
                        Divider()
                        
                        Text("Your Consent")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ConsentCheckbox(
                            isChecked: $hasReadPrivacyPolicy,
                            text: "I have read and understand the privacy policy"
                        )
                        
                        ConsentCheckbox(
                            isChecked: $understandsAnonymization,
                            text: "I understand my data will be anonymized and aggregated"
                        )
                        
                        ConsentCheckbox(
                            isChecked: $agreesToContribute,
                            text: "I agree to contribute my speed test results to help the community"
                        )
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: joinCommunity) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Join Community")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(allConsentsGiven ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!allConsentsGiven)
                        
                        Button(action: decline) {
                            Text("Maybe Later")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("You can change your mind anytime in Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Button("Privacy Policy") {
                                // Open privacy policy
                            }
                            .font(.caption)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Terms of Service") {
                                // Open terms
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Community Consent")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    decline()
                }
            )
        }
    }
    
    private var allConsentsGiven: Bool {
        hasReadPrivacyPolicy && understandsAnonymization && agreesToContribute
    }
    
    private func joinCommunity() {
        communityService.requestCommunityParticipation()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func decline() {
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Helper Views

struct ConsentSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConsentBulletPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    init(icon: String, text: String, color: Color = .blue) {
        self.icon = icon
        self.text = text
        self.color = color
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
                .frame(width: 16)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConsentCheckbox: View {
    @Binding var isChecked: Bool
    let text: String
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .blue : .gray)
                    .font(.title3)
                
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Privacy Information Detail View

struct PrivacyDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Our Privacy Commitment")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("SpeedTest Pro is built with privacy at its core. Here's exactly how we protect your data:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    PrivacySection(title: "Data Anonymization") {
                        Text("Before any data leaves your device:")
                        
                        BulletPoint("Your exact location is rounded to approximately 1 kilometer")
                        BulletPoint("All device identifiers are removed")
                        BulletPoint("Personal information is never collected")
                        BulletPoint("Data is aggregated with other users before storage")
                    }
                    
                    PrivacySection(title: "Data Security") {
                        BulletPoint("All data transmission uses end-to-end encryption")
                        BulletPoint("Servers are secured with industry-standard protection")
                        BulletPoint("No third-party analytics or tracking services")
                        BulletPoint("Regular security audits and updates")
                    }
                    
                    PrivacySection(title: "Your Control") {
                        BulletPoint("Opt out anytime in Settings")
                        BulletPoint("Request deletion of your contributed data")
                        BulletPoint("View exactly what data is shared")
                        BulletPoint("Control participation on a per-test basis")
                    }
                    
                    PrivacySection(title: "Legal Framework") {
                        BulletPoint("Compliant with GDPR and CCPA regulations")
                        BulletPoint("Data retention limited to 2 years maximum")
                        BulletPoint("No data sales or sharing with third parties")
                        BulletPoint("Transparent privacy policy and terms")
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Details")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct PrivacySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
                .fontWeight(.bold)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
struct CommunityConsentView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityConsentView(communityService: CommunityMappingService())
    }
}
#endif
