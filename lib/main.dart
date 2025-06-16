import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:reclaim_gnark_zkoperator/reclaim_gnark_zkoperator.dart';
// ignore: implementation_imports
import 'package:reclaim_gnark_zkoperator/src/download/download.dart' show downloadWithHttp;
import 'package:reclaim_inapp_sdk/attestor.dart';
import 'package:reclaim_inapp_sdk/capability_access.dart';
import 'package:reclaim_inapp_sdk/logging.dart';
import 'package:reclaim_inapp_sdk/overrides.dart';
import 'package:reclaim_inapp_sdk/reclaim_inapp_sdk.dart';
import 'package:reclaim_inapp_sdk/ui.dart';

import 'src/pigeon/messages.pigeon.dart';

const CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY = String.fromEnvironment(
  'org.reclaimprotocol.inapp_sdk.CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY',
);

final logger = Logger('reclaim_flutter_sdk.reclaim_verifier_module');

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

  startReclaimSdkLogging();

  Attestor.instance.useAttestor((client) async {
    // don't wait to make this [client] available in the pool
    client.ensureReady();
    return;
  });

  ReclaimZkOperator.getInstance();

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

  final _defaultReclaimVerificationOptions = ReclaimVerificationOptions(
    canAutoSubmit: true,
    isCloseButtonVisible: true,
    attestorZkOperator: AttestorZkOperatorWithCallback.withReclaimZKOperator(
      onComputeProof: (type, args, onPerformanceReport) async {
        // Get gnark prover instance and compute the attestor proof.
        return (await ReclaimZkOperator.getInstance()).computeAttestorProof(
          type,
          args,
          onPerformanceReport: (algorithm, report) {
            onPerformanceReport(ZKComputePerformanceReport(algorithmName: algorithm?.name ?? '', report: report));
          },
        );
      },
    ),
  );

  late ReclaimVerificationOptions _reclaimVerificationOptions = _defaultReclaimVerificationOptions;

  Future<ReclaimApiVerificationResponse> _startVerification(
    ReclaimVerificationRequest request,
    String requestSessionId,
  ) async {
    try {
      final reclaimVerification = ReclaimVerification.of(context);

      final response = await reclaimVerification.startVerification(
        request: request,
        options: _reclaimVerificationOptions,
      );
      return ReclaimApiVerificationResponse(
        sessionId: SessionIdentity.latest?.sessionId ?? requestSessionId,
        didSubmitManualVerification: false,
        proofs: (json.decode(json.encode(response.proofs)) as List).map((e) => e as Map<String, dynamic>).toList(),
        exception: null,
      );
    } catch (e, s) {
      logger.severe('Failed verification response', e, s);
      return ReclaimApiVerificationResponse(
        sessionId: SessionIdentity.latest?.sessionId ?? requestSessionId,
        didSubmitManualVerification: e is ReclaimVerificationManualReviewException,
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
  Future<ReclaimApiVerificationResponse> startVerification(ReclaimApiVerificationRequest request) async {
    final usePreGeneratedSession =
        request.signature.isNotEmpty &&
        request.timestamp != null &&
        request.timestamp!.isNotEmpty &&
        request.sessionId.isNotEmpty;

    return _startVerification(
      ReclaimVerificationRequest(
        sessionProvider: () {
          final version = ProviderVersionExact(
            request.providerVersion?.resolvedVersion ?? '',
            versionExpression: request.providerVersion?.versionExpression,
          );
          if (usePreGeneratedSession) {
            return ReclaimSessionInformation(
              signature: request.signature,
              timestamp: request.timestamp ?? '',
              sessionId: request.sessionId,
              version: version,
            );
          }
          return ReclaimSessionInformation.generateNew(
            applicationId: request.appId,
            applicationSecret: request.secret,
            providerId: request.providerId,
            providerVersion: version.versionExpression,
          );
        },
        applicationId: request.appId,
        providerId: request.providerId,
        contextString: request.context,
        parameters: request.parameters,
      ),
      request.sessionId,
    );
  }

  @override
  Future<ReclaimApiVerificationResponse> startVerificationFromUrl(String url) {
    final request = ClientSdkVerificationRequest.fromUrl(url);
    return _startVerification(ReclaimVerificationRequest.fromSdkRequest(request), request.sessionId ?? '');
  }

  @override
  Future<ReclaimApiVerificationResponse> startVerificationFromJson(Map<dynamic, dynamic> template) {
    final request = ClientSdkVerificationRequest.fromJson(<String, dynamic>{
      for (final entry in template.entries) (entry.key?.toString() ?? ''): entry.value,
    });
    return _startVerification(ReclaimVerificationRequest.fromSdkRequest(request), request.sessionId ?? '');
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

    throw ReclaimVerificationCancelledException('Unauthorized use of capability: $capabilityName');
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
        throw ReclaimVerificationCancelledException(e.message);
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
          attestorBrowserRpcUrl: feature.attestorBrowserRpcUrl,
          idleTimeThresholdForManualVerificationTrigger: feature.idleTimeThresholdForManualVerificationTrigger,
          sessionTimeoutForManualVerificationTrigger: feature.sessionTimeoutForManualVerificationTrigger,
          canUseAiFlow: feature.isAIFlowEnabled ?? false,
          manualReviewMessage: feature.manualReviewMessage,
          loginPromptMessage: feature.loginPromptMessage,
        ),
      if (provider != null)
        ReclaimProviderOverride(
          fetchProviderInformation: ({
            required String appId,
            required String providerId,
            required String sessionId,
            required String signature,
            required String timestamp,
            required String resolvedVersion,
          }) async {
            Map<String, dynamic> providerInformation = {};
            try {
              if (provider.providerInformationUrl != null) {
                final response = await downloadWithHttp(
                  provider.providerInformationUrl!,
                  cacheDirName: 'inapp_sdk_provider_information',
                );

                if (response == null) {
                  throw ReclaimVerificationCancelledException(
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
                  resolvedVersion: resolvedVersion,
                );
                providerInformation = json.decode(rawProviderInformation);
              }
            } catch (e, s) {
              logger.severe('Failed to fetch provider information', e, s);
              if (e is ReclaimException) {
                rethrow;
              }
              throw ReclaimVerificationCancelledException('Failed to fetch provider information due to $e');
            }

            try {
              return HttpProvider.fromJson(providerInformation);
            } catch (e, s) {
              logger.severe('Failed to parse provider information', e, s);
              throw ReclaimVerificationCancelledException('Failed to parse provider information: ${e.toString()}');
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
            required String providerVersion,
          }) async {
            final response = await hostOverridesApi.createSession(
              appId: appId,
              providerId: providerId,
              timestamp: timestamp,
              signature: signature,
              providerVersion: providerVersion,
            );
            return SessionInitResponse(
              sessionId: response.sessionId,
              resolvedProviderVersion: response.resolvedProviderVersion,
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

  @override
  Future<void> setVerificationOptions(ReclaimApiVerificationOptions? options) async {
    final log = logger.child('setVerificationOptions');
    if (options == null) {
      log.info('Setting verification options to null');
      _reclaimVerificationOptions = _defaultReclaimVerificationOptions;
    } else {
      log.info({
        'reason': 'Setting verification options',
        'canDeleteCookiesBeforeVerificationStarts': options.canDeleteCookiesBeforeVerificationStarts,
        'canUseAttestorAuthenticationRequest': options.canUseAttestorAuthenticationRequest,
        'claimCreationType': options.claimCreationType,
      });
      _reclaimVerificationOptions = _reclaimVerificationOptions.copyWith(
        canAutoSubmit: options.canAutoSubmit,
        isCloseButtonVisible: options.isCloseButtonVisible,
        claimCreationType: options.claimCreationType.toClaimCreationType,
        canClearWebStorage: options.canDeleteCookiesBeforeVerificationStarts,
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
        throw ReclaimVerificationCancelledException('Invalid attestor authentication request');
      }
      return AttestorAuthenticationRequest.fromJson(map as Map<String, dynamic>);
    } catch (e, s) {
      logger.severe('Failed to parse attestor authentication request', e, s);
      throw ReclaimVerificationCancelledException('Failed to parse attestor authentication request: ${e.toString()}');
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

  @override
  Future<bool> sendLog(LogEntryApi entry) async {
    final level = Level.LEVELS.firstWhere((it) => it.value == entry.level, orElse: () => Level.INFO);
    final buffer = StringBuffer(entry.message);
    final stackTrace = entry.stackTraceAsString;
    if (stackTrace != null && stackTrace.isNotEmpty) {
      buffer.write('\nSTACKTRACE: $stackTrace');
    }
    final givenSessionId = entry.sessionId;
    final latestSessionId = SessionIdentity.latest?.sessionId;
    if (givenSessionId != null && givenSessionId.isNotEmpty && (latestSessionId == null || latestSessionId.isEmpty)) {
      SessionIdentity.updateLatest(SessionIdentity(appId: '', providerId: '', sessionId: givenSessionId));
    }
    logger.child(entry.source).log(level, buffer.toString(), entry.error);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Center(child: ClaimTriggerIndicator(color: colorScheme.primary)),
        ),
      ),
    );
  }
}
