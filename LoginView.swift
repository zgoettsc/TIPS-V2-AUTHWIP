//
//  LoginView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//


import SwiftUI
import FirebaseDatabase

struct LoginView: View {
    @ObservedObject var appData: AppData
    @State private var userId: String = ""
    @State private var selectedRoom: String?
    @State private var availableRooms: [String: String] = [:] // [roomId: roomName]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    // Check for saved user ID
    var savedUserId: String? {
        UserDefaults.standard.string(forKey: "currentUserId")
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let savedId = savedUserId {
                    // User has logged in before
                    Section {
                        Text("Welcome back!")
                        Text("Select a room to continue:")
                    }
                    
                    Section(header: Text("Your Rooms")) {
                        ForEach(Array(availableRooms.keys), id: \.self) { roomId in
                            Button(action: {
                                selectRoom(roomId)
                            }) {
                                Text(availableRooms[roomId] ?? "Unnamed Room")
                            }
                        }
                    }
                } else {
                    // No saved user - this shouldn't normally happen
                    // but could occur if user deleted app data
                    Section {
                        Text("No saved login found.")
                        Text("Please use an invitation code to join a room.")
                    }
                    
                    Button("Use Invitation Code") {
                        dismiss()
                        // Show invitation code entry
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .onAppear(perform: loadUserData)
        }
    }
    
    func loadUserData() {
        guard let dbRef = Database.database().reference(),
              let userId = savedUserId else {
            errorMessage = "No saved login found."
            return
        }
        
        isLoading = true
        
        // Load user info
        dbRef.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if let userData = snapshot.value as? [String: Any] {
                // User exists, load their rooms
                if let roomAccess = userData["roomAccess"] as? [String: Bool] {
                    // Load room details for each accessible room
                    let group = DispatchGroup()
                    
                    for (roomId, hasAccess) in roomAccess where hasAccess {
                        group.enter()
                        dbRef.child("rooms").child(roomId).observeSingleEvent(of: .value) { roomSnapshot in
                            if let roomData = roomSnapshot.value as? [String: Any] {
                                let roomName = roomData["name"] as? String ?? "Unnamed Room"
                                availableRooms[roomId] = roomName
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        if availableRooms.isEmpty {
                            errorMessage = "You don't have access to any rooms."
                        }
                        isLoading = false
                    }
                } else {
                    errorMessage = "No room access found for your account."
                    isLoading = false
                }
            } else {
                errorMessage = "Your account could not be found."
                isLoading = false
            }
        }
    }
    
    func selectRoom(_ roomId: String) {
        guard let userId = savedUserId,
              let dbRef = Database.database().reference() else { return }
        
        // Set as current room
        UserDefaults.standard.set(roomId, forKey: "currentRoomId")
        
        // Load user data
        dbRef.child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
            if let userData = snapshot.value as? [String: Any],
               var user = User(dictionary: userData) {
                appData.currentUser = user
                dismiss()
                // Continue to app main view
            }
        }
    }
}