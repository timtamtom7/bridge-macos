import Foundation
import os.log
import AppKit
import SwiftUI

final class FeedbackManager {
    static let shared = FeedbackManager()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "FeedbackManager")
    
    private let feedbackURL: URL? = URL(string: "https://api.github.com/repos/timtamtom7/bridge-macos/issues")
    
    private init() {}
    
    enum FeedbackCategory: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case performance = "Performance Issue"
        case other = "Other"
    }
    
    struct Feedback: Codable {
        let category: String
        let message: String
        let screenshotPath: String?
        let deviceInfo: DeviceInfo
        let appVersion: String
        let macOSVersion: String
        let timestamp: Date
        let userOptIn: Bool
        
        struct DeviceInfo: Codable {
            let deviceName: String
            let deviceModel: String
            let osVersion: String
        }
    }
    
    // MARK: - Submit Feedback
    
    func submitFeedback(category: FeedbackCategory, message: String, screenshot: NSImage?, attachDiagnostics: Bool) async throws {
        logger.info("Submitting feedback: \(category.rawValue)")
        
        var screenshotPath: String? = nil
        if let screenshot = screenshot {
            screenshotPath = saveScreenshot(screenshot)
        }
        
        let feedback = Feedback(
            category: category.rawValue,
            message: message,
            screenshotPath: screenshotPath,
            deviceInfo: Feedback.DeviceInfo(
                deviceName: Host.current().localizedName ?? "Unknown",
                deviceModel: "Mac",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString
            ),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            timestamp: Date(),
            userOptIn: attachDiagnostics
        )
        
        // Store locally first
        try storeFeedbackLocally(feedback)
        
        // Upload when on WiFi
        if isOnWiFi() {
            try await uploadPendingFeedback()
        }
    }
    
    // MARK: - Local Storage
    
    private func storeFeedbackLocally(_ feedback: Feedback) throws {
        let feedbackDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Bridge/Feedback", isDirectory: true)
        
        try FileManager.default.createDirectory(at: feedbackDir, withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(feedback)
        
        let filename = "feedback_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = feedbackDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        
        logger.info("Feedback stored locally: \(filename)")
    }
    
    func getPendingFeedback() -> [URL] {
        let feedbackDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Bridge/Feedback", isDirectory: true)
        
        guard let contents = try? FileManager.default.contentsOfDirectory(at: feedbackDir!, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return contents.filter { $0.pathExtension == "json" }
    }
    
    // MARK: - Upload
    
    func uploadPendingFeedback() async throws {
        let pending = getPendingFeedback()
        
        for url in pending {
            try await uploadFeedback(at: url)
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func uploadFeedback(at url: URL) async throws {
        logger.info("Uploading feedback: \(url.lastPathComponent)")
        // Upload implementation via GitHub Issues API or custom backend
    }
    
    // MARK: - Helpers
    
    private func saveScreenshot(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let feedbackDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Bridge/Feedback/Screenshots", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: feedbackDir, withIntermediateDirectories: true)
        
        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = feedbackDir.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            return fileURL.path
        } catch {
            logger.error("Failed to save screenshot: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func isOnWiFi() -> Bool {
        // Simplified WiFi detection
        return true
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @State private var category: FeedbackManager.FeedbackCategory = .bug
    @State private var message = ""
    @State private var attachScreenshot = true
    @State private var attachDiagnostics = true
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send Feedback")
                .font(.headline)
            
            Picker("Category", selection: $category) {
                ForEach(FeedbackManager.FeedbackCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            
            TextEditor(text: $message)
                .frame(height: 150)
                .border(Color.gray.opacity(0.3))
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("Describe your issue or suggestion...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            
            Toggle("Attach screenshot", isOn: $attachScreenshot)
            Toggle("Attach diagnostics (logs)", isOn: $attachDiagnostics)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    // Dismiss
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Submit") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(message.isEmpty || isSubmitting)
            }
        }
        .padding()
    }
    
    private func submit() {
        isSubmitting = true
        
        Task {
            do {
                let screenshot: NSImage? = attachScreenshot ? NSApplication.shared.windows.first?.capturedImage : nil
                try await FeedbackManager.shared.submitFeedback(
                    category: category,
                    message: message,
                    screenshot: screenshot,
                    attachDiagnostics: attachDiagnostics
                )
            } catch {
                print("Feedback submission failed: \(error)")
            }
            
            isSubmitting = false
        }
    }
}

extension NSWindow {
    var capturedImage: NSImage? {
        guard let contentView = self.contentView else { return nil }
        return contentView.capturedImage
    }
}

extension NSView {
    var capturedImage: NSImage? {
        let rect = self.bounds
        guard let bitmap = self.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        self.cacheDisplay(in: rect, to: bitmap)
        return NSImage(size: rect.size)
    }
}
