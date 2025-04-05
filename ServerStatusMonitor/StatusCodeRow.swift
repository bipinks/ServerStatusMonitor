import SwiftUI

struct StatusCodeRow: View {
    let code: String
    let description: String
    
    var body: some View {
        HStack {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 50, alignment: .leading)
            
            Text(description)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack {
        StatusCodeRow(code: "200", description: "OK")
        StatusCodeRow(code: "404", description: "Not Found")
        StatusCodeRow(code: "500", description: "Internal Server Error")
    }
    .padding()
} 