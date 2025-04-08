//
//  InviteUserView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//


import SwiftUI
import MessageUI
import FirebaseDatabase

struct InviteUserView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @State private var phoneNumber = ""
    @State private var isAdmin = false
    @State private var invitationCode = ""
    @State private var isShowingMessageComposer = false
    @State private var isGeneratingCode = false
    var onComplete: () -> Void
    
    var body: some View {
        Form {
            Section(header: Text("User Information")) {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                
                Toggle("Admin Privileges", isOn: $isAdmin)
            }
            
            Section(header: Text("Invitation Details"), footer: Text("A 6-character code will be generated and sent via SMS")) {
                if !invitationCode.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Code Generated:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(invitationCode)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: generateAndSendInvitation) {
                    if isGeneratingCode {
                        ProgressView()
                    } else if invitationCode.isEmpty {
                        Text("Generate Invitation Code")
                    } else {
                        Text("Send Text Message")
                    }
                }
                .disabled(phoneNumber.isEmpty || isGeneratingCode)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Invite User")
        .navigationBarItems(leading: Button("Cancel") { dismiss() })
        .sheet(isPresented: $isShowingMessageComposer) {
            MessageComposeView(
                recipients: [phoneNumber],
                body: createMessageBody(),
                isShowing: $isShowingMessageComposer,
                completion: handleMessageCompletion
            )
        }
    }
    
    func generateAndSendInvitation() {
        if invitationCode.isEmpty {
            generateInvitationCode()
        } else {
            isShowingMessageComposer = true
        }
    }
    
    func generateInvitationCode() {
        guard let dbRef = Database.database().reference(),
              let currentRoomId = UserDefaults.standard.string(forKey: "currentRoomId"),
              let currentUser = appData.currentUser else { return }
        
        isGeneratingCode = true
        
        // Generate a random 6-character alphanumeric code
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomCode = String((0..<6).map { _ in characters.randomElement()! })
        
        // Create invitation data
        let invitation = [
            "phoneNumber": phoneNumber,
            "isAdmin": isAdmin,
            "roomId": currentRoomId,
            "createdBy": currentUser.id.uuidString,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "expiryDate": ISO8601DateFormatter().string(from: Date().addingTimeInterval(7*24*3600)), // 7 days
            "status": "created"
        ]
        
        // Save to Firebase
        dbRef.child("invitations").child(randomCode).setValue(invitation) { error, _ in
            isGeneratingCode = false
            
            if error == nil {
                invitationCode = randomCode
            }
        }
    }
    
    func createMessageBody() -> String {
        let appStoreLink = "https://testflight.apple.com/join/W93z4G4W" // Replace with your actual link
        return "You've been invited to use the TIPs App! Download here: \(appStoreLink) and use invitation code: \(invitationCode)"
    }
    
    func handleMessageCompletion(_ result: MessageComposeResult) {
        // Update invitation status based on message result
        guard let dbRef = Database.database().reference() else { return }
        
        switch result {
        case .sent:
            dbRef.child("invitations").child(invitationCode).child("status").setValue("sent")
            dismiss()
            onComplete()
        case .failed:
            dbRef.child("invitations").child(invitationCode).child("status").setValue("failed")
        case .cancelled:
            break // Do nothing, keep the invitation as is
        @unknown default:
            break
        }
    }
}

// Message Compose View Helper
struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    @Binding var isShowing: Bool
    var completion: (MessageComposeResult) -> Void
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposeView
        
        init(_ parent: MessageComposeView) {
            self.parent = parent
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            parent.isShowing = false
            parent.completion(result)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        if !MFMessageComposeViewController.canSendText() {
            // SMS services are not available
            let alert = UIAlertController(
                title: "SMS Not Available",
                message: "Your device cannot send text messages.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            return alert
        }
        
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}