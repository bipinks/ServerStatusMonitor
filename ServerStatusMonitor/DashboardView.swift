import SwiftUI

struct StatTile: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon and Title
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Value
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatusHistoryRow: View {
    let server: Server
    let statusCheck: ServerStatusCheck
    
    var body: some View {
        HStack {
            // Status Icon
            Image(systemName: statusCheck.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(statusCheck.isOnline ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.domain)
                    .font(.headline)
                
                Text("Status Code: \(statusCheck.statusCode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(statusCheck.timestamp.formatted())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct OfflineServerRow: View {
    let server: Server
    
    var body: some View {
        HStack {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.domain)
                    .font(.headline)
                
                if let lastChecked = server.lastChecked {
                    Text("Last checked: \(lastChecked.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let lastStatusCode = server.statusHistory.last?.statusCode {
                Text("Status: \(lastStatusCode)")
                    .font(.caption)
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DashboardView: View {
    @ObservedObject var serverManager: ServerManager
    @State private var isChecking = false
    
    private var totalServers: Int {
        serverManager.servers.count
    }
    
    private var onlineServers: Int {
        serverManager.servers.filter { $0.isOnline == true }.count
    }
    
    private var offlineServers: Int {
        serverManager.servers.filter { $0.isOnline == false }.count
    }
    
    private var uncheckedServers: Int {
        serverManager.servers.filter { $0.isOnline == nil }.count
    }
    
    private var offlineServersList: [Server] {
        serverManager.servers.filter { $0.isOnline == false }
            .sorted { $0.lastChecked ?? Date.distantPast > $1.lastChecked ?? Date.distantPast }
    }
    
    private var combinedHistory: [(Server, ServerStatusCheck)] {
        var history: [(Server, ServerStatusCheck)] = []
        for server in serverManager.servers {
            for check in server.statusHistory {
                history.append((server, check))
            }
        }
        return history.sorted { $0.1.timestamp > $1.1.timestamp }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title Section with Check All Button
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dashboard")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Server Status Overview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            isChecking = true
                            await serverManager.checkAllServers()
                            isChecking = false
                        }
                    }) {
                        Label {
                            Text("Check All")
                        } icon: {
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(totalServers == 0 || isChecking)
                }
                .padding(.bottom)
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    StatTile(
                        title: "Total Servers",
                        value: totalServers,
                        icon: "server.rack",
                        color: .blue
                    )
                    
                    StatTile(
                        title: "Online Servers",
                        value: onlineServers,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatTile(
                        title: "Offline Servers",
                        value: offlineServers,
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                    
                    StatTile(
                        title: "Unchecked Servers",
                        value: uncheckedServers,
                        icon: "questionmark.circle.fill",
                        color: .gray
                    )
                }
                
                // Offline Servers Section
                if !offlineServersList.isEmpty {
                    GroupBox(label: 
                        HStack {
                            Text("Offline Servers").font(.headline)
                            Spacer()
                            Text("\(offlineServersList.count) servers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    ) {
                        VStack(spacing: 0) {
                            ForEach(offlineServersList) { server in
                                OfflineServerRow(server: server)
                                if server.id != offlineServersList.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Status History Section
                if !combinedHistory.isEmpty {
                    GroupBox(label: 
                        HStack {
                            Text("Recent Status Checks").font(.headline)
                            Spacer()
                            Text("\(combinedHistory.count) checks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    ) {
                        VStack(spacing: 0) {
                            ForEach(combinedHistory.prefix(20), id: \.1.id) { server, check in
                                StatusHistoryRow(server: server, statusCheck: check)
                                if check.id != combinedHistory.prefix(20).last?.1.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    DashboardView(serverManager: ServerManager())
} 