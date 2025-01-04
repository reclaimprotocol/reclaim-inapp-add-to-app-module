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
    var body: some View {
        NavigationStack {
          NavigationLink("My Flutter Feature") {
              FlutterViewControllerRepresentable()
          }
        }
      }
}

//
//struct ContentView: View {
//    @State private var result: ReclaimVerification.ClaimCreationProof?
//    @State private var showingAlert = false
//    @State private var alertMessage = ""
//    @State private var providerId: String = (Bundle.main.infoDictionary?["ReclaimProviderId"] as? String) ?? ""
//    
//    var body: some View {
//        VStack {
//            Text("Reclaim SDK Example")
//                .font(.largeTitle)
//                .padding()
//            
//            Spacer()
//            
//            TextField("Provider Id", text: $providerId)
//                .multilineTextAlignment(.center)
//                .padding()
//            
//            Button("Start Claim") {
//                Task {
//                    await startClaimCreation()
//                }
//            }
//            .buttonStyle(BorderedProminentButtonStyle())
//            
//            if let result = result {
//                Text("Result: \(result.currentUrl)")
//                    .padding()
//            }
//
//            Button("Start Sample Attestor Claim") {
//                Task { @MainActor in
//                    await startSampleAttestorProofCreation()
//                }
//            }
//            .padding(.top, 10)
//            .buttonStyle(BorderedButtonStyle())
//
//            Button("Reload Attestor") {
//                Task { @MainActor in
//                    await reloadAttestor()
//                }
//            }
//            .padding(.top, 10)
//            .buttonStyle(BorderlessButtonStyle())
//
//            Spacer()
//        }
//        .onAppear {
//            Task { @MainActor in
//                await initializeAttestor()
//            }
//        }
//        .alert(isPresented: $showingAlert) {
//            Alert(title: Text("Claim Creation"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
//        }
//    }
//    
//    func startClaimCreation() async {
//        do {
//            let request = try ReclaimVerification.Request(
//                providerId: providerId
//            )
//            print("your request preview: providerId: \(request.providerId), appId: \(request.appId), appSecret: \(request.appSecret)")
//            let result = try await ReclaimVerification.startVerification(request)
//            self.result = result
//        } catch ReclaimVerificationError.cancelled {
//            showAlert(message: "Cancelled by user")
//        } catch ReclaimVerificationError.failed(let error) {
//            print("failure error details: \(error)")
//            Task { @MainActor in
//                showAlert(message: "Something went wrong")
//            }
//        } catch {
//            print("unexpected failure error details: \(error)")
//            Task { @MainActor in
//                showAlert(message: "An unexpected error occurred")
//            }
//        }
//    }
//    
//    func reloadAttestor() async {
//        do {
//            try await Attestor.shared.reload()
//            print("Attestor reload complete")
//        } catch {
//            print("Attestor reload failed: \(error)")
//        }
//    }
//    
//    func initializeAttestor() async {
//        do {
//            let _ = try await Attestor.shared
//            showAlert(message: "Attestor initialized successfully")
//        } catch {
//            print("Attestor failed: \(error)")
//            showAlert(message: "Attestor could not be initialized")
//        }
//        
//    }
//    
//    func startSampleAttestorProofCreation() async {
//        do {
//            try await Attestor.shared.setAttestorLogLevel()
//            let value = try SampleAttestorClaimCreationRequest.getSampleClaimCreationRequest()
//            let result = try await Attestor.shared.createClaim(fromDictionary: value) { update in
//                print("Received claim creation update: \(String(describing: update))")
//            }
//            print("proof result \(result)")
//            showAlert(message: "Proof created successfully")
//        } catch (let error) {
//            print("Failed attestor create claim \(error)")
//        }
//    }
//    
//    private func showAlert(message: LocalizedStringResource) {
//        alertMessage = String(localized: message)
//        showingAlert = true
//    }
//}

#Preview {
    ContentView()
}
