import Foundation
import SwiftUI

public extension ReclaimApiVerificationRequest {
    public init(appId: String? = nil, providerId: String, secret: String? = nil, signature: String, timestamp: String? = nil, context: String, sessionId: String, parameters: [String : String], debug: Bool, hideLanding: Bool, autoSubmit: Bool, acceptAiProviders: Bool, webhookUrl: String? = nil) {
        let sdkParam = Bundle.main.infoDictionary?["ReclaimInAppSDKParam"] as? [String : Any]
        if (appId == nil && sdkParam?["ReclaimAppId"] == nil) {
            // app id not set
        } else if (secret == nil  && sdkParam?["ReclaimAppSecret"] == nil) {
            // secret not set
        }
        self.appId = appId ?? sdkParam?["ReclaimAppId"] as! String
        self.secret = secret ?? sdkParam?["ReclaimAppSecret"] as! String

        self.providerId = providerId
        self.signature = signature
        self.timestamp = timestamp
        self.context = context
        self.sessionId = sessionId
        self.parameters = parameters
        self.debug = debug
        self.hideLanding = hideLanding
        self.autoSubmit = autoSubmit
        self.acceptAiProviders = acceptAiProviders
        self.webhookUrl = webhookUrl
    }
}

/// ReclaimVerification is the main entry point for the Reclaim SDK verification flow.
/// It provides functionality to initiate and manage the verification process.
public class ReclaimVerification {
    private init() {}
    
    private struct ReclaimClientConfiguration: Decodable {
        public let ReclaimAppId, ReclaimAppSecret: String
    }
    
    /// Request object containing all necessary parameters to start a verification process
    public enum Request {
        case params(_ request: ReclaimApiVerificationRequest)
        case url(_ url: String)
    }
    
    /// Represents the proof obtained after successful verification
    public struct ClaimCreationProof {
        /// The response containing the verification result
        public let response: ReclaimApiVerificationResponse
        // Add any other relevant properties here
    }
    
    /// Starts the verification process by presenting a full-screen verification interface
    /// - Parameter request: The verification request containing all necessary parameters
    /// - Returns: A ClaimCreationProof object containing the verification result
    /// - Throws: ReclaimVerificationError if the verification fails or is cancelled
    ///
    /// This method performs the following steps:
    /// 1. Sets up logging and consumer identity for the verification session
    /// 2. Creates and initializes the verification UI and view model
    /// 3. Presents a full-screen modal interface for the verification process
    /// 4. Returns the verification proof when the process completes successfully
    ///
    /// The verification flow is handled asynchronously and the method will only return once
    /// the verification is complete or an error occurs. The UI is automatically dismissed
    /// when the process finishes.
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     let request = try ReclaimVerification.Request(providerId: "google-login")
    ///     let proof = try await ReclaimVerification.startVerification(request)
    ///     // Handle successful verification
    /// } catch {
    ///     // Handle verification error
    /// }
    /// ```
    @MainActor
    public static func startVerification(_ request: Request) async throws -> ClaimCreationProof {
        // Initialize logger for debugging and tracking
        let logger = Logging.get("ReclaimVerification.startVerification")
        
        // Create the view model and UI screen for verification
        let viewModel = ClaimCreationViewModel(request)
        let claimCreationScreen = ClaimCreationScreen(viewModel: viewModel)
        
        logger.log("started initialization")
        
        // Initialize the view model asynchronously
        Task { @MainActor in
            await viewModel.initialize()
        }
        
        // Use continuation to handle the asynchronous UI flow
        return try await withCheckedThrowingContinuation { continuation in
            // Get the current window to present the verification UI
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                continuation.resume(throwing: ReclaimVerificationError.failed(reason: "Could not open claim creation window"))
                return
            }
            
            // Create and configure the hosting controller for the SwiftUI view
            let hostingController = UIHostingController(rootView: claimCreationScreen)
            hostingController.modalPresentationStyle = .fullScreen
            
            // Set up completion handler to dismiss UI and return result
            viewModel.onCompletion = { [weak hostingController] result in
                Task { @MainActor in
                    hostingController?.dismiss(animated: true)
                    continuation.resume(with: result)
                }
            }
            
            // Present the verification UI
            window.rootViewController?.present(hostingController, animated: true)
            logger.log("started client webview")
        }
    }
}

/// Errors that can occur during the verification process
public enum ReclaimVerificationError: Error {
    /// The user cancelled the verification process
    case cancelled
    case dismissed
    case sessionExpired
    /// The verification failed with the specified reason
    case failed(reason: String)
}
