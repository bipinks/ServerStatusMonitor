import SwiftUI

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: String? = "General"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let tabs = [
        Tab(id: "General", icon: "gear", title: "General"),
        Tab(id: "Notifications", icon: "bell", title: "Notifications"),
        Tab(id: "Advanced", icon: "slider.horizontal.3", title: "Advanced")
    ]
    
    var body: some View {
        NavigationSplitView {
            List(tabs, id: \.id, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .frame(minWidth: 200, maxWidth: 250)
        } detail: {
            tabContent(for: selectedTab ?? "General")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .alert("Invalid Setting", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: String) -> some View {
        switch tab {
        case "General":
            GeneralSettingsTab(serverManager: serverManager) { message in
                errorMessage = message
                showingError = true
            }
        case "Notifications":
            NotificationsSettingsTab()
        case "Advanced":
            AdvancedSettingsTab()
        default:
            EmptyView()
        }
    }
}

private struct Tab {
    let id: String
    let icon: String
    let title: String
}

struct GeneralSettingsTab: View {
    @ObservedObject var serverManager: ServerManager
    @State private var interval: String
    @State private var isEnabled: Bool
    let onError: (String) -> Void
    
    init(serverManager: ServerManager, onError: @escaping (String) -> Void) {
        self.serverManager = serverManager
        self.onError = onError
        _interval = State(initialValue: String(serverManager.autoCheckInterval))
        _isEnabled = State(initialValue: serverManager.isAutoCheckEnabled)
    }
    
    var body: some View {
        Form {
            autoCheckSection
            historySection
        }
        .formStyle(.grouped)
        .padding([.horizontal, .bottom])
        .frame(maxWidth: 600)
    }
    
    private var autoCheckSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Automatic Status Checks", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        if newValue {
                            validateAndSave()
                        }
                    }
                
                if isEnabled {
                    intervalPicker
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Status Check Settings")
                .font(.headline)
                .textCase(nil)
        } footer: {
            autoCheckFooter
        }
    }
    
    private var intervalPicker: some View {
        HStack(spacing: 16) {
            Text("Check Interval")
                .frame(width: 100, alignment: .leading)
            
            TextField("Minutes", text: $interval)
                .frame(width: 120)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .onSubmit(validateAndSave)
            
            Text("minutes")
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Spacer(minLength: 20)
        }
        .padding(.leading, 20)
    }
    
    private var autoCheckFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Servers will be automatically checked at the specified interval when enabled.")
                .foregroundStyle(.secondary)
            
            if isEnabled {
                let nextCheck = Date().addingTimeInterval(TimeInterval(Int(interval) ?? 5 * 60))
                Text("Next check: \(nextCheck, style: .relative)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
    
    private var historySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Keep History", selection: .constant(100)) {
                    Text("Last 50 checks").tag(50)
                    Text("Last 100 checks").tag(100)
                    Text("Last 200 checks").tag(200)
                }
                .pickerStyle(.radioGroup)
                .padding(.leading, 20)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Status Check History")
                .font(.headline)
                .textCase(nil)
        }
    }
    
    private func validateAndSave() {
        guard let intervalValue = Int(interval) else {
            onError("Please enter a valid number.")
            isEnabled = false
            return
        }
        
        guard intervalValue >= 1 else {
            onError("Interval must be at least 1 minute.")
            isEnabled = false
            return
        }
        
        guard intervalValue <= 60 else {
            onError("Interval cannot exceed 60 minutes.")
            isEnabled = false
            return
        }
        
        serverManager.autoCheckInterval = intervalValue
        serverManager.isAutoCheckEnabled = isEnabled
        serverManager.saveAutoCheckSettings()
    }
}

struct NotificationsSettingsTab: View {
    @State private var notificationsEnabled = true
    @State private var notifyOffline = true
    @State private var notifyOnline = true
    @State private var notifyFailure = true
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .padding(.bottom, 8)
                    
                    if notificationsEnabled {
                        notificationOptions
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Notification Settings")
                    .font(.headline)
                    .textCase(nil)
            } footer: {
                Text("You'll receive system notifications when these events occur.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding([.horizontal, .bottom])
        .frame(maxWidth: 600)
    }
    
    private var notificationOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notify when:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Server goes offline", isOn: $notifyOffline)
                Toggle("Server comes back online", isOn: $notifyOnline)
                Toggle("Status check fails", isOn: $notifyFailure)
            }
            .padding(.leading, 20)
        }
    }
}

struct AdvancedSettingsTab: View {
    @State private var useHTTPS = true
    @State private var followRedirects = true
    @State private var timeout: Double = 30
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Use HTTPS by default", isOn: $useHTTPS)
                    Toggle("Follow redirects", isOn: $followRedirects)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection timeout")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Slider(value: $timeout, in: 5...60, step: 1)
                                .frame(maxWidth: .infinity)
                            Text("\(Int(timeout))s")
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                                .font(.callout)
                                .monospacedDigit()
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Connection Settings")
                    .font(.headline)
                    .textCase(nil)
            } footer: {
                Text("These settings affect how the app connects to your servers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding([.horizontal, .bottom])
        .frame(maxWidth: 600)
    }
}

#Preview {
    SettingsView(serverManager: ServerManager())
} 
