import Foundation
import SwiftUI
import Network

@MainActor
class ServerManager: ObservableObject {
    @Published var servers: [Server] = []
    @Published var autoCheckInterval: Int = 5 // Default 5 minutes
    @Published var isAutoCheckEnabled: Bool = false
    
    private var autoCheckTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private let serversKey = "savedServers"
    private let autoCheckIntervalKey = "autoCheckInterval"
    private let autoCheckEnabledKey = "autoCheckEnabled"
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = false
    private var networkContinuation: CheckedContinuation<Void, Never>?
    
    init() {
        loadServers()
        loadAutoCheckSettings()
        setupAutoCheck()
        
        // Setup network monitoring and initial check
        Task {
            await setupNetworkMonitoring()
            await checkAllServers()
        }
    }
    
    private func setupNetworkMonitoring() async {
        await withCheckedContinuation { continuation in
            networkContinuation = continuation
            
            monitor.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isNetworkAvailable = path.status == .satisfied
                    print("Network status updated: \(self.isNetworkAvailable ? "Available" : "Not Available")")
                    
                    // Complete the continuation when network becomes available
                    if self.isNetworkAvailable, let cont = self.networkContinuation {
                        self.networkContinuation = nil
                        cont.resume()
                    }
                }
            }
            
            monitor.start(queue: DispatchQueue.global())
            
            // If network is already available, resume immediately
            if monitor.currentPath.status == .satisfied {
                isNetworkAvailable = true
                networkContinuation = nil
                continuation.resume()
            }
        }
    }
    
    private func loadAutoCheckSettings() {
        autoCheckInterval = userDefaults.integer(forKey: autoCheckIntervalKey)
        if autoCheckInterval == 0 { autoCheckInterval = 5 } // Default if not set
        
        isAutoCheckEnabled = userDefaults.bool(forKey: autoCheckEnabledKey)
    }
    
    func saveAutoCheckSettings() {
        userDefaults.set(autoCheckInterval, forKey: autoCheckIntervalKey)
        userDefaults.set(isAutoCheckEnabled, forKey: autoCheckEnabledKey)
        setupAutoCheck()
    }
    
    private func setupAutoCheck() {
        // Cancel existing timer if any
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil
        
        // Setup new timer if enabled
        if isAutoCheckEnabled {
            // Perform initial check immediately
            Task {
                await checkAllServers()
            }
            
            // Schedule timer for subsequent checks
            autoCheckTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoCheckInterval * 60), repeats: true) { [weak self] _ in
                Task {
                    await self?.checkAllServers()
                }
            }
            
            // Make sure the timer is added to the main run loop
            RunLoop.main.add(autoCheckTimer!, forMode: .common)
        }
    }
    
    deinit {
        autoCheckTimer?.invalidate()
    }
    
    func addServer(_ server: Server) {
        servers.append(server)
        saveServers()
        objectWillChange.send()
    }
    
    func removeServer(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        saveServers()
        objectWillChange.send()
    }
    
    func updateServer(at index: Int, with server: Server) {
        print("ServerManager: Updating server at index \(index)")
        print("ServerManager: Old server domain: \(servers[index].domain)")
        print("ServerManager: New server domain: \(server.domain)")
        servers[index] = server
        print("ServerManager: Server updated, saving servers")
        saveServers()
        print("ServerManager: Servers saved")
        objectWillChange.send()
    }
    
    @MainActor
    func checkAllServers() async {
        objectWillChange.send()
        for server in servers {
            _ = await checkServer(server)
        }
        saveServers()
    }
    
    @MainActor
    func checkServer(_ server: Server) async -> String? {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            // Update UI to show checking status
            var checkingServer = servers[index]
            checkingServer.isOnline = nil
            checkingServer.lastChecked = Date()
            
            // Update the array and notify observers
            objectWillChange.send()
            servers[index] = checkingServer
            saveServers()
            
            // Check server status
            let (isOnline, statusCode) = await checkServerStatus(server: server)
            
            // Create a new status check
            let statusCheck = ServerStatusCheck(
                timestamp: Date(),
                statusCode: statusCode ?? 0,
                isOnline: isOnline
            )
            
            // Create a new server with updated status
            var updatedServer = servers[index] // Get fresh copy in case array changed
            updatedServer.isOnline = isOnline
            updatedServer.lastChecked = Date()
            updatedServer.statusHistory.append(statusCheck)
            
            // Keep only the last 100 status checks
            if updatedServer.statusHistory.count > 100 {
                updatedServer.statusHistory.removeFirst(updatedServer.statusHistory.count - 100)
            }
            
            // Update the array and notify observers
            objectWillChange.send()
            servers[index] = updatedServer
            saveServers()
            
            // Return error message if server is offline
            if !isOnline {
                return "Could not connect to server. Please check the domain name and try again."
            }
        }
        return nil
    }
    
    private func checkServerStatus(server: Server) async -> (Bool, Int?) {
        guard isNetworkAvailable else {
            print("Network is not available")
            return (false, nil)
        }
        
        var urlString = server.formattedDomain
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return (false, nil)
        }
        
        print("Checking server status for: \(url)")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Server: \(server.domain) - Status Code: \(httpResponse.statusCode) (URL: \(url))")
                let isSuccess = (200...299).contains(httpResponse.statusCode)
                return (isSuccess, httpResponse.statusCode)
            }
        } catch let error as URLError {
            let errorMessage: String
            switch error.code {
            case .cannotFindHost:
                errorMessage = "A server with the specified hostname could not be found"
            case .notConnectedToInternet:
                errorMessage = "Not connected to the internet"
            case .timedOut:
                errorMessage = "The connection timed out"
            case .cannotConnectToHost:
                errorMessage = "Could not connect to the server"
            case .secureConnectionFailed:
                // Try HTTP if HTTPS fails
                if urlString.lowercased().hasPrefix("https") {
                    let httpUrl = urlString.replacingOccurrences(of: "https://", with: "http://")
                    guard let url = URL(string: httpUrl) else {
                        return (false, nil)
                    }
                    do {
                        let (_, response) = try await session.data(from: url)
                        if let httpResponse = response as? HTTPURLResponse {
                            print("Server: \(server.domain) - Status Code: \(httpResponse.statusCode) (URL: \(url))")
                            let isSuccess = (200...299).contains(httpResponse.statusCode)
                            return (isSuccess, httpResponse.statusCode)
                        }
                    } catch {
                        print("HTTP fallback failed: \(error.localizedDescription)")
                    }
                }
                errorMessage = "Secure connection failed"
            default:
                errorMessage = error.localizedDescription
            }
            print("Error checking \(server.domain): \(errorMessage)")
            return (false, nil)
        } catch {
            print("Error checking \(server.domain): \(error.localizedDescription)")
            return (false, nil)
        }
        
        return (false, nil)
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            userDefaults.set(encoded, forKey: serversKey)
        }
    }
    
    private func loadServers() {
        if let data = userDefaults.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([Server].self, from: data) {
            servers = decoded
        }
    }
} 
