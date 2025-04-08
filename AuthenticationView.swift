//
//  AuthenticationView.swift
//  TIPsApp
//
//  Created by Zack Goettsche on 4/8/25.
//


import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var appData: AppData
    @State private var showingLoginView = false
    @State private var showingInvitationView = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image("app_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
            
            Text("Welcome to TIPs App")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your daily progress and food consumption")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    showingLoginView = true
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingInvitationView = true
                }) {
                    Text("I Have an Invitation Code")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingLoginView) {
            LoginView(appData: appData)
        }
        .sheet(isPresented: $showingInvitationView) {
            InvitationCodeView(appData: appData)
        }
    }
}