import SwiftUI

struct SignupTestView: View {
    @State private var output: String = ""
    @State private var isLoading: Bool = false
    @State private var baseURL: String = "192.168.1.9:54321/functions/v1"
    @State private var apiKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    @State private var jwt: String = ""
    
    @State private var uuid: String = UUID().uuidString
    @State private var name: String = ""
    @State private var nickname: String = ""
    @State private var info: String = ""
    @State private var color: String = ""
    @State private var memberID: String = ""
    @State private var inviteCode: String = ""
    
    @State private var currentLoadingButton: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // API Key and JWT fields
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.headline)
                    TextField("Base URL (e.g., 127.0.0.1:54321/functions/v1)", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Text("⚠️ For physical device: Use your Mac's IP (e.g., 192.168.1.100:54321/functions/v1)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("API Key")
                        .font(.headline)
                    TextField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("JWT Token")
                        .font(.headline)
                    TextField("JWT Token", text: $jwt)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Get JWT from Anonymous Signup") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                let authBaseURL = baseURL.replacingOccurrences(of: "/functions/v1", with: "")
                                let result = try await AuthAPI.signupAnonymous(baseURL: authBaseURL)
                                if
                                    let data = result.body.data(using: .utf8),
                                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                    let token = json["access_token"] as? String {
                                    jwt = token
                                    output = formatResponse(statusCode: result.statusCode, body: result.body)
                                } else {
                                    output = formatResponse(statusCode: result.statusCode, body: result.body)
                                }
                            } catch {
                                output = formatError(error)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
                
                Divider()
                
                // Input fields
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Fields")
                        .font(.headline)
                    
                    HStack {
                        TextField("UUID", text: $uuid)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            uuid = UUID().uuidString
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Nickname (comma-separated)", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Info", text: $info)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Color", text: $color)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Member ID", text: $memberID)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Invite Code", text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                
                // API Buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Family API Endpoints")
                        .font(.headline)
                    
                    Button("Create Family") {
                        callCreateFamily()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Get Family") {
                        callGetFamily()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Create Invite") {
                        callCreateInvite()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Join Family") {
                        callJoinFamily()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Leave Family") {
                        callLeaveFamily()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Add Member") {
                        callAddMember()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Edit Member") {
                        callEditMember()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                    
                    Button("Delete Member") {
                        callDeleteMember()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || currentLoadingButton != nil)
                }
                
                Divider()
                
                // Output
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.headline)
                    
                    ScrollView {
                        Text(output.isEmpty ? "No output yet." : output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 500)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    private func formatError(_ error: Error) -> String {
        let errorMsg = error.localizedDescription
        if errorMsg.contains("1004") || errorMsg.contains("Connection refused") || errorMsg.contains("61") || errorMsg.contains("Could not connect") {
            return """
            Error: Connection Refused
            
            This usually means:
            1. Your Supabase server is not running
            2. You're on a physical device using 127.0.0.1 (use your Mac's IP instead)
            3. Device and Mac are not on the same WiFi network
            
            To find your Mac's IP:
            - Open Terminal and run: ifconfig | grep "inet " | grep -v 127.0.0.1
            - Or: System Settings → Network → Wi-Fi → Details
            
            Then update Base URL to: YOUR_IP:54321/functions/v1
            Example: 192.168.1.100:54321/functions/v1
            
            Original error: \(errorMsg)
            """
        } else {
            return "Error: \(errorMsg)"
        }
    }
    
    private func formatResponse(statusCode: Int, body: String) -> String {
        var formattedOutput = "Status: \(statusCode)\n\n"
        
        // Try to pretty print JSON
        if !body.isEmpty,
           let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            formattedOutput += "Body:\n\(prettyString)"
        } else {
            // If not valid JSON or empty, just show the raw body
            if body.isEmpty {
                formattedOutput += "Body: (empty)"
            } else {
                formattedOutput += "Body:\n\(body)"
            }
        }
        
        return formattedOutput
    }
    
    private func callCreateFamily() {
        guard !jwt.isEmpty, !name.isEmpty, !color.isEmpty, !uuid.isEmpty else {
            output = "Error: JWT, name, color, and UUID are required"
            return
        }
        
        currentLoadingButton = "createFamily"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let nicknames = nickname.isEmpty ? [] : nickname.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var selfMember: [String: Any] = [
                    "id": uuid,
                    "name": name,
                    "nicknames": nicknames,
                    "color": color
                ]
                if !info.isEmpty {
                    selfMember["info"] = info
                }
                
                let result = try await FamilyAPI.createFamily(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    name: name,
                    selfMember: selfMember
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callGetFamily() {
        guard !jwt.isEmpty else {
            output = "Error: JWT is required"
            return
        }
        
        currentLoadingButton = "getFamily"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let result = try await FamilyAPI.getFamily(baseURL: baseURL, apiKey: apiKey, jwt: jwt)
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callCreateInvite() {
        guard !jwt.isEmpty, !memberID.isEmpty else {
            output = "Error: JWT and memberID are required"
            return
        }
        
        currentLoadingButton = "createInvite"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let result = try await FamilyAPI.createInvite(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    memberID: memberID
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callJoinFamily() {
        guard !jwt.isEmpty, !inviteCode.isEmpty else {
            output = "Error: JWT and inviteCode are required"
            return
        }
        
        currentLoadingButton = "joinFamily"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let result = try await FamilyAPI.joinFamily(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    inviteCode: inviteCode
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callLeaveFamily() {
        guard !jwt.isEmpty else {
            output = "Error: JWT is required"
            return
        }
        
        currentLoadingButton = "leaveFamily"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let result = try await FamilyAPI.leaveFamily(baseURL: baseURL, apiKey: apiKey, jwt: jwt)
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callAddMember() {
        guard !jwt.isEmpty, !name.isEmpty, !color.isEmpty, !uuid.isEmpty else {
            output = "Error: JWT, name, color, and UUID are required"
            return
        }
        
        currentLoadingButton = "addMember"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let nicknames = nickname.isEmpty ? [] : nickname.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var member: [String: Any] = [
                    "id": uuid,
                    "name": name,
                    "nicknames": nicknames,
                    "color": color
                ]
                if !info.isEmpty {
                    member["info"] = info
                }
                
                let result = try await FamilyAPI.addMember(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    member: member
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
    
    private func callEditMember() {
        guard !jwt.isEmpty, !name.isEmpty, !color.isEmpty, !memberID.isEmpty else {
            output = "Error: JWT, name, color, and memberID are required"
            return
        }
        
        currentLoadingButton = "editMember"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let nicknames = nickname.isEmpty ? [] : nickname.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                var member: [String: Any] = [
                    "id": uuid,
                    "name": name,
                    "nicknames": nicknames,
                    "color": color
                ]
                if !info.isEmpty {
                    member["info"] = info
                }
                
                let result = try await FamilyAPI.editMember(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    memberID: memberID,
                    member: member
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func callDeleteMember() {
        guard !jwt.isEmpty, !memberID.isEmpty else {
            output = "Error: JWT and memberID are required"
            return
        }
        
        currentLoadingButton = "deleteMember"
        Task {
            isLoading = true
            defer {
                isLoading = false
                currentLoadingButton = nil
            }
            
            do {
                let result = try await FamilyAPI.deleteMember(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    jwt: jwt,
                    memberID: memberID
                )
                output = formatResponse(statusCode: result.statusCode, body: result.body)
            } catch {
                output = formatError(error)
            }
        }
    }
}

struct SignupTestView_Previews: PreviewProvider {
    static var previews: some View {
        SignupTestView()
    }
}


