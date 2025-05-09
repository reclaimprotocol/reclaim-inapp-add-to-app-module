import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reclaim_flutter_sdk/logging/data/log.dart';
import 'package:reclaim_flutter_sdk/logging/logging.dart';
import 'package:reclaim_flutter_sdk/reclaim_flutter_sdk.dart';
import 'package:reclaim_flutter_sdk/services/capability/capability.dart';
import 'package:reclaim_flutter_sdk/types/claim_creation_type.dart';
import 'package:reclaim_flutter_sdk/widgets/reclaim_theme_provider.dart';
import 'package:reclaim_gnark_zkoperator/reclaim_gnark_zkoperator.dart';
// ignore: implementation_imports
import 'package:reclaim_gnark_zkoperator/src/download/download.dart' show downloadWithHttp;

import 'src/data/url_request.dart';
import 'src/pigeon/messages.pigeon.dart';

const CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY = String.fromEnvironment(
  'org.reclaimprotocol.inapp_sdk.CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY',
);

final logger = Logger('reclaim_flutter_sdk.reclaim_verifier_module');

final gnarkProverFuture = ReclaimZkOperator.getInstance();

extension ReclaimSessionStatusExtension on ReclaimSessionStatus {
  static ReclaimSessionStatus fromSessionStatus(SessionStatus status) {
    return switch (status) {
      SessionStatus.PROOF_GENERATION_FAILED => ReclaimSessionStatus.PROOF_GENERATION_FAILED,
      SessionStatus.PROOF_GENERATION_SUCCESS => ReclaimSessionStatus.PROOF_GENERATION_SUCCESS,
      SessionStatus.PROOF_SUBMITTED => ReclaimSessionStatus.PROOF_SUBMITTED,
      SessionStatus.PROOF_SUBMISSION_FAILED => ReclaimSessionStatus.PROOF_SUBMISSION_FAILED,
      SessionStatus.PROOF_MANUAL_VERIFICATION_SUBMITED => ReclaimSessionStatus.PROOF_MANUAL_VERIFICATION_SUBMITTED,
      SessionStatus.USER_INIT_VERIFICATION => ReclaimSessionStatus.USER_INIT_VERIFICATION,
      SessionStatus.USER_STARTED_VERIFICATION => ReclaimSessionStatus.USER_STARTED_VERIFICATION,
      SessionStatus.PROOF_GENERATION_STARTED => ReclaimSessionStatus.PROOF_GENERATION_STARTED,
      SessionStatus.PROOF_GENERATION_RETRY => ReclaimSessionStatus.PROOF_GENERATION_RETRY,
    };
  }
}

extension ClaimCreationTypeExtension on ClaimCreationTypeApi {
  ClaimCreationType get toClaimCreationType {
    return switch (this) {
      ClaimCreationTypeApi.standalone => ClaimCreationType.standalone,
      ClaimCreationTypeApi.meChain => ClaimCreationType.meChain,
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

  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: ReclaimThemeProvider(child: ReclaimModuleApp())));
}

class ReclaimModuleApp extends StatefulWidget {
  const ReclaimModuleApp({super.key});

  @override
  State<ReclaimModuleApp> createState() => _ReclaimModuleAppState();
}

class _ReclaimModuleAppState extends State<ReclaimModuleApp> implements ReclaimModuleApi {
  late final hostOverridesApi = ReclaimHostOverridesApi();
  late final hostVerificationApi = ReclaimHostVerificationApi();

  @override
  Future<bool> ping() async {
    return true;
  }

  late StreamSubscription<SessionIdentity?> _sessionIdentityUpdateListener;

  @override
  void initState() {
    super.initState();
    ReclaimModuleApi.setUp(this);
    _sessionIdentityUpdateListener = SessionIdentity.onChanged.listen(_onSessionIdentityUpdate);
  }

