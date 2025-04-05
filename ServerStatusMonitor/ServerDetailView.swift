import SwiftUI

struct ServerDetailView: View {
    @ObservedObject var serverManager: ServerManager
    let serverId: UUID  // Store server ID instead of the server itself
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var historyCount = 0  // Track history count for auto-scroll
    
    // Computed property to get the current server
    private var server: Server? {
        serverManager.servers.first { $0.id == serverId }
    }
    
    init(serverManager: ServerManager, server: Server) {
        self.serverManager = serverManager
        self.serverId = server.id
        _historyCount = State(initialValue: server.statusHistory.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let server = server {  // Use optional binding
                // Server Information Section
                GroupBox(label: Text("Server Information").font(.headline)) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Domain:")
                                .foregroundColor(.secondary)
                            Text(server.domain)
                                .textSelection(.enabled)
                        }
                        
                        HStack {
                            Text("Expected Status:")
                                .foregroundColor(.secondary)
                            Text("\(server.expectedStatusCode)")
                        }
                        
                        HStack {
                            Text("Current Status:")
                                .foregroundColor(.secondary)
                            StatusBadge(
                                text: server.statusText,
                                color: server.statusColor
                            )
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    isChecking = true
                                    if let error = await serverManager.checkServer(server) {
                                        errorMessage = error
                                        showingError = true
                                    }
                                    isChecking = false
                                }
                            } label: {
                                HStack {
                                    if isChecking {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text("Check Now")
                                }
                            }
                            .disabled(isChecking)
                        }
                        
                        if let lastChecked = server.lastChecked {
                            HStack {
                                Text("Last Checked:")
                                    .foregroundColor(.secondary)
                                Text(lastChecked.formatted())
                            }
                        }
                    }
                    .padding()
                }
                
                // Status History Section
                GroupBox(label: Text("Status History").font(.headline)) {
                    if server.statusHistory.isEmpty {
                        ContentUnavailableView(
                            "No Status History",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Check the server status to see its history")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(server.statusHistory.reversed()) { check in
                                    HStack {
                                        Image(systemName: check.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(check.isOnline ? .green : .red)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Status Code: \(check.statusCode)")
                                                .font(.headline)
                                            
                                            Text(check.timestamp.formatted())
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .id(check.id)  // Use the check's ID for scrolling
                                }
                            }
                            .listStyle(.plain)
                            .onChange(of: server.statusHistory.count) { newCount in
                                if newCount > historyCount {
                                    // New history item added, scroll to top
                                    if let firstCheck = server.statusHistory.last {
                                        withAnimation {
                                            proxy.scrollTo(firstCheck.id, anchor: .top)
                                        }
                                    }
                                }
                                historyCount = newCount
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Server Not Found",
                    systemImage: "server.rack",
                    description: Text("The selected server could not be found")
                )
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        .alert("Server Check Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    ServerDetailView(
        serverManager: ServerManager(),
        server: Server(domain: "example.com", expectedStatusCode: 200)
    )
} 