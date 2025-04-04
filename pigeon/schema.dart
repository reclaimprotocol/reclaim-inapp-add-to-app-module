import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    input: 'pigeon/schema.dart',
    dartOut: 'lib/src/pigeon/messages.pigeon.dart',
    // dartTestOut: 'test/pigeon/messages_test.g.dart',
    kotlinOptions: KotlinOptions(package: 'org.reclaimprotocol.inapp_sdk'),
    kotlinOut: 'generated/android/src/main/java/org/reclaimprotocol/inapp_sdk/Messages.kt',
    swiftOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.swift',
    objcHeaderOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.h',
    objcSourceOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.m',
    copyrightHeader: 'pigeon/copyright.txt',
  ),
)
class ReclaimApiVerificationRequest {
  final String appId;
  final String providerId;
  final String secret;
  final String signature;
  final String? timestamp;
  final String context;
  final String sessionId;
  final Map<String, String> parameters;
  final bool autoSubmit;
  final bool acceptAiProviders;
  final String? webhookUrl;

  const ReclaimApiVerificationRequest({
    required this.appId,
    required this.providerId,
    required this.secret,
    required this.signature,
    required this.timestamp,
    required this.context,
    required this.sessionId,
    required this.parameters,
    required this.autoSubmit,
    required this.acceptAiProviders,
    required this.webhookUrl,
  });
}

enum ReclaimApiVerificationExceptionType { unknown, sessionExpired, verificationDismissed, verificationFailed, verificationCancelled }

class ReclaimApiVerificationException {
  final String message;
  final String stackTraceAsString;
  final ReclaimApiVerificationExceptionType type;

  const ReclaimApiVerificationException({required this.message, required this.stackTraceAsString, required this.type});
}

class ReclaimApiVerificationResponse {
  final String sessionId;
  final bool didSubmitManualVerification;
  final List<Map<String, dynamic>> proofs;
  final ReclaimApiVerificationException? exception;

  const ReclaimApiVerificationResponse({
    required this.sessionId,
    required this.didSubmitManualVerification,
    required this.proofs,
    required this.exception,
  });
}

class ClientProviderInformationOverride {
  final String? providerInformationUrl;
  final String? providerInformationJsonString;
  final bool canFetchProviderInformationFromHost;

  const ClientProviderInformationOverride({
    this.providerInformationUrl,
    this.providerInformationJsonString,
    this.canFetchProviderInformationFromHost = false,
  });
}

class ClientFeatureOverrides {
  final bool? cookiePersist;
  final bool? singleReclaimRequest;
  final int? idleTimeThresholdForManualVerificationTrigger;
  final int? sessionTimeoutForManualVerificationTrigger;
  final String? attestorBrowserRpcUrl;
  final bool? isAIFlowEnabled;

  const ClientFeatureOverrides({
    this.cookiePersist,
    // false
    this.singleReclaimRequest,
    // 2
    this.idleTimeThresholdForManualVerificationTrigger,
    // 180
    this.sessionTimeoutForManualVerificationTrigger,
    // https://attestor.reclaimprotocol.org/browser-rpc
    this.attestorBrowserRpcUrl,
    // false
    this.isAIFlowEnabled,
  });
}

class ClientLogConsumerOverride {
  // true
  final bool enableLogHandler;
  // true
  final bool canSdkCollectTelemetry;
  // false
  final bool? canSdkPrintLogs;

  const ClientLogConsumerOverride({this.enableLogHandler = true, this.canSdkCollectTelemetry = true, this.canSdkPrintLogs = false});
}

class ClientReclaimSessionManagementOverride {
  // true
  final bool enableSdkSessionManagement;

  const ClientReclaimSessionManagementOverride({this.enableSdkSessionManagement = true});
}

class ClientReclaimAppInfoOverride {
  final String appName;
  final String appImageUrl;
  // false
  final bool isRecurring;

  const ClientReclaimAppInfoOverride({required this.appName, required this.appImageUrl, required this.isRecurring});
}

enum ReclaimSessionStatus {
  USER_STARTED_VERIFICATION,
  USER_INIT_VERIFICATION,
  PROOF_GENERATION_STARTED,
  PROOF_GENERATION_RETRY,
  PROOF_GENERATION_SUCCESS,
  PROOF_GENERATION_FAILED,
  PROOF_SUBMITTED,
  PROOF_SUBMISSION_FAILED,
  PROOF_MANUAL_VERIFICATION_SUBMITTED,
}

/// Identification information of a session.
class ReclaimSessionIdentityUpdate {
  /// The application id.
  final String appId;

  /// The provider id.
  final String providerId;

  /// The session id.
  final String sessionId;

  const ReclaimSessionIdentityUpdate({required this.appId, required this.providerId, required this.sessionId});
}

class ReclaimApiVerificationOptions {
  /// Whether to delete cookies before user journey starts in the client web view.
  /// Defaults to true.
  final bool canDeleteCookiesBeforeVerificationStarts;

  /// Whether module can use a callback to host that returns an authentication request when a Reclaim HTTP provider is provided.
  /// Defaults to false.
  /// {@macro CreateClaimOptions.attestorAuthenticationRequest}
  final bool canUseAttestorAuthenticationRequest;

  const ReclaimApiVerificationOptions({
    this.canDeleteCookiesBeforeVerificationStarts = true,
    this.canUseAttestorAuthenticationRequest = false,
  });
}

/// Apis implemented by the Reclaim module for use by the host.
@FlutterApi()
abstract class ReclaimModuleApi {
  @async
  ReclaimApiVerificationResponse startVerification(ReclaimApiVerificationRequest request);
  @async
  ReclaimApiVerificationResponse startVerificationFromUrl(String url);
  @async
  void setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
    String? capabilityAccessToken,
  );
  @async
  void clearAllOverrides();
  @async
  void setVerificationOptions(ReclaimApiVerificationOptions? options);
  @async
  bool ping();
}

/// Apis implemented by the host using the Reclaim module.
@HostApi()
abstract class ReclaimHostOverridesApi {
  @async
  void onLogs(String logJsonString);
  @async
  bool createSession({required String appId, required String providerId, required String sessionId});
  @async
  bool updateSession({required String sessionId, required ReclaimSessionStatus status});
  @async
  void logSession({required String appId, required String providerId, required String sessionId, required String logType});
  @async
  void onSessionIdentityUpdate(ReclaimSessionIdentityUpdate? update);
  @async
  String fetchProviderInformation({
    required String appId,
    required String providerId,
    required String sessionId,
    required String signature,
    required String timestamp,
  });
}

@HostApi()
abstract class ReclaimHostVerificationApi {
  @async
  String fetchAttestorAuthenticationRequest(Map<dynamic, dynamic> reclaimHttpProvider);
}
