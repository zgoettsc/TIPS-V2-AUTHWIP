//
//  InvitationCodeView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//


import SwiftUI
import FirebaseDatabase

struct InvitationCodeView: View {
    @ObservedObject var appData: AppData
    @State private var invitationCode: String = ""
    @State private var name: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter your invitation details")) {
                    TextField("Invitation Code", text: $invitationCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                    
                    TextField("Your Name", text: $name)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: validateInvitation) {
                        if isValidating {
                            ProgressView()
                        } else {
                            Text("Join Room")
                        }
                    }
                    .disabled(invitationCode.isEmpty || name.isEmpty || isValidating)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Join with Invitation")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
    }
    
    func validateInvitation() {
        let dbRef = Database.database().reference()
        isValidating = true
        errorMessage = nil
        
        dbRef.child("invitations").child(invitationCode).observeSingleEvent(of: .value) { snapshot in
            if let invitation = snapshot.value as? [String: Any],
               let status = invitation["status"] as? String,
               status == "invited" || status == "sent" {
                
                // Create a new user
                let userId = UUID()
                let newUser = User(
                    id: userId,
                    name: name,
                    isAdmin: invitation["isAdmin"] as? Bool ?? false
                )
                
                // Get the room access
                if let roomId = invitation["roomId"] as? String {
                    // Add user to system
                    dbRef.child("users").child(userId.uuidString).setValue(newUser.toDictionary())
                    
                    // Give room access
                    dbRef.child("users").child(userId.uuidString).child("roomAccess").child(roomId).setValue(true)
                    
                    // Mark invitation as used
                    dbRef.child("invitations").child(invitationCode).child("status").setValue("accepted")
                    dbRef.child("invitations").child(invitationCode).child("acceptedBy").setValue(userId.uuidString)
                    
                    // Set as current user
                    appData.currentUser = newUser
                    UserDefaults.standard.set(userId.uuidString, forKey: "currentUserId")
                    UserDefaults.standard.set(roomId, forKey: "currentRoomId")
                    
                    // Dismiss and proceed to app
                    dismiss()
                } else {
                    errorMessage = "Invalid invitation: No room access specified."
                    isValidating = false
                }
            } else {
                errorMessage = "Invalid or expired invitation code."
                isValidating = false
            }
        }
    }
}
