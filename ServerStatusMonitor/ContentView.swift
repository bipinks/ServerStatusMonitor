//
//  ContentView.swift
//  ServerStatusMonitor
//
//  Created by Bipin Kareparambil on 04/04/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    @State private var selectedServer: Server?
    @State private var showingAddServer = false
    @State private var showingEditServer = false
    @State private var showingSettings = false
    @State private var isChecking = false
    @State private var serverToEdit: Server?
    
    var body: some View {
        NavigationSplitView {
            List {
                // Dashboard Navigation
                Section {
                    Button(action: { selectedServer = nil }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                                .foregroundColor(.blue)
                            Text("Dashboard")
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Servers Section
                Section("Servers") {
                    if serverManager.servers.isEmpty {
                        Text("No servers added")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(serverManager.servers) { server in
                            Button(action: { selectedServer = server }) {
                                ServerRow(server: server)
                            }
                            .buttonStyle(.plain)
                            .background(selectedServer?.id == server.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            .contextMenu {
                                Button(action: {
                                    selectedServer = server
                                    showingAddServer = true
                                }) {
                                    Label("Edit Server", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: {
                                    if let index = serverManager.servers.firstIndex(where: { $0.id == server.id }) {
                                        serverManager.removeServer(at: IndexSet(integer: index))
                                        if selectedServer?.id == server.id {
                                            selectedServer = nil
                                        }
                                    }
                                }) {
                                    Label("Delete Server", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Servers")
            .listStyle(.sidebar)
            .frame(minWidth: 300, idealWidth: 300, maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddServer = true }) {
                        Label("Add Server", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            if let server = selectedServer {
                ServerDetailView(serverManager: serverManager, server: server)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                showingAddServer = true
                            }) {
                                Label("Edit Server", systemImage: "pencil")
                            }
                        }
                        
                        ToolbarItem(placement: .destructiveAction) {
                            Button(role: .destructive, action: {
                                if let index = serverManager.servers.firstIndex(where: { $0.id == server.id }) {
                                    serverManager.removeServer(at: IndexSet(integer: index))
                                    selectedServer = nil
                                }
                            }) {
                                Label("Delete Server", systemImage: "trash")
                            }
                        }
                    }
            } else {
                DashboardView(serverManager: serverManager)
            }
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView(serverManager: serverManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(serverManager: serverManager)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding()
            
            Text("No servers added yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Click the + button to add a server")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding()
            
            Text("Select a server to view details")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Choose a server from the list on the left")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ServerRow: View {
    let server: Server
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // Status Indicator
                Circle()
                    .fill(server.isOnline == true ? Color.green : 
                          server.isOnline == false ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                
                // Domain
                Text(server.domain)
                    .font(.system(.body))
                
                Spacer()
                
                // Status Text
                Text(server.isOnline == true ? "Online" : 
                     server.isOnline == false ? "Offline" : "")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            
            // Timestamp
            if let lastChecked = server.lastChecked {
                Text(lastChecked.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16) // Align with domain text
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusIndicator: View {
    let server: Server
    
    var body: some View {
        Circle()
            .fill(server.isOnline == true ? Color.green : 
                  server.isOnline == false ? Color.red : Color.gray)
            .frame(width: 8, height: 8)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
            )
    }
}

#Preview {
    ContentView()
}
