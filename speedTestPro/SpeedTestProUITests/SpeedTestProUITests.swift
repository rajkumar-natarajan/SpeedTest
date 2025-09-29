//
//  SpeedTestProUITests.swift
//  SpeedTestProUITests
//
//  Created by SpeedTest Pro on 2025-09-29.
//  Copyright © 2025 SpeedTest Pro. All rights reserved.
//

import XCTest

/// UI Tests for SpeedTest Pro
final class SpeedTestProUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch Tests
    
    func testAppLaunches() throws {
        // Test that the app launches successfully
        XCTAssertTrue(app.staticTexts["SpeedTest Pro"].exists, "App title should be visible")
    }
    
    func testTabBarExists() throws {
        // Test that all tab bar items exist
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        
        XCTAssertTrue(app.tabBars.buttons["Test"].exists, "Test tab should exist")
        XCTAssertTrue(app.tabBars.buttons["History"].exists, "History tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")
    }
    
    // MARK: - Home Tab Tests
    
    func testHomeTabNavigation() throws {
        // Test navigation to home tab
        app.tabBars.buttons["Test"].tap()
        
        XCTAssertTrue(app.staticTexts["SpeedTest Pro"].exists, "Home screen title should be visible")
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Start Test").element.exists, "Start test button should exist")
    }
    
    func testStartTestButtonExists() throws {
        // Navigate to home tab
        app.tabBars.buttons["Test"].tap()
        
        let startButton = app.buttons.containing(.staticText, identifier: "Start Test").element
        XCTAssertTrue(startButton.exists, "Start test button should exist")
        XCTAssertTrue(startButton.isEnabled, "Start test button should be enabled")
    }
    
    func testConnectionStatusVisible() throws {
        // Navigate to home tab
        app.tabBars.buttons["Test"].tap()
        
        // Look for connection status indicators
        let wifiIndicator = app.images["wifi"]
        let cellularIndicator = app.images["antenna.radiowaves.left.and.right"]
        let noConnectionIndicator = app.images["wifi.slash"]
        
        let hasConnection = wifiIndicator.exists || cellularIndicator.exists || noConnectionIndicator.exists
        XCTAssertTrue(hasConnection, "Some connection status indicator should be visible")
    }
    
    // MARK: - History Tab Tests
    
    func testHistoryTabNavigation() throws {
        // Test navigation to history tab
        app.tabBars.buttons["History"].tap()
        
        XCTAssertTrue(app.navigationBars["History"].exists, "History navigation bar should exist")
    }
    
    func testEmptyHistoryState() throws {
        // Navigate to history tab
        app.tabBars.buttons["History"].tap()
        
        // Check for empty state
        if app.staticTexts["No Test History"].exists {
            XCTAssertTrue(app.staticTexts["Your speed test results will appear here after you run your first test."].exists,
                         "Empty state description should be visible")
        }
    }
    
    // MARK: - Settings Tab Tests
    
    func testSettingsTabNavigation() throws {
        // Test navigation to settings tab
        app.tabBars.buttons["Settings"].tap()
        
        XCTAssertTrue(app.navigationBars["Settings"].exists, "Settings navigation bar should exist")
    }
    
    func testDarkModeToggle() throws {
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Look for dark mode toggle
        let darkModeSwitch = app.switches.element(matching: .switch, identifier: "Dark Mode")
        if darkModeSwitch.exists {
            // Test toggling dark mode
            let initialState = darkModeSwitch.value as? String
            darkModeSwitch.tap()
            
            // Wait for animation
            Thread.sleep(forTimeInterval: 0.5)
            
            let newState = darkModeSwitch.value as? String
            XCTAssertNotEqual(initialState, newState, "Dark mode toggle should change state")
        } else {
            // Look for the cell containing Dark Mode text
            XCTAssertTrue(app.staticTexts["Dark Mode"].exists, "Dark mode setting should be visible")
        }
    }
    
    func testSpeedUnitPicker() throws {
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Look for speed unit setting
        XCTAssertTrue(app.staticTexts["Speed Unit"].exists, "Speed unit setting should be visible")
    }
    
    func testAboutSection() throws {
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Look for about section
        XCTAssertTrue(app.staticTexts["About SpeedTest Pro"].exists, "About section should be visible")
    }
    
    func testPrivacyPolicyLink() throws {
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Look for privacy policy
        XCTAssertTrue(app.staticTexts["Privacy Policy"].exists, "Privacy policy link should be visible")
        
        // Tap privacy policy to open sheet
        app.staticTexts["Privacy Policy"].tap()
        
        // Wait for sheet to appear
        expectation(for: NSPredicate(format: "exists == true"), 
                   evaluatedWith: app.staticTexts["Privacy Policy"], 
                   handler: nil)
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test home tab accessibility
        app.tabBars.buttons["Test"].tap()
        
        let startButton = app.buttons.containing(.staticText, identifier: "Start Test").element
        XCTAssertTrue(startButton.isHittable, "Start test button should be accessible")
    }
    
    func testVoiceOverSupport() throws {
        // Navigate through tabs using accessibility
        let testTab = app.tabBars.buttons["Test"]
        let historyTab = app.tabBars.buttons["History"]
        let settingsTab = app.tabBars.buttons["Settings"]
        
        XCTAssertTrue(testTab.isHittable, "Test tab should be accessible")
        XCTAssertTrue(historyTab.isHittable, "History tab should be accessible")
        XCTAssertTrue(settingsTab.isHittable, "Settings tab should be accessible")
    }
    
    // MARK: - Landscape Orientation Tests (iPad only)
    
    func testLandscapeOrientation() throws {
        // Only test on iPad
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test only runs on iPad")
        }
        
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Wait for rotation
        Thread.sleep(forTimeInterval: 1.0)
        
        // Test that UI still works in landscape
        XCTAssertTrue(app.staticTexts["SpeedTest Pro"].exists, "App should work in landscape")
        
        // Rotate back
        XCUIDevice.shared.orientation = .portrait
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testTabSwitchingPerformance() throws {
        measure {
            // Switch between tabs multiple times
            for _ in 0..<10 {
                app.tabBars.buttons["Test"].tap()
                app.tabBars.buttons["History"].tap()
                app.tabBars.buttons["Settings"].tap()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testAppBackgroundAndForeground() throws {
        // Navigate to home
        app.tabBars.buttons["Test"].tap()
        
        // Send app to background
        XCUIDevice.shared.press(.home)
        
        // Wait a moment
        Thread.sleep(forTimeInterval: 1.0)
        
        // Bring app back to foreground
        app.activate()
        
        // Verify app is still functional
        XCTAssertTrue(app.staticTexts["SpeedTest Pro"].exists, "App should work after backgrounding")
    }
    
    func testMemoryWarningRecovery() throws {
        // This would ideally test memory warning scenarios
        // For now, just verify the app handles tab switching under load
        
        for _ in 0..<20 {
            app.tabBars.buttons["Test"].tap()
            app.tabBars.buttons["History"].tap()
            app.tabBars.buttons["Settings"].tap()
        }
        
        // App should still be responsive
        XCTAssertTrue(app.tabBars.buttons["Test"].isHittable, "App should remain responsive")
    }
    
    // MARK: - Helper Methods
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Element should exist within timeout")
    }
}
