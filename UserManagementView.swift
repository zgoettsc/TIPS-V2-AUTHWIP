//
//  UserManagementView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//


import SwiftUI
import FirebaseDatabase

struct UserManagementView: View {
    @ObservedObject var appData: AppData
    @State private var users: [User] = []
    @State private var pendingInvitations: [String: [String: Any]] = [:]
    @State private var isShowingInviteSheet = false
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading users...")
            } else {
                List {
                    Section(header: Text("Current Users")) {
                        ForEach(users) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.isAdmin ? "Admin" : "Regular User")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Menu {
                                    Button(action: {
                                        toggleAdminStatus(user)
                                    }) {
                                        Label(user.isAdmin ? "Remove Admin" : "Make Admin", 
                                              systemImage: user.isAdmin ? "person.fill.badge.minus" : "person.fill.badge.plus")
                                    }
                                    
                                    Button(action: {
                                        removeUser(user)
                                    }) {
                                        Label("Remove User", systemImage: "trash")
                                    }
                                    .foregroundColor(.red)
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Pending Invitations")) {
                        if pendingInvitations.isEmpty {
                            Text("No pending invitations")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(pendingInvitations.keys), id: \.self) { code in
                                if let invitation = pendingInvitations[code] {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Code: \(code)")
                                                .font(.headline)
                                            
                                            if let phone = invitation["phoneNumber"] as? String {
                                                Text(phone)
                                                    .font(.subheadline)
                                            }
                                            
                                            Text(invitation["isAdmin"] as? Bool == true ? "Admin" : "Regular User")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text("Status: \(invitation["status"] as? String ?? "Unknown")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            resendInvitation(code, invitation: invitation)
                                        }) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                        }
                                        
                                        Button(action: {
                                            deleteInvitation(code)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button(action: {
                            isShowingInviteSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Invite New User")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Users")
        .onAppear(perform: loadData)
        .sheet(isPresented: $isShowingInviteSheet) {
            NavigationView {
                InviteUserView(appData: appData, onComplete: loadData)
            }
        }
    }
    
    func loadData() {
        guard let dbRef = Database.database().reference(),
              let currentRoomId = UserDefaults.standard.string(forKey: "currentRoomId") else { return }
        
        isLoading = true
        users = []
        pendingInvitations = [:]
        
        // Load all users with access to this room
        dbRef.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let usersData = snapshot.value as? [String: [String: Any]] else {
                isLoading = false
                return
            }
            
            for (userId, userData) in usersData {
                if let roomAccess = userData["roomAccess"] as? [String: Bool],
                   roomAccess[currentRoomId] == true,
                   var user = User(dictionary: userData) {
                    users.append(user)
                }
            }
            
            // Now load pending invitations for this room
            dbRef.child("invitations").observeSingleEvent(of: .value) { snapshot in
                guard let invitationsData = snapshot.value as? [String: [String: Any]] else {
                    isLoading = false
                    return
                }
                
                for (code, invitationData) in invitationsData {
                    if let roomId = invitationData["roomId"] as? String,
                       roomId == currentRoomId,
                       let status = invitationData["status"] as? String,
                       status != "accepted" {
                        pendingInvitations[code] = invitationData
                    }
                }
                
                isLoading = false
            }
        }
    }
    
    func toggleAdminStatus(_ user: User) {
        guard let dbRef = Database.database().reference() else { return }
        
        let updatedAdmin = !user.isAdmin
        dbRef.child("users").child(user.id.uuidString).child("isAdmin").setValue(updatedAdmin) { error, _ in
            if error == nil {
                if let index = users.firstIndex(where: { $0.id == user.id }) {
                    users[index].isAdmin = updatedAdmin
                }
            }
        }
    }
    
    func removeUser(_ user: User) {
        guard let dbRef = Database.database().reference(),
              let currentRoomId = UserDefaults.standard.string(forKey: "currentRoomId") else { return }
        
        // Remove room access for this user
        dbRef.child("users").child(user.id.uuidString).child("roomAccess").child(currentRoomId).removeValue { error, _ in
            if error == nil {
                if let index = users.firstIndex(where: { $0.id == user.id }) {
                    users.remove(at: index)
                }
            }
        }
    }
    
    func deleteInvitation(_ code: String) {
        guard let dbRef = Database.database().reference() else { return }
        
        dbRef.child("invitations").child(code).removeValue { error, _ in
            if error == nil {
                pendingInvitations.removeValue(forKey: code)
            }
        }
    }
    
    func resendInvitation(_ code: String, invitation: [String: Any]) {
        if let phoneNumber = invitation["phoneNumber"] as? String {
            // Show message composer with pre-populated text
            let appStoreLink = "https://testflight.apple.com/join/W93z4G4W" // Replace with your actual link
            let messageBody = "You've been invited to use the TIPs App! Download here: \(appStoreLink) and use invitation code: \(code)"
            
            // Update invitation status
            guard let dbRef = Database.database().reference() else { return }
            dbRef.child("invitations").child(code).child("status").setValue("sent")
            
            // Update local state
            if var updatedInvitation = pendingInvitations[code] {
                updatedInvitation["status"] = "sent"
                pendingInvitations[code] = updatedInvitation
            }
        }
    }
}
