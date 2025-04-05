import Foundation
import SwiftUI

struct ServerStatusCheck: Identifiable, Codable, Hashable {
    var id = UUID()
    var timestamp: Date
    var statusCode: Int
    var isOnline: Bool
}

struct Server: Identifiable, Codable, Hashable {
    let id: UUID
    let domain: String
    let expectedStatusCode: Int
    var isOnline: Bool?
    var lastChecked: Date?
    var statusHistory: [ServerStatusCheck]
    
    init(domain: String, expectedStatusCode: Int) {
        self.id = UUID()
        self.domain = domain
        self.expectedStatusCode = expectedStatusCode
        self.isOnline = nil
        self.lastChecked = nil
        self.statusHistory = []
    }
    
    var formattedDomain: String {
        if domain.hasPrefix("http://") || domain.hasPrefix("https://") {
            return domain
        }
        return "https://" + domain
    }
    
    var lastStatusCheck: ServerStatusCheck? {
        statusHistory.last
    }
    
    var statusText: String {
        if let isOnline = isOnline {
            return isOnline ? "Online" : "Offline"
        }
        return "Not Checked"
    }
    
    var statusColor: Color {
        if let isOnline = isOnline {
            return isOnline ? .green : .red
        }
        return .gray
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
    }
} 