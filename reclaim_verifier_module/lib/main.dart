import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gnarkprover/gnarkprover.dart';
import 'package:reclaim_flutter_sdk/logging/logging.dart';
import 'package:reclaim_flutter_sdk/reclaim_flutter_sdk.dart';
import 'package:reclaim_verifier_module/src/pigeon/schema.pigeon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Getting the Gnark prover instance to initialize in advance before usage because initialization can take time.
  // This can also be done in the `main` function.
  // Calling this more than once is safe.
  Gnarkprover.getInstance();

  // Setting this to true will print logs from reclaim_flutter_sdk to the console.
  debugCanPrintLogs = kDebugMode;

  initializeReclaimLogging();

  runApp(const MaterialApp(
    home: ReclaimModuleApp(),
  ));
}

class ReclaimModuleApp extends StatefulWidget {
  const ReclaimModuleApp({super.key});

  @override
  State<ReclaimModuleApp> createState() => _ReclaimModuleAppState();
}

class _ReclaimModuleAppState extends State<ReclaimModuleApp>
    implements ReclaimModuleApi {
  @override
  Future<bool> ping() async {
    return true;
  }

  @override
  void initState() {
    super.initState();
    ReclaimModuleApi.setUp(this);
  }

  @override
  void dispose() {
    ReclaimModuleApi.setUp(null);
    super.dispose();
  }

  @override
  Future<ReclaimApiVerificationResponse> startVerification(
    ReclaimApiVerificationRequest request,
  ) async {
    try {
      final ReclaimVerification reclaimVerification;
      final usePreGeneratedSession = request.signature.isNotEmpty &&
          request.timestamp != null &&
          request.sessionId.isNotEmpty;
      if (usePreGeneratedSession) {
        reclaimVerification = ReclaimVerification.withSignature(
          signature: request.signature,
          timestamp: request.timestamp,
          sessionId: request.sessionId,
          buildContext: context,
          appId: request.appId,
          providerId: request.providerId,
          context: request.context,
          parameters: request.parameters,
          computeAttestorProof: _onComputeProofExternally,
          debug: request.debug,
          hideLanding: request.hideLanding,
          autoSubmit: request.autoSubmit,
          acceptAiProviders: request.acceptAiProviders,
          webhookUrl: request.webhookUrl,
        );
      } else {
        reclaimVerification = ReclaimVerification(
          buildContext: context,
          appId: request.appId,
          providerId: request.providerId,
          secret: request.secret,
          context: request.context,
          parameters: request.parameters,
          computeAttestorProof: _onComputeProofExternally,
          debug: request.debug,
          hideLanding: request.hideLanding,
          autoSubmit: request.autoSubmit,
          acceptAiProviders: request.acceptAiProviders,
          webhookUrl: request.webhookUrl,
        );
      }

      final proofs = await reclaimVerification.startVerification();

      return ReclaimApiVerificationResponse(
        sessionId: latestConsumerIdentity?.sessionId ?? request.sessionId,
        didSubmitManualVerification: proofs == null,
        proofs: [
          if (proofs != null) proofs.toJson(),
        ],
        exception: null,
      );
    } catch (e, s) {
      return ReclaimApiVerificationResponse(
        sessionId: latestConsumerIdentity?.sessionId ?? request.sessionId,
        didSubmitManualVerification: false,
        proofs: const [],
        exception: ReclaimApiVerificationException(
          message: e.toString(),
          stackTraceAsString: s.toString(),
          type: () {
            if (e is ReclaimException) {
              if (e is ReclaimVerificationDismissedException) {
                return ReclaimApiVerificationExceptionType.verificationDismissed;
              }
              if (e is ReclaimVerificationCancelledException) {
                return ReclaimApiVerificationExceptionType.verificationCancelled;
              }
              if (e is ReclaimSessionExpiredException) {
                return ReclaimApiVerificationExceptionType.sessionExpired;
              }
            }
            return ReclaimApiVerificationExceptionType.unknown;
          }(),
        ),
      );
    }
  }

  Future<String> _onComputeProofExternally(String type, Uint8List bytes) async {
    final gnarkProver = await Gnarkprover.getInstance();
    return gnarkProver.computeWitnessProof(type, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