  void _onSessionIdentityUpdate(SessionIdentity? identity) {
    if (identity == null) {
      hostOverridesApi.onSessionIdentityUpdate(null);
    } else {
      hostOverridesApi.onSessionIdentityUpdate(
        ReclaimSessionIdentityUpdate(
          appId: identity.appId,
          providerId: identity.providerId,
          sessionId: identity.sessionId,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sessionIdentityUpdateListener.cancel();
    ReclaimModuleApi.setUp(null);
    super.dispose();
  }

  ReclaimVerificationOptions? _reclaimVerificationOptions;

  @override
  Future<ReclaimApiVerificationResponse> startVerification(ReclaimApiVerificationRequest request) async {
    try {
      final ReclaimVerification reclaimVerification;
      final usePreGeneratedSession =
          request.signature.isNotEmpty &&
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
          acceptAiProviders: request.acceptAiProviders,
          webhookUrl: request.webhookUrl,
          claimCreationType: _claimCreationType,
          autoSubmit: canAutoSubmit,
          hideCloseButton: !isCloseButtonVisible,
          verificationOptions: _reclaimVerificationOptions,
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
          acceptAiProviders: request.acceptAiProviders,
          webhookUrl: request.webhookUrl,
          claimCreationType: _claimCreationType,
          autoSubmit: canAutoSubmit,
          hideCloseButton: !isCloseButtonVisible,
          verificationOptions: _reclaimVerificationOptions,
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
                return ReclaimApiVerificationExceptionType.verificationDismissed;
              }
              if (e is ReclaimVerificationCancelledException) {
                return ReclaimApiVerificationExceptionType.verificationCancelled;
              }
              if (e is ReclaimExpiredSessionException) {
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
    return startVerification(
      ReclaimApiVerificationRequest(
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
      ),
    );
  }

  @override
  Future<void> clearAllOverrides() async {
    ReclaimOverride.clearAll();
  }

  Future<bool> canUseCapability(String capabilityName) async {
    final capabilityAccessVerifier = CapabilityAccessVerifier();

    if (await capabilityAccessVerifier.canUse(capabilityName)) {
      return true;
    }

    throw ReclaimException('Unauthorized use of capability: $capabilityName');
  }

  @override
  Future<void> setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
    String? capabilityAccessToken,
  ) async {
    if (capabilityAccessToken != null) {
      try {
        ReclaimOverride.set(
          CapabilityAccessToken.import(capabilityAccessToken, CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY),
        );
      } on CapabilityAccessTokenException catch (e, s) {
        logger.severe('Failed to set capability access token', e, s);
        throw ReclaimException(e.message);
      }
    }

    if (feature?.attestorBrowserRpcUrl != null ||
        provider != null ||
        logConsumer?.canSdkPrintLogs == true ||
        logConsumer?.canSdkCollectTelemetry == false ||
        sessionManagement?.enableSdkSessionManagement == true) {
      await canUseCapability('overrides_v1');
    }

    ReclaimOverride.setAll([
      if (feature != null)
        ReclaimFeatureFlagData(
          cookiePersist: feature.cookiePersist,
          singleReclaimRequest: feature.singleReclaimRequest,
          idleTimeThresholdForManualVerificationTrigger: feature.idleTimeThresholdForManualVerificationTrigger,
          sessionTimeoutForManualVerificationTrigger: feature.sessionTimeoutForManualVerificationTrigger,
          attestorBrowserRpcUrl: feature.attestorBrowserRpcUrl,
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
                  cacheDirName: 'inapp_sdk_provider_information',
                );

                if (response == null) {
                  throw ReclaimException(
                    'Failed to fetch provider information from ${provider.providerInformationUrl}',
                  );
                }

                providerInformation = json.decode(utf8.decode(response));
              } else if (provider.providerInformationJsonString != null) {
                providerInformation = json.decode(provider.providerInformationJsonString!);
              } else if (provider.canFetchProviderInformationFromHost) {
                final String rawProviderInformation = await hostOverridesApi.fetchProviderInformation(
                  appId: appId,
                  providerId: providerId,
                  sessionId: sessionId,
                  signature: signature,
                  timestamp: timestamp,
                );
                providerInformation = json.decode(rawProviderInformation);
              }
            } catch (e, s) {
              logger.severe('Failed to fetch provider information', e, s);
              if (e is ReclaimException) {
                rethrow;
              }
              throw ReclaimException('Failed to fetch provider information due to $e');
            }

            try {
              return HttpProvider.fromJson(providerInformation);
            } catch (e, s) {
              logger.severe('Failed to parse provider information', e, s);
              throw ReclaimException('Failed to parse provider information: ${e.toString()}');
            }
          },
        ),
      if (logConsumer != null)
        LogConsumerOverride(
          // Setting this to true will print logs from reclaim_flutter_sdk to the console.
          canPrintLogs: logConsumer.canSdkPrintLogs == true,
          onRecord:
              logConsumer.enableLogHandler
                  ? (record, identity) {
                    _sendLogsToHost(record, identity);
                    return logConsumer.canSdkCollectTelemetry;
                  }
                  : (!logConsumer.canSdkCollectTelemetry ? (_, __) => false : null),
        ),
      // A handler has been provided. We'll not let SDK manage sessions in this case.
      // Disabling [enableSdkSessionManagement] lets the host manage sessions.
      if (sessionManagement != null && !sessionManagement.enableSdkSessionManagement)
        ReclaimSessionOverride.session(
          createSession: ({
            required String appId,
            required String providerId,
            required String timestamp,
            required String signature,
          }) async {
            return hostOverridesApi.createSession(
              appId: appId,
              providerId: providerId,
              timestamp: timestamp,
              signature: signature,
            );
          },
          // metadata is not sent to host
          updateSession: (sessionId, status, metadata) async {
            return hostOverridesApi.updateSession(
              sessionId: sessionId,
              status: ReclaimSessionStatusExtension.fromSessionStatus(status),
            );
          },
          // metadata is not sent to host
          logRecord: ({
            required appId,
            required logType,
            required providerId,
            required sessionId,
            Map<String, dynamic>? metadata,
          }) {
            hostOverridesApi.logSession(appId: appId, providerId: providerId, sessionId: sessionId, logType: logType);
          },
        ),
      if (appInfo != null)
        AppInfo(appName: appInfo.appName, appImage: appInfo.appImageUrl, isRecurring: appInfo.isRecurring),
    ]);
  }

  ClaimCreationType _claimCreationType = ClaimCreationType.standalone;
  bool canAutoSubmit = true;
  bool isCloseButtonVisible = true;

  @override
  Future<void> setVerificationOptions(ReclaimApiVerificationOptions? options) async {
    final log = logger.child('setVerificationOptions');
    if (options == null) {
      log.info('Setting verification options to null');
      _reclaimVerificationOptions = null;
    } else {
      log.info({
        'reason': 'Setting verification options',
        'canDeleteCookiesBeforeVerificationStarts': options.canDeleteCookiesBeforeVerificationStarts,
        'canUseAttestorAuthenticationRequest': options.canUseAttestorAuthenticationRequest,
        'claimCreationType': options.claimCreationType,
      });
      _claimCreationType = options.claimCreationType.toClaimCreationType;
      isCloseButtonVisible = options.isCloseButtonVisible;
      canAutoSubmit = options.canAutoSubmit;
      _reclaimVerificationOptions = ReclaimVerificationOptions(
        preventCookieDeletion: !options.canDeleteCookiesBeforeVerificationStarts,
        attestorAuthenticationRequest:
            options.canUseAttestorAuthenticationRequest ? _requestAttestorAuthenticationRequestFromHost : null,
      );
    }
  }

  Future<AttestorAuthenticationRequest> _requestAttestorAuthenticationRequestFromHost(HttpProvider provider) async {
    // Encode to a JSON string and decode to a Map<dynamic, dynamic> to avoid type errors. This causes all nested objects's toJson to be called.
    final Map<dynamic, dynamic> providerMap = json.decode(json.encode(provider));
    final result = await hostVerificationApi.fetchAttestorAuthenticationRequest(providerMap);
    try {
      final map = json.decode(result);
      if (map is! Map) {
        throw ReclaimException('Invalid attestor authentication request');
      }
      return AttestorAuthenticationRequest.fromJson(map as Map<String, dynamic>);
    } catch (e, s) {
      logger.severe('Failed to parse attestor authentication request', e, s);
      throw ReclaimException('Failed to parse attestor authentication request: ${e.toString()}');
    }
  }

  void _sendLogsToHost(LogRecord record, SessionIdentity? identity) {
    final entry = LogEntry.fromRecord(
      record,
      identity,
      fallbackSessionIdentity: SessionIdentity.latest ?? SessionIdentity(appId: '', providerId: '', sessionId: ''),
    );
    hostOverridesApi.onLogs(json.encode(entry));
  }

  Future<String> _onComputeAttestorProof(
    String type,
    List<dynamic> args,
    OnZKComputePerformanceReportCallback onPerformanceReport,
  ) async {
    final gnarkProver = await gnarkProverFuture;
    return gnarkProver.computeAttestorProof(
      type,
      args,
      onPerformanceReport: (algorithm, report) {
        onPerformanceReport(ZKComputePerformanceReport(algorithmName: algorithm?.name ?? '', report: report));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuerySizeWidth = MediaQuery.sizeOf(context).width;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0 + (mediaQuerySizeWidth * 0.2)),
          child: const Center(child: LinearProgressIndicator(borderRadius: BorderRadius.all(Radius.circular(20)))),
        ),
      ),
    );
  }
}
