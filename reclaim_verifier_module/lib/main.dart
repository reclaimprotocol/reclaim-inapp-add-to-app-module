import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reclaim_gnark_zkoperator/reclaim_gnark_zkoperator.dart';
import 'package:reclaim_flutter_sdk/reclaim_flutter_sdk.dart';
import 'package:reclaim_verifier_module/src/pigeon/schema.pigeon.dart';

import 'src/data/url_request.dart';

final gnarkProverFuture = ReclaimZkOperator.getInstance();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Attestor.instance.useAttestor((client) async {
    // don't wait to make this [client] available in the pool
    client.ensureReady();
    return;
  });

  initializeReclaimLogging();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
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
          request.timestamp!.isNotEmpty &&
          request.sessionId.isNotEmpty;
      if (usePreGeneratedSession) {
        reclaimVerification = ReclaimVerification.withSession(
          sessionInformation: ReclaimSessionInformation(
            signature: request.signature,
            timestamp: request.timestamp ?? '',
            sessionId: request.sessionId,
          ),
          buildContext: context,
          appId: request.appId,
          providerId: request.providerId,
          context: request.context,
          parameters: request.parameters,
          computeAttestorProof: _onComputeAttestorProof,
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
          computeAttestorProof: _onComputeAttestorProof,
          hideLanding: request.hideLanding,
          autoSubmit: request.autoSubmit,
          acceptAiProviders: request.acceptAiProviders,
          webhookUrl: request.webhookUrl,
        );
      }

      final proofs = await reclaimVerification.startVerification();

      return ReclaimApiVerificationResponse(
        sessionId: SessionIdentity.latest?.sessionId ?? request.sessionId,
        didSubmitManualVerification: proofs == null,
        proofs: [
          if (proofs != null)
            for (final proof in proofs) json.decode(json.encode(proof)),
        ],
        exception: null,
      );
    } catch (e, s) {
      return ReclaimApiVerificationResponse(
        sessionId: SessionIdentity.latest?.sessionId ?? request.sessionId,
        didSubmitManualVerification: false,
        proofs: const [],
        exception: ReclaimApiVerificationException(
          message: e.toString(),
          stackTraceAsString: s.toString(),
          type: () {
            if (e is ReclaimException) {
              if (e is ReclaimVerificationDismissedException) {
                return ReclaimApiVerificationExceptionType
                    .verificationDismissed;
              }
              if (e is ReclaimVerificationCancelledException) {
                return ReclaimApiVerificationExceptionType
                    .verificationCancelled;
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

  @override
  Future<ReclaimApiVerificationResponse> startVerificationFromUrl(String url) {
    final request = ReclaimUrlRequest.fromUrl(url);
    return startVerification(ReclaimApiVerificationRequest(
      appId: request.applicationId,
      providerId: request.providerId,
      secret: request.signature,
      signature: request.signature,
      timestamp: request.timestamp,
      context: request.context ?? '',
      sessionId: request.sessionId ?? '',
      parameters: request.parameters ?? const {},
      acceptAiProviders: request.acceptAiProviders ?? false,
      webhookUrl: request.callbackUrl,
      hideLanding: false,
      autoSubmit: false,
    ));
  }

  Future<String> _onComputeAttestorProof(
    String type,
    List<dynamic> args,
  ) async {
    final gnarkProver = await gnarkProverFuture;
    return gnarkProver.computeAttestorProof(type, args);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: LinearProgressIndicator(
              borderRadius: BorderRadius.all(
                Radius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
