import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var serverManager: ServerManager
    
    @State private var domain: String = ""
    @State private var expectedStatusCode: String = "200"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Server Details Section
            GroupBox(label: Text("Server Details").font(.headline)) {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Domain")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("example.com", text: $domain)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Status Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("200", text: $expectedStatusCode)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: expectedStatusCode) { newValue in
                                // Only allow numeric input
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    expectedStatusCode = filtered
                                }
                            }
                    }
                }
                .padding()
            }
            
            // Common Status Codes Section
            GroupBox(label: Text("Common Status Codes").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    StatusCodeRow(code: "200", description: "OK")
                    StatusCodeRow(code: "201", description: "Created")
                    StatusCodeRow(code: "204", description: "No Content")
                    StatusCodeRow(code: "404", description: "Not Found")
                    StatusCodeRow(code: "500", description: "Internal Server Error")
                }
                .padding()
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Add") {
                    addServer()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(domain.isEmpty || expectedStatusCode.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 500)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addServer() {
        // Validate domain
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDomain.isEmpty else {
            errorMessage = "Domain cannot be empty"
            showingError = true
            return
        }
        
        // Validate status code
        guard let statusCode = Int(expectedStatusCode),
              (100...599).contains(statusCode) else {
            errorMessage = "Status code must be between 100 and 599"
            showingError = true
            return
        }
        
        // Add the server
        let server = Server(domain: trimmedDomain, expectedStatusCode: statusCode)
        serverManager.addServer(server)
        dismiss()
    }
}

#Preview {
    AddServerView(serverManager: ServerManager())
} 