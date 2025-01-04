//import Foundation
//import SwiftUI
//
///// ReclaimVerification is the main entry point for the Reclaim SDK verification flow.
///// It provides functionality to initiate and manage the verification process.
//public class ReclaimVerification {
//    private init() {}
//    
//    private struct ReclaimClientConfiguration: Decodable {
//        public let ReclaimAppId, ReclaimAppSecret: String
//    }
//    
//    /// Request object containing all necessary parameters to start a verification process
//    public struct Request {
//        /// The Reclaim application ID obtained from the Reclaim dashboard
//        public let appId: String
//        /// The Reclaim application secret obtained from the Reclaim dashboard
//        public let appSecret: String
//        /// The ID of the provider to verify against (e.g., "google-login")
//        public let providerId: String
//        /// A unique identifier for this verification session
//        public let sessionId: String
//        /// Additional context that will be passed to the verification process
//        public let reclaimContext: String
//        /// Additional parameters required by the witness
//        public let witnessParameters: [String: String]
//        
//        /// Initialize a new verification request with explicit credentials
//        /// - Parameters:
//        ///   - appId: The Reclaim application ID
//        ///   - appSecret: The Reclaim application secret
//        ///   - providerId: The ID of the provider to verify against
//        ///   - sessionId: Optional unique identifier for this session (auto-generated if nil)
//        ///   - reclaimContext: Additional context for the verification
//        ///   - witnessParameters: Additional parameters required by the witness
//        public init(appId: String, appSecret: String, providerId: String, sessionId: String? = nil, reclaimContext: String = "", witnessParameters: [String: String] = [:]) {
//            self.appId = appId
//            self.appSecret = appSecret
//            self.providerId = providerId
//            self.sessionId = sessionId ?? UUID().uuidString
//            self.reclaimContext = reclaimContext
//            self.witnessParameters = witnessParameters
//        }
//        
//        /// Initialize a new verification request using credentials from Info.plist
//        /// - Parameters:
//        ///   - providerId: The ID of the provider to verify against
//        ///   - sessionId: Optional unique identifier for this session (auto-generated if nil)
//        ///   - reclaimContext: Additional context for the verification
//        ///   - witnessParameters: Additional parameters required by the witness
//        /// - Throws: ReclaimVerificationError if the credentials are not found in Info.plist
//        public init(providerId: String, sessionId: String? = nil, reclaimContext: String = "", witnessParameters: [String: String] = [:]) throws {
//            do {
//                if  let data = Bundle.main.infoDictionary?["ReclaimInAppSDKParam"] as? [String : Any] {
//                    let appId = data["ReclaimAppId"] as! String
//                    let appSecret = data["ReclaimAppSecret"] as! String
//                    self.init(appId: appId, appSecret: appSecret, providerId: providerId, sessionId: sessionId, reclaimContext: reclaimContext, witnessParameters: witnessParameters)
//                } else {
//                    throw ReclaimVerificationError.failed(reason:"Invalid ReclaimInAppSDKParam")
//                }
//            } catch {
//                throw ReclaimVerificationError.failed(reason: "Failed to create ReclaimVerification.Request. Make sure you have Reclaim SDK's required parameters in your app's Info.plist file.")
//            }
//        }
//    }
//    
//    /// Represents the proof obtained after successful verification
//    public struct ClaimCreationProof {
//        /// The URL containing the verification result
//        public let currentUrl: String
//        // Add any other relevant properties here
//    }
//    
//    /// Starts the verification process by presenting a full-screen verification interface
//    /// - Parameter request: The verification request containing all necessary parameters
//    /// - Returns: A ClaimCreationProof object containing the verification result
//    /// - Throws: ReclaimVerificationError if the verification fails or is cancelled
//    /// 
//    /// This method performs the following steps:
//    /// 1. Sets up logging and consumer identity for the verification session
//    /// 2. Creates and initializes the verification UI and view model
//    /// 3. Presents a full-screen modal interface for the verification process
//    /// 4. Returns the verification proof when the process completes successfully
//    ///
//    /// The verification flow is handled asynchronously and the method will only return once
//    /// the verification is complete or an error occurs. The UI is automatically dismissed
//    /// when the process finishes.
//    ///
//    /// Example usage:
//    /// ```swift
//    /// do {
//    ///     let request = try ReclaimVerification.Request(providerId: "google-login")
//    ///     let proof = try await ReclaimVerification.startVerification(request)
//    ///     // Handle successful verification
//    /// } catch {
//    ///     // Handle verification error
//    /// }
//    /// ```
//    @MainActor
//    public static func startVerification(_ request: Request) async throws -> ClaimCreationProof {
//        // Initialize logger for debugging and tracking
//        let logger = Logging.get("ReclaimVerification.startVerification")
//        
//        // Set up consumer identity for this verification session
//        ConsumerIdentity.latest = ConsumerIdentity(sessionId: request.sessionId, providerId: request.providerId, appId: request.appId)
//        
//        // Create the view model and UI screen for verification
//        let viewModel = ClaimCreationViewModel(request)
//        let claimCreationScreen = ClaimCreationScreen(viewModel: viewModel)
//        
//        logger.log("started initialization")
//        
//        // Initialize the view model asynchronously
//        Task { @MainActor in
//            await viewModel.initialize()
//        }
//        
//        // Use continuation to handle the asynchronous UI flow
//        return try await withCheckedThrowingContinuation { continuation in
//            // Get the current window to present the verification UI
//            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//                  let window = windowScene.windows.first else {
//                continuation.resume(throwing: ReclaimVerificationError.failed(reason: "Could not open claim creation window"))
//                return
//            }
//            
//            // Create and configure the hosting controller for the SwiftUI view
//            let hostingController = UIHostingController(rootView: claimCreationScreen)
//            hostingController.modalPresentationStyle = .fullScreen
//            
//            // Set up completion handler to dismiss UI and return result
//            viewModel.onCompletion = { [weak hostingController] result in
//                Task { @MainActor in
//                    hostingController?.dismiss(animated: true)
//                    continuation.resume(with: result)
//                }
//            }
//            
//            // Present the verification UI
//            window.rootViewController?.present(hostingController, animated: true)
//            logger.log("started client webview")
//        }
//    }
//}
//
///// Errors that can occur during the verification process
//public enum ReclaimVerificationError: Error {
//    /// The user cancelled the verification process
//    case cancelled
//    /// The verification failed with the specified reason
//    case failed(reason: String)
//}
