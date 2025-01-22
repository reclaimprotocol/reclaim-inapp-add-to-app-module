import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  input: 'pigeon/schema.dart',
  dartOut: 'lib/src/pigeon/schema.pigeon.dart',
  dartTestOut: 'test/pigeon/schema_test.g.dart',
  kotlinOptions: KotlinOptions(
    package: 'org.reclaimprotocol.plugins.reclaim_verifier_android',
  ),
  kotlinOut:
      '../plugins/android/app/src/main/java/org/reclaimprotocol/reclaim_inapp_sdk/Schema.kt',
  swiftOut: '../plugins/ios/Sources/ReclaimInAppSdk/Schema.swift',
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
  final bool debug;
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
    required this.debug,
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
  bool ping();
}

@HostApi()
abstract class ReclaimApi {
  @async
  bool ping();
}
