import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  input: 'pigeon/schema.dart',
  dartOut: 'lib/src/pigeon/messages.pigeon.dart',
  // dartTestOut: 'test/pigeon/messages_test.g.dart',
  kotlinOptions: KotlinOptions(
    package: 'org.reclaimprotocol.inapp_sdk',
  ),
  kotlinOut: 'generated/android/src/main/java/org/reclaimprotocol/inapp_sdk/Messages.kt',
  swiftOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.swift',
  objcHeaderOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.h',
  objcSourceOut: 'generated/ios/Sources/ReclaimInAppSdk/Messages.m',
  copyrightHeader: 'pigeon/copyright.txt',
))
class ReclaimApiVerificationRequest {
  final String appId;
  final String providerId;
  final String secret;
  final String signature;
  final String? timestamp;
  final String context;
  final String sessionId;
  final Map<String, String> parameters;
  final bool hideLanding;
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
    required this.hideLanding,
    required this.autoSubmit,
    required this.acceptAiProviders,
    required this.webhookUrl,
  });
}

enum ReclaimApiVerificationExceptionType {
  unknown,
  sessionExpired,
  verificationDismissed,
  verificationFailed,
  verificationCancelled,
}

class ReclaimApiVerificationException {
  final String message;
  final String stackTraceAsString;
  final ReclaimApiVerificationExceptionType type;

  const ReclaimApiVerificationException({
    required this.message,
    required this.stackTraceAsString,
    required this.type,
  });
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

  const ClientProviderInformationOverride({
    this.providerInformationUrl,
    this.providerInformationJsonString,
  });
}

class ClientFeatureOverrides {
  final bool? cookiePersist;
  final bool? singleReclaimRequest;
  final int? idleTimeThresholdForManualVerificationTrigger;
  final int? sessionTimeoutForManualVerificationTrigger;
  final String? attestorBrowserRpcUrl;
  final bool? isResponseRedactionRegexEscapingEnabled;
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
    this.isResponseRedactionRegexEscapingEnabled,
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

  const ClientLogConsumerOverride({
    this.enableLogHandler = true,
    this.canSdkCollectTelemetry = true,
    this.canSdkPrintLogs = false,
  });
}

class ClientReclaimSessionManagementOverride {
  // true
  final bool enableSdkSessionManagement;

  const ClientReclaimSessionManagementOverride({
    this.enableSdkSessionManagement = true,
  });
}

class ClientReclaimAppInfoOverride {
  final String appName;
  final String appImageUrl;
  // false
  final bool isRecurring;

  const ClientReclaimAppInfoOverride({
    required this.appName,
    required this.appImageUrl,
    required this.isRecurring,
  });
}

@FlutterApi()
abstract class ReclaimModuleApi {
  @async
  ReclaimApiVerificationResponse startVerification(
    ReclaimApiVerificationRequest request,
  );
  @async
  ReclaimApiVerificationResponse startVerificationFromUrl(
    String url,
  );
  @async
  void setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
  );
  @async
  bool ping();
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

@HostApi()
abstract class ReclaimApi {
  @async
  bool ping();
  @async
  void onLogs(String logJsonString);
  @async
  bool createSession(String appId, String providerId, String sessionId);
  @async
  bool updateSession(String sessionId, ReclaimSessionStatus status);
  void logSession(
    String appId,
    String providerId,
    String sessionId,
    String logType,
  );
}
