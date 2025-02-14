import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reclaim_flutter_sdk/logging/data/log.dart';
import 'package:reclaim_flutter_sdk/logging/logging.dart';
import 'package:reclaim_gnark_zkoperator/reclaim_gnark_zkoperator.dart';
// ignore: implementation_imports
import 'package:reclaim_gnark_zkoperator/src/download/download.dart'
    show downloadWithHttp;
import 'package:reclaim_flutter_sdk/reclaim_flutter_sdk.dart';
import 'package:reclaim_verifier_module/src/pigeon/messages.pigeon.dart';

import 'src/data/url_request.dart';

final logger = Logger('reclaim_flutter_sdk.reclaim_verifier_module');

final gnarkProverFuture = ReclaimZkOperator.getInstance();

extension ReclaimSessionStatusExtension on ReclaimSessionStatus {
  static ReclaimSessionStatus fromSessionStatus(SessionStatus status) {
    return switch (status) {
      SessionStatus.PROOF_GENERATION_FAILED =>
        ReclaimSessionStatus.PROOF_GENERATION_FAILED,
      SessionStatus.PROOF_GENERATION_SUCCESS =>
        ReclaimSessionStatus.PROOF_GENERATION_SUCCESS,
      SessionStatus.PROOF_SUBMITTED => ReclaimSessionStatus.PROOF_SUBMITTED,
      SessionStatus.PROOF_SUBMISSION_FAILED =>
        ReclaimSessionStatus.PROOF_SUBMISSION_FAILED,
      SessionStatus.PROOF_MANUAL_VERIFICATION_SUBMITTED =>
        ReclaimSessionStatus.PROOF_MANUAL_VERIFICATION_SUBMITTED,
      SessionStatus.USER_INIT_VERIFICATION =>
        ReclaimSessionStatus.USER_INIT_VERIFICATION,
      SessionStatus.USER_STARTED_VERIFICATION =>
        ReclaimSessionStatus.USER_STARTED_VERIFICATION,
      SessionStatus.PROOF_GENERATION_STARTED =>
        ReclaimSessionStatus.PROOF_GENERATION_STARTED,
      SessionStatus.PROOF_GENERATION_RETRY =>
        ReclaimSessionStatus.PROOF_GENERATION_RETRY,
    };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  hierarchicalLoggingEnabled = true;

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
  final hostApi = ReclaimApi();

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

  @override
  Future<void> setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
  ) async {
    ReclaimOverride.clearAll();

    ReclaimOverride.setAll([
      if (feature != null)
        ReclaimFeatureFlagData(
          cookiePersist: feature.cookiePersist,
          singleReclaimRequest: feature.singleReclaimRequest,
          idleTimeThresholdForManualVerificationTrigger:
              feature.idleTimeThresholdForManualVerificationTrigger,
          sessionTimeoutForManualVerificationTrigger:
              feature.sessionTimeoutForManualVerificationTrigger,
          attestorBrowserRpcUrl: feature.attestorBrowserRpcUrl,
          isResponseRedactionRegexEscapingEnabled:
              feature.isResponseRedactionRegexEscapingEnabled ?? false,
          isAIFlowEnabled: feature.isAIFlowEnabled ?? false,
        ),
      if (provider != null)
        ReclaimProviderOverride(
          fetchProviderInformation: ({
            required String appId,
            required String providerId,
            required String sessionId,
            required String signature,
            required String timestamp,
          }) async {
            Map<String, dynamic> providerInformation = {};
            try {
              if (provider.providerInformationUrl != null) {
                final response = await downloadWithHttp(
                  provider.providerInformationUrl!,
                );

                if (response == null) {
                  throw ReclaimException(
                    'Failed to fetch provider information from ${provider.providerInformationUrl}',
                  );
                }

                providerInformation = json.decode(utf8.decode(response));
              } else if (provider.providerInformationJsonString != null) {
                providerInformation = json.decode(
                  provider.providerInformationJsonString!,
                );
              }
            } catch (e, s) {
              logger.severe(
                'Failed to fetch provider information',
                e,
                s,
              );
              if (e is ReclaimException) {
                rethrow;
              }
              throw ReclaimException(
                'Failed to fetch provider information due to $e',
              );
            }

            try {
              return HttpProvider.fromJson(providerInformation);
            } catch (e, s) {
              logger.severe(
                'Failed to parse provider information',
                e,
                s,
              );
              throw ReclaimException(
                'Failed to parse provider information',
              );
            }
          },
        ),
      if (logConsumer != null)
        LogConsumerOverride(
          // Setting this to true will print logs from reclaim_flutter_sdk to the console.
          canPrintLogs: logConsumer.canSdkPrintLogs ?? reclaimCanPrintDebugLogs,
          onRecord: logConsumer.enableLogHandler
              ? (record, identity) {
                  _sendLogsToHost(record, identity);
                  return logConsumer.canSdkCollectTelemetry;
                }
              : (!logConsumer.canSdkCollectTelemetry ? (_, __) => false : null),
        ),
      // A handler has been provided. We'll not let SDK manage sessions in this case.
      // Disabling [enableSdkSessionManagement] lets the host manage sessions.
      if (sessionManagement != null &&
          !sessionManagement.enableSdkSessionManagement)
        ReclaimSessionOverride.session(
          createSession: ({
            required appId,
            required providerId,
            required sessionId,
          }) async {
            return hostApi.createSession(appId, providerId, sessionId);
          },
          updateSession: (sessionId, status) async {
            return hostApi.updateSession(
              sessionId,
              ReclaimSessionStatusExtension.fromSessionStatus(status),
            );
          },
          logRecord: ({
            required appId,
            required logType,
            required providerId,
            required sessionId,
          }) {
            hostApi.logSession(appId, providerId, sessionId, logType);
          },
        ),
      if (appInfo != null)
        AppInfo(
          appName: appInfo.appName,
          appImage: appInfo.appImageUrl,
          isRecurring: appInfo.isRecurring,
        ),
    ]);
  }

  void _sendLogsToHost(LogRecord record, SessionIdentity? identity) {
    final entry = LogEntry.fromRecord(
      record,
      identity,
      fallbackSessionIdentity: SessionIdentity.latest ??
          SessionIdentity(
            appId: '',
            providerId: '',
            sessionId: '',
          ),
    );
    hostApi.onLogs(json.encode(entry.toJson()));
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
