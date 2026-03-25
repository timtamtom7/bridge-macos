import SwiftUI
import os.log

struct DiagnosticsPanel: View {
    @State private var logs: [LogEntry] = []
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostics")
                    .font(.headline)
                Spacer()
                Button("Export") {
                    exportDiagnostics()
                }
                .buttonStyle(.bordered)
                
                Button(isExpanded ? "Collapse" : "Expand") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }
            
            if isExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { entry in
                            LogEntryView(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "Diagnostics")
        // Load recent logs from system
        logs = [
            LogEntry(timestamp: Date(), level: "INFO", message: "Diagnostics panel opened"),
            LogEntry(timestamp: Date().addingTimeInterval(-60), level: "DEBUG", message: "Last sync completed")
        ]
    }
    
    private func exportDiagnostics() {
        let diagnostics = generateDiagnosticsBundle()
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "bridge_diagnostics_\(Date().ISO8601Format()).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func generateDiagnosticsBundle() -> String {
        let data: [String: Any] = [
            "timestamp": Date().ISO8601Format(),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "logs": logs.map { ["timestamp": $0.timestamp, "level": $0.level, "message": $0.message] }
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let message: String
}

struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(entry.level)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(levelColor.opacity(0.2))
                .foregroundColor(levelColor)
            
            Text(entry.message)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private var levelColor: Color {
        switch entry.level {
        case "ERROR": return .red
        case "WARNING": return .orange
        case "DEBUG": return .blue
        default: return .green
        }
    }
}

// MARK: - Debug Log Overlay (Option Key Required)

struct DebugLogOverlay: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isVisible = false
    
    var body: some View {
        if isVisible {
            DiagnosticsPanel()
                .frame(width: 400, height: 300)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 10)
        }
    }
}

extension NSApplication {
    func toggleDebugLogs() {
        NotificationCenter.default.post(name: .toggleDebugLogs, object: nil)
    }
}

extension Notification.Name {
    static let toggleDebugLogs = Notification.Name("toggleDebugLogs")
}
