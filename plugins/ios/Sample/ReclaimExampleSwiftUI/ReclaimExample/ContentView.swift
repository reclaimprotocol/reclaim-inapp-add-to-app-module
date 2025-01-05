//
//  ContentView.swift
//  app
//
//  Created by Mushaheed Syed on 17/10/24.
//

import SwiftUI
import ReclaimInAppSdk
import Combine
import WebKit

struct ContentView: View {
    @State private var result: ReclaimVerification.ClaimCreationProof?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var providerId: String = (Bundle.main.infoDictionary?["ReclaimProviderId"] as? String) ?? ""
    
    var body: some View {
        VStack {
            Text("Reclaim SDK Example")
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            TextField("Provider Id", text: $providerId)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Start Claim") {
                Task {
                    await startClaimCreation()
                }
            }
            .buttonStyle(BorderedProminentButtonStyle())
            
            if let result = result {
                Text("Result: \(result.response)")
                    .padding()
            }
            
            Spacer()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Claim Creation"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func startClaimCreation() async {
        do {
            let request = ReclaimVerification.Request.params(
                .init(providerId: providerId, signature: "", context: "", sessionId: "", parameters: [String: String](), debug: false, hideLanding: true, autoSubmit: false, acceptAiProviders: true)
            )
            switch (request) {
            case .params(let request):
                print("your request preview: \(request)")
            default: break
            }
            
            let result = try await ReclaimVerification.startVerification(request)
            self.result = result
        } catch ReclaimVerificationError.cancelled {
            showAlert(message: "Cancelled")
        } catch ReclaimVerificationError.dismissed {
            showAlert(message: "Cancelled by user")
        } catch ReclaimVerificationError.failed(let error) {
            print("failure error details: \(error)")
            Task { @MainActor in
                showAlert(message: "Something went wrong")
            }
        } catch {
            print("unexpected failure error details: \(error)")
            Task { @MainActor in
                showAlert(message: "An unexpected error occurred")
            }
        }
    }
    
    private func showAlert(message: LocalizedStringResource) {
        alertMessage = String(localized: message)
        showingAlert = true
    }
}

#Preview {
    ContentView()
}
