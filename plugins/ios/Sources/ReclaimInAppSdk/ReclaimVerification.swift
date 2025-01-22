import Foundation
import SwiftUI

/// The session that sdk will use for a verification attempt. If nil, sdk will generate a new session information internally.
public struct ReclaimSessionInformation {
    let timestamp: String
    let sessionId: String
    let signature: String
}

public extension ReclaimApiVerificationRequest {
    /// Create a Reclaim Verification Request with appId and secret. This is used to start a reclaim verification process.
    ///
    /// See also:
    ///  - [ReclaimVerification() initializer]: Another initializer where [appId] and [secret] is retreived from Info.plist file.
    public init(
        /// If not provided, sdk will look for an appId from ReclaimInAppSDKParam.ReclaimAppId in Info.plist
        appId: String,
        /// Your Reclaim application's secret. If null, sdk will look for the secret from ReclaimInAppSDKParam.ReclaimAppSecret in Info.plist
        secret: String,
        /// The Reclaim data provider Id that should be used in the Reclaim Verification Process.
        providerId: String,
        /// The session that sdk will use for a verification attempt. If nil, sdk will generate a new session information internally.
        session: ReclaimSessionInformation? = nil,
        /// Additional data that can be associated with a verification attempt and returned in proofs. Defaults to an empty [String].
        context: String = "",
        /// Prefill variables that can be used during the claim creation process.
        parameters: [String : String] = [String:String](),
        /// When false, sdk shows a page with claims that'll be proven and waits for the user to press start before starting verification flow
        hideLanding: Bool = true,
        /// If true, automatically submits proof after proof is generated from the claim creation process. Otherwise, lets the user submit proof by pressing a submit button when proof is generated.
        autoSubmit: Bool = false,
        acceptAiProviders: Bool = false,
        webhookUrl: String? = nil
    ) {
        self.appId = appId
        self.secret = secret
        self.providerId = providerId
        self.signature = session?.signature ?? ""
        self.timestamp = session?.timestamp ?? ""
        self.context = context
        self.sessionId = session?.sessionId ?? ""
        self.parameters = parameters
        self.hideLanding = hideLanding
        self.autoSubmit = autoSubmit
        self.acceptAiProviders = acceptAiProviders
        self.webhookUrl = webhookUrl
    }

    /// Create a Reclaim Verification Request where appId and secret is retreived from Info.plist file. This is used to start a reclaim verification process.
    ///
    /// AppId and Secret can be provided like this in the Info.plist file:
    /// ```plist
    ///     <key>ReclaimInAppSDKParam</key>
    ///     <dict>
    ///         <key>ReclaimAppId</key>
    ///         <string>$(RECLAIM_APP_ID)</string>
    ///         <key>ReclaimAppSecret</key>
    ///         <string>$(RECLAIM_APP_SECRET)</string>
    ///     </dict>
    /// ```
    ///
    /// See also:
    ///  - [ReclaimVerification(appId:secret:) initializer]: Another initializer where [appId] and [secret] is can be provided in the initializer.
    public init(
        /// The Reclaim data provider Id that should be used in the Reclaim Verification Process.
        providerId: String,
        /// The session that sdk will use for a verification attempt. If nil, sdk will generate a new session information internally.
        session: ReclaimSessionInformation? = nil,
        /// Additional data that can be associated with a verification attempt and returned in proofs. Defaults to an empty [String].
        context: String = "",
        /// Prefill variables that can be used during the claim creation process.
        parameters: [String : String] = [String:String](),
        hideLanding: Bool = true,
        /// If true, automatically submits proof after proof is generated from the claim creation process. Otherwise, lets the user submit proof by pressing a submit button when proof is generated.
        autoSubmit: Bool = false,
        acceptAiProviders: Bool = false,
        webhookUrl: String? = nil
    ) throws {
        let sdkParam = Bundle.main.infoDictionary?["ReclaimInAppSDKParam"] as? [String : Any]
        if (sdkParam == nil || sdkParam?["ReclaimAppId"] == nil || sdkParam?["ReclaimAppSecret"] == nil) {
            throw ReclaimVerificationError.failed(reason: "ReclaimInAppSDKParam.ReclaimAppId or ReclaimInAppSDKParam.ReclaimAppSecret are missing in Info.plist. Either provide appId and secret in Info.plist or use ReclaimVerification(appId:secret:) initializer")
        }
        let appId = sdkParam?["ReclaimAppId"] as! String
        let secret = sdkParam?["ReclaimAppSecret"] as! String
        self.init(
            appId: appId,
            secret: secret,
            providerId: providerId,
            session: session,
            context: context,
            parameters: parameters,
            hideLanding: hideLanding,
            autoSubmit: autoSubmit,
            acceptAiProviders: acceptAiProviders,
            webhookUrl: webhookUrl
        )
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
    ///     let request = try ReclaimVerification.Request(providerId: "some-provider-id")
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
