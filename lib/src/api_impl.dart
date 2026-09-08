part of 'api.dart';

final _logger = Logger('reclaim_flutter_sdk.reclaim_verifier_module.api');

ReclaimApiVerificationResponse _builderModeFailure(Object error, StackTrace stackTrace, String sessionId) {
  return ReclaimApiVerificationResponse(
    sessionId: sessionId,
    didSubmitManualVerification: false,
    proofs: const [],
    exception: ReclaimApiVerificationException(
      message:
          'Builder verification failed. Configure the registered Verification Client bridge and x-reclaim-vc-id. Caused by: $error',
      stackTraceAsString: stackTrace.toString(),
      type: ReclaimApiVerificationExceptionType.verificationCancelled,
    ),
  );
}

extension ClaimCreationTypeExtension on ClaimCreationTypeApi {
  ClaimCreationType get toClaimCreationType {
    return switch (this) {
      ClaimCreationTypeApi.standalone => ClaimCreationType.standalone,
      ClaimCreationTypeApi.meChain => ClaimCreationType.meChain,
    };
  }
}

bool _didAttemptPrecacheFonts = false;

void _precacheFonts() async {
  if (_didAttemptPrecacheFonts) return;
  _didAttemptPrecacheFonts = true;

  final log = _logger.child('_precacheFonts');
  try {
    await ReclaimThemeProvider.font.description.installFontIfRequired();
  } catch (e, s) {
    log.severe('Error precaching fonts', e, s);
  }
}

void _setReclaimEnv() {
  ReclaimEnv.CAPABILITY_ACCESS_TOKEN_VERIFICATION_KEY =
      'eyJraWQiOiI4NjgyNGJkMS04ZDU4LTQ5YWQtODVlMC03YzYxYWUyYTNjM2IiLCJrZXlfb3BzIjpbInZlcmlmeSJdLCJleHQiOnRydWUsImt0eSI6IkVDIiwieCI6Il80ekg2MFNJNEkyYXBuVlYzeUFTLWxQYWpwbzRHeTRmYV9NOFJYMGVaR0UiLCJ5IjoiSk5lWExnZ0JDdm9QZ1lYYTZxRGhCWHN6OGc1MkpHSDZPSHUyUmtpLXp5USIsImNydiI6IlAtMjU2In0';
  ReclaimEnv.IS_VERIFIER_INAPP_MODULE = true;
}

class _ReclaimModuleExternalApiImpl implements ReclaimModuleExternalApi {
  _ReclaimModuleExternalApiImpl() {
    _setReclaimEnv();
    _precacheFonts();
    startReclaimSdkLogging();
    ReclaimModuleApi.setUp(this);
    setSessionIdentityListener(_onSessionIdentityUpdate);
  }

  bool _isDisposed = false;
  void assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('ReclaimModuleExternalApiImpl is disposed');
    }
  }

  late final _hostOverridesApi = ReclaimHostOverridesApi();
  ReclaimHostOverridesApi get hostOverridesApi {
    assertNotDisposed();
    return _hostOverridesApi;
  }

  late final _hostVerificationApi = ReclaimHostVerificationApi();
  ReclaimHostVerificationApi get hostVerificationApi {
    assertNotDisposed();
    return _hostVerificationApi;
  }

  BuilderVerificationClient? _builderClient;

  @override
  Future<void> configureBuilderVerification({required String baseUrl, required String verificationClientId}) async {
    return setBuilderModeOverrides(
      ClientBuilderModeOverrides(baseUrl: baseUrl, verificationClientId: verificationClientId),
    );
  }

  @override
  Future<void> setBuilderModeOverrides(ClientBuilderModeOverrides overrides) async {
    assertNotDisposed();
    final override = ReclaimBuilderVerificationOverride(
      baseUrl: overrides.baseUrl,
      verificationClientId: overrides.verificationClientId,
    );
    // Constructing the generated bridge wrapper validates the URL now instead
    // of failing only after the claimant opens an `api=2` link.
    final client = BuilderVerificationClient.fromOverride(override);
    ReclaimOverride.set(override);
    _builderClient = client;
  }

  StreamSubscription<SessionIdentity?>? _sessionIdentityUpdateListener;

  @override
  void dispose() {
    _isDisposed = true;
    _sessionIdentityUpdateListener?.cancel();
    ReclaimModuleApi.setUp(null);
  }

  @override
  Future<void> setSessionIdentityListener(void Function(SessionIdentity?)? onSessionIdentity) async {
    _sessionIdentityUpdateListener?.cancel();
    _sessionIdentityUpdateListener = SessionIdentity.onChanged.listen(onSessionIdentity);
  }

  @override
  Future<void> clearAllOverrides() async {
    _builderClient = null;
    return ReclaimOverride.clearAll();
  }

  @override
  Future<bool> ping() async {
    return true;
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
    _logger.child(entry.source).log(level, buffer.toString(), entry.error);
    return true;
  }

  @override
  Future<void> setConsoleLogging(bool enabled) async {
    final old = ReclaimOverride.get<LogConsumerOverride>();
    ReclaimOverride.set(
      LogConsumerOverride(
        // Setting this to true will print logs from reclaim_flutter_sdk to the console.
        canPrintLogs: enabled,
        onRecord: old?.onRecord,
        levelChangeHandler: old?.levelChangeHandler,
      ),
    );
  }

  @override
  Future<void> setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
    String? capabilityAccessToken, {
    ReclaimHostOverridesApi? overridesHandlerApi,
  }) async {
    final overridesHandler = overridesHandlerApi ?? hostOverridesApi;
    if (capabilityAccessToken != null) {
      try {
        ReclaimOverride.set(CapabilityAccessToken.import(capabilityAccessToken));
      } on CapabilityAccessTokenException catch (e, s) {
        _logger.severe('Failed to set capability access token', e, s);
        throw ReclaimVerificationCancelledException(e.message);
      }
    }

    if (logConsumer?.canSdkPrintLogs == true) {
      await _assertCanUseAnyCapability(['overrides_v1', 'sdk_console_logging_v1']);
    }

    if (feature?.attestorBrowserRpcUrl != null) {
      await _assertCanUseAnyCapability(['overrides_v1', 'sdk_attestor_browser_rpc_v1']);
    }

    if (provider != null ||
        logConsumer?.canSdkPrintLogs == true ||
        logConsumer?.canSdkCollectTelemetry == false ||
        sessionManagement?.enableSdkSessionManagement == true) {
      await _assertCanUseCapability('overrides_v1');
    }

    final logLevel = logConsumer?.logLevel;
    if (logLevel != null) {
      setLoggingLevel(logLevel);
    }
    final canLogMetadata = logConsumer?.canLogMetadata;
    if (canLogMetadata != null) {
      metadataLoggingEnabled = canLogMetadata;
    }

    ReclaimOverride.setAll([
      if (feature != null)
        ReclaimFeatureFlagData(
          cookiePersist: feature.cookiePersist,
          singleReclaimRequest: feature.singleReclaimRequest,
          attestor3BrowserRpcUrl: feature.attestorBrowserRpcUrl,
          idleTimeThresholdForManualVerificationTrigger: feature.idleTimeThresholdForManualVerificationTrigger,
          sessionTimeoutForManualVerificationTrigger: feature.sessionTimeoutForManualVerificationTrigger,
          canUseAiFlow: feature.isAIFlowEnabled ?? false,
          manualReviewMessage: feature.manualReviewMessage,
          loginPromptMessage: feature.loginPromptMessage,
          useTEE: feature.useTEE,
          interceptorOptions: feature.interceptorOptions,
          claimCreationTimeoutDurationInMins: feature.claimCreationTimeoutDurationInMins,
          sessionNoActivityTimeoutDurationInMins: feature.sessionNoActivityTimeoutDurationInMins,
          aiProviderNoActivityTimeoutDurationInSecs: feature.aiProviderNoActivityTimeoutDurationInSecs,
          pageLoadedCompletedDebounceTimeoutMs: feature.pageLoadedCompletedDebounceTimeoutMs,
          potentialLoginTimeoutS: feature.potentialLoginTimeoutS,
          screenshotCaptureIntervalSeconds: feature.screenshotCaptureIntervalSeconds,
          teeUrls: feature.teeUrls,
          privacyPolicyUrl: feature.privacyPolicyUrl,
          termsOfServiceUrl: feature.termsOfServiceUrl,
          potentialFailureReasonsUrl: feature.potentialFailureReasonsUrl,
        ),
      if (provider != null)
        ReclaimProviderOverride(
          fetchProviderInformation:
              ({
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
                    final String rawProviderInformation = await overridesHandler.fetchProviderInformation(
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
                  _logger.severe('Failed to fetch provider information', e, s);
                  if (e is ReclaimException) {
                    rethrow;
                  }
                  throw ReclaimVerificationCancelledException('Failed to fetch provider information due to $e');
                }

                try {
                  return HttpProvider.fromJson(providerInformation);
                } catch (e, s) {
                  _logger.severe('Failed to parse provider information', e, s);
                  throw ReclaimVerificationCancelledException('Failed to parse provider information: ${e.toString()}');
                }
              },
        ),
      if (logConsumer != null)
        LogConsumerOverride(
          // Setting this to true will print logs from reclaim_flutter_sdk to the console.
          canPrintLogs: logConsumer.canSdkPrintLogs == true,
          onRecord: logConsumer.enableLogHandler
              ? (record) {
                  _sendLogsToHost(record, overridesHandler);
                  return logConsumer.canSdkCollectTelemetry;
                }
              : (!logConsumer.canSdkCollectTelemetry ? (_) => false : null),
        ),
      // A handler has been provided. We'll not let SDK manage sessions in this case.
      // Disabling [enableSdkSessionManagement] lets the host manage sessions.
      if (sessionManagement != null && !sessionManagement.enableSdkSessionManagement)
        ReclaimSessionOverride.session(
          createSession:
              ({
                required String appId,
                required String providerId,
                required String timestamp,
                required String signature,
                required String providerVersion,
              }) async {
                final response = await overridesHandler.createSession(
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
          updateSession: (sessionId, status, metadata) async {
            return overridesHandler.updateSession(
              sessionId: sessionId,
              status: ReclaimSessionStatusExtension.fromSessionStatus(status),
              metadata: ensureMap<String>(metadata),
            );
          },
          logRecord:
              ({
                required appId,
                required logType,
                required providerId,
                required sessionId,
                Map<String, dynamic>? metadata,
              }) {
                overridesHandler.logSession(
                  appId: appId,
                  providerId: providerId,
                  sessionId: sessionId,
                  logType: logType.name,
                  metadata: ensureMap<String>(metadata),
                );
              },
        ),
      if (appInfo != null)
        AppInfo(
          appName: appInfo.appName,
          appImage: appInfo.appImageUrl,
          isRecurring: appInfo.isRecurring,
          theme: appInfo.theme != null
              ? fromStringToObject(
                  content: appInfo.theme!,
                  fromJson: ReclaimAppThemeInfo.fromJson,
                  onInvalidContent: (e, s) {
                    _logger.severe('Failed to parse app theme', e, s);
                  },
                )
              : null,
        ),
    ]);
  }

  final _defaultReclaimVerificationOptions = ReclaimVerificationOptions(
    canAutoSubmit: true,
    // TODO: Add this as an option in platform apis
    canAutoCloseOnError: true,
    isCloseButtonVisible: true,
  );

  late ReclaimVerificationOptions _reclaimVerificationOptions = _defaultReclaimVerificationOptions;

  @override
  Future<void> setVerificationOptions(ReclaimApiVerificationOptions? options) async {
    final log = _logger.child('setVerificationOptions');
    if (options == null) {
      log.info('Setting verification options to null');
      _reclaimVerificationOptions = _defaultReclaimVerificationOptions;
    } else {
      log.info({
        'reason': 'Setting verification options',
        'canAutoSubmit': options.canAutoSubmit,
        'canDeleteCookiesBeforeVerificationStarts': options.canDeleteCookiesBeforeVerificationStarts,
        'canUseAttestorAuthenticationRequest': options.canUseAttestorAuthenticationRequest,
        'claimCreationType': options.claimCreationType,
        'isCloseButtonVisible': options.isCloseButtonVisible,
        'locale': options.locale,
        'useTeeOperator': options.useTeeOperator,
      });
      _reclaimVerificationOptions = _reclaimVerificationOptions.copyWith(
        canAutoSubmit: options.canAutoSubmit,
        // TODO: Add this as an option in platform apis
        canAutoCloseOnError: true,
        canClearWebStorage: options.canDeleteCookiesBeforeVerificationStarts,
        attestorAuthenticationRequest: options.canUseAttestorAuthenticationRequest
            ? _requestAttestorAuthenticationRequestFromHost
            : null,
        claimCreationType: options.claimCreationType.toClaimCreationType,
        isCloseButtonVisible: options.isCloseButtonVisible,
        locale: options.locale,
        useTeeOperator: options.useTeeOperator,
      );
    }
  }

  late BuildContext? _verificationContext;

  @override
  void setVerificationContext(BuildContext context) {
    _verificationContext = context;
  }

  @override
  Future<ReclaimApiVerificationResponse> startVerification(ReclaimApiVerificationRequest request) {
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
  Future<ReclaimApiVerificationResponse> startVerificationFromJson(Map<dynamic, dynamic> template) {
    try {
      final api = template['api']?.toString();
      if (api == '2') {
        final sessionId = template['sessionId']?.toString() ?? '';
        return _startBuilderVerification(
          ReclaimVerificationLink.fromUri(
            Uri(
              scheme: 'https',
              host: 'builder.invalid',
              queryParameters: {
                'api': '2',
                'sessionId': sessionId,
                if (template['diag']?.toString() == '1') 'diag': '1',
              },
            ),
          ),
        );
      }
      final debugMessage = 'Starting verification with json: ${json.encode(template)}';
      if (kDebugMode) {
        debugPrint(debugMessage);
      } else {
        _logger.config(debugMessage);
      }

      if (template.containsKey('reclaimProofRequestConfig')) {
        final config = template['reclaimProofRequestConfig'];
        if (config is String) {
          return startVerificationFromJson(json.decode(config));
        }
        if (config is Map) {
          return startVerificationFromJson(<String, dynamic>{
            for (final entry in config.entries) (entry.key?.toString() ?? ''): entry.value,
          });
        }
      }
      if (template.containsKey('context')) {
        final context = template['context'];
        if (context is Map) {
          return startVerificationFromJson(<String, dynamic>{...template, 'context': json.encode(context)});
        }
      }
      if (template.containsKey('timeStamp')) {
        template['timestamp'] = template['timeStamp'];
      }

      final request = ClientSdkVerificationRequest.fromJson(json.decode(json.encode(template)));
      return _startVerification(ReclaimVerificationRequest.fromSdkRequest(request), request.sessionId ?? '');
    } catch (e, s) {
      _logger.severe('Failed to start verification from json', e, s);
      return Future.value(
        ReclaimApiVerificationResponse(
          sessionId: 'unknown',
          didSubmitManualVerification: false,
          proofs: const [],
          exception: ReclaimApiVerificationException(
            message: 'Failed to parse verification request from json. Caused by: $e',
            stackTraceAsString: s.toString(),
            type: ReclaimApiVerificationExceptionType.verificationCancelled,
          ),
        ),
      );
    }
  }

  @override
  Future<ReclaimApiVerificationResponse> startVerificationFromUrl(String url) async {
    try {
      final link = ReclaimVerificationLink.fromUri(Uri.parse(url));
      if (link.isBuilder) {
        return await _startBuilderVerification(link);
      }
      final request = await ClientSdkVerificationRequest.fromUrl(url);
      final debugMessage = 'Starting verification with url: $url';
      if (kDebugMode) {
        debugPrint(debugMessage);
      } else {
        _logger.info(debugMessage);
      }
      return await _startVerification(ReclaimVerificationRequest.fromSdkRequest(request), request.sessionId ?? '');
    } catch (e, s) {
      _logger.severe('Failed to start verification from url', e, s);
      return Future.value(
        ReclaimApiVerificationResponse(
          sessionId: 'unknown',
          didSubmitManualVerification: false,
          proofs: const [],
          exception: ReclaimApiVerificationException(
            message: 'Failed to parse verification request from url. Caused by: $e',
            stackTraceAsString: s.toString(),
            type: ReclaimApiVerificationExceptionType.verificationCancelled,
          ),
        ),
      );
    }
  }

  Future<ReclaimApiVerificationResponse> _startBuilderVerification(ReclaimVerificationLink link) async {
    final sessionId = link.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return _builderModeFailure(
        const FormatException('Builder verification URL must include sessionId'),
        StackTrace.current,
        'unknown',
      );
    }
    final client = _builderClient;
    if (client == null) {
      return _builderModeFailure(
        const FormatException('Builder transport is not configured'),
        StackTrace.current,
        sessionId,
      );
    }
    BuilderVerificationSession? session;
    var terminalResultStored = false;
    var executionStarted = false;
    try {
      final claimantClientId = await DiagnosticLogging.getDeviceLoggingId();
      final context = _requireVerificationContext();
      if (!context.mounted) {
        throw const ReclaimVerificationCancelledException('Verification context was disposed');
      }
      final claimantDetails = await collectBuilderClaimantDetails(
        claimantId: claimantClientId,
        clientKind: 'reclaim_inapp_add_to_app_module',
        context: context,
      );
      session = await BuilderVerificationSession.load(
        client: client,
        sessionId: sessionId,
        claimantClientId: claimantClientId,
        claimantDetails: claimantDetails,
        diagnosticMode: link.diagnosticMode,
      );
      session.beginExecution();
      executionStarted = true;
      final recipes = [
        for (var index = 0; index < session.recipes.length; index++)
          BuilderRecipeAdapter.toHttpProvider(
            session.recipes[index],
            index: index,
            templateParameters: session.templateParameters(recipe: session.recipes[index]),
          ),
      ];
      if (!context.mounted) {
        throw const ReclaimVerificationCancelledException('Verification context was disposed');
      }
      final reclaim = ReclaimVerification.of(context);
      await reclaim.requestBuilderConsent(session);
      final results = <Map<String, dynamic>>[];
      final proofs = <CreateClaimOutput>[];

      for (var index = 0; index < recipes.length; index++) {
        final provider = recipes[index];
        final recipe = session.recipes[index];
        final parameters = session.templateParameters(recipe: recipe);
        final providerId = provider.name;
        if (providerId == null || providerId.isEmpty) {
          throw const FormatException('Builder recipe providerId is missing');
        }
        final resolvedVersion = recipe['resolvedVersion']?.toString() ?? '';
        final eventData = <String, dynamic>{
          'providerId': providerId,
          'resolvedVersion': resolvedVersion,
          'ordinal': index,
        };
        await session.reportCanonicalEventBestEffort(
          BuilderVerificationEvent.verificationProviderStarted,
          eventData: eventData,
        );
        for (var requestOrdinal = 0; requestOrdinal < provider.requestData.length; requestOrdinal++) {
          await session.reportCanonicalEventBestEffort(
            BuilderVerificationEvent.requestClaimCreated,
            eventData: <String, dynamic>{...eventData, 'requestOrdinal': requestOrdinal, 'attempt': 1},
          );
        }
        final request = ReclaimVerificationRequest(
          applicationId: session.applicationId,
          // Preserve the exact Builder context, including attestationNonceData,
          // in the legacy claimData.context field.
          contextString: session.contextString,
          providerId: providerId,
          parameters: parameters,
          sessionProvider: () => ReclaimSessionInformation(
            sessionId: session!.sessionId,
            // The bridge authorizes the attestor request. These sentinel values
            // only satisfy legacy engine invariants; they are never sent to the
            // legacy session backend in Builder mode.
            signature: 'builder',
            timestamp: 'builder',
            version: ProviderVersionExact(resolvedVersion),
          ),
          builderExecution: BuilderVerificationExecution(
            provider: provider,
            appInfo: session.appInfo,
            diagnosticMode: link.diagnosticMode,
            reportEvent: (event, eventData) async {
              final parsed = BuilderVerificationEvent.fromJson(event);
              if (parsed == null || parsed == BuilderVerificationEvent.unknownDefaultOpenApi) return;
              await session!.reportCanonicalEventBestEffort(
                parsed,
                eventData: <String, dynamic>{
                  ...eventData ?? const <String, dynamic>{},
                  'providerId': providerId,
                  'resolvedVersion': resolvedVersion,
                  'ordinal': index,
                },
              );
            },
            attestorAuthenticationRequest: () async {
              return client.getAttestorAuthentication(session!.sessionId);
            },
          ),
        );
        late final ReclaimVerificationResult response;
        try {
          response = await reclaim.startVerification(
            request: request,
            options: _reclaimVerificationOptions.copyWith(canAutoSubmit: true),
          );
        } catch (error) {
          await session.reportCanonicalEventBestEffort(
            BuilderVerificationEvent.requestClaimFailed,
            eventData: <String, dynamic>{...eventData, 'attempt': 1, ...builderFailureEventData(error)},
          );
          rethrow;
        }
        proofs.addAll(response.proofs);
        for (var claimIndex = 0; claimIndex < response.proofs.length; claimIndex++) {
          final providerRequest = response.proofs[claimIndex].providerRequest;
          final claimEventData = <String, dynamic>{
            ...eventData,
            'requestOrdinal': claimIndex,
            'attempt': 1,
            if (providerRequest?.requestHash != null) 'requestId': providerRequest!.requestHash,
          };
          await session.reportCanonicalEventBestEffort(
            BuilderVerificationEvent.requestClaimCompleted,
            eventData: claimEventData,
          );
        }
        await session.reportCanonicalEventBestEffort(
          BuilderVerificationEvent.verificationProviderCompleted,
          eventData: <String, dynamic>{
            ...eventData,
            'requestCount': provider.requestData.length,
            'proofCount': response.proofs.length,
          },
        );
        results.add(
          BuilderProofResultAdapter.providerResult(
            providerId: providerId,
            resolvedVersion: resolvedVersion,
            proofs: response.proofs,
          ),
        );
      }
      await session.reportCanonicalEventBestEffort(
        BuilderVerificationEvent.verificationProofsCompleted,
        eventData: {
          'expectedProviderCount': recipes.length,
          'completedProviderCount': results.length,
          'expectedRequestCount': recipes.fold<int>(0, (count, provider) => count + provider.requestData.length),
          'completedRequestCount': proofs.length,
          'completedProofCount': proofs.length,
        },
      );
      final resultCounts = <String, dynamic>{
        'expectedProviderCount': recipes.length,
        'completedProviderCount': results.length,
        'expectedRequestCount': recipes.fold<int>(0, (count, provider) => count + provider.requestData.length),
        'completedRequestCount': proofs.length,
        'completedProofCount': proofs.length,
        'attempt': 1,
      };
      await session.reportCanonicalEventBestEffort(
        BuilderVerificationEvent.verificationResultSubmitting,
        eventData: resultCounts,
      );
      try {
        await session.submitResultWithRetry(status: 'success', results: results);
        terminalResultStored = true;
      } catch (error, stackTrace) {
        await session.reportCanonicalEventBestEffort(
          BuilderVerificationEvent.verificationResultSubmissionFailed,
          eventData: {'attempt': 1, 'retryable': true, ...builderFailureEventData(error)},
        );
        return _builderModeFailure(error, stackTrace, session.sessionId);
      }
      return ReclaimApiVerificationResponse(
        sessionId: session.sessionId,
        didSubmitManualVerification: false,
        proofs: _encodeProofs(proofs),
        exception: null,
      );
    } catch (error, stackTrace) {
      _logger.severe('Failed to load Builder verification session', error, stackTrace);
      if (terminalResultStored) return _builderModeFailure(error, stackTrace, sessionId);
      try {
        if (session != null && isBuilderSession(session.sessionId)) {
          await session.reportCanonicalEventBestEffort(
            builderFailureEvent(error),
            eventData: builderFailureEventData(error),
          );
        }
        if (session != null && isBuilderSession(session.sessionId) && builderFailureHasResult(error)) {
          await session.submitResultWithRetry(
            status: builderFailureStatus(error),
            results: const [],
            problem: <String, dynamic>{'detail': error.toString()},
          );
        }
      } catch (bridgeError, bridgeStackTrace) {
        _logger.severe('Failed to report Builder verification error', bridgeError, bridgeStackTrace);
      }
      return _builderModeFailure(error, stackTrace, sessionId);
    } finally {
      if (executionStarted) session?.endExecution();
      if (session != null && !isBuilderSession(session.sessionId)) {
        session.dispose();
      }
    }
  }

  List<Map<String, dynamic>> _encodeProofs(Iterable<CreateClaimOutput> proofs) {
    return (json.decode(json.encode(proofs.toList())) as List).map((proof) => proof as Map<String, dynamic>).toList();
  }

  void _onSessionIdentityUpdate(SessionIdentity? identity) {
    try {
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
    } catch (e, s) {
      _logger.warning(
        'Could not send session identity update to host. Likely no listener is set to receive this event.',
        e,
        s,
      );
    }
  }

  void _sendLogsToHost(LogEntry entry, ReclaimHostOverridesApi overridesHandler) {
    overridesHandler.onLogs(json.encode(entry));
  }

  Future<bool> _assertCanUseCapability(String capabilityName) async {
    final capabilityAccessVerifier = CapabilityAccessVerifier();

    if (await capabilityAccessVerifier.canUse(capabilityName)) {
      return true;
    }

    throw ReclaimVerificationCancelledException('Unauthorized use of capability: $capabilityName');
  }

  Future<bool> _assertCanUseAnyCapability(List<String> capabilityNames) async {
    final capabilityAccessVerifier = CapabilityAccessVerifier();
    for (final capabilityName in capabilityNames) {
      if (await capabilityAccessVerifier.canUse(capabilityName)) {
        return true;
      }
    }

    throw ReclaimVerificationCancelledException('Unauthorized use of capability: $capabilityNames');
  }

  Future<AttestorAuthenticationRequest> _requestAttestorAuthenticationRequestFromHost(HttpProvider provider) async {
    final providerMap = ensureMap<Object?>(provider.toJson())!;
    final result = await hostVerificationApi.fetchAttestorAuthenticationRequest(providerMap);
    try {
      final map = json.decode(result);
      if (map is! Map) {
        throw ReclaimVerificationCancelledException('Invalid attestor authentication request');
      }
      return AttestorAuthenticationRequest.fromJson(map as Map<String, dynamic>);
    } catch (e, s) {
      _logger.severe('Failed to parse attestor authentication request', e, s);
      throw ReclaimVerificationCancelledException('Failed to parse attestor authentication request: ${e.toString()}');
    }
  }

  BuildContext _requireVerificationContext() {
    final ctx = _verificationContext;
    if (ctx == null) {
      throw ReclaimVerificationCancelledException(
        'BuildContext for verification is not set. Please call setVerificationContext before starting verification from a widget which is mounted in widget tree.',
      );
    }
    if (!ctx.mounted) {
      throw ReclaimVerificationCancelledException(
        'BuildContext for verification is not mounted. Please call setVerificationContext before starting verification from a widget which is mounted in widget tree.',
      );
    }
    return ctx;
  }

  Future<ReclaimApiVerificationResponse> _startVerification(
    ReclaimVerificationRequest request,
    String requestSessionId,
  ) async {
    try {
      final context = _requireVerificationContext();
      final reclaimVerification = ReclaimVerification.of(context);

      _logger.event(
        Level.INFO.withEvent(LogEventType.IS_RECLAIM_INAPPSDK),
        'Starting verification with request applicationId: ${request.applicationId}, provider: ${request.providerId}, context: ${request.contextString}, params: ${json.encode(request.parameters)}',
      );

      final response = await reclaimVerification.startVerification(
        request: request,
        options: _reclaimVerificationOptions,
      );

      final effectiveSessionId = SessionIdentity.latest?.sessionId ?? requestSessionId;

      if (response.proofs.isNotEmpty) {
        _logger.event(Level.INFO.withEvent(LogEventType.SUBMITTING_PROOF), 'submitting proof');
      }

      final encodableProofs = (json.decode(json.encode(response.proofs)) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (response.proofs.isNotEmpty) {
        final isAIProofs = () {
          try {
            return areParamsFromAIProofs(response.proofs);
          } catch (e, s) {
            _logger.severe('Failed to check whether proof is AI proof', e, s);
            return false;
          }
        }();

        _logger.event(Level.INFO.withEvent(LogEventType.SUBMITTING_PROOF), 'submitted proof');

        final sessionManager = SessionManager();
        sessionManager.onProofSubmitted(
          applicationId: request.applicationId,
          providerId: request.providerId,
          sessionId: effectiveSessionId,
          isAIProofs: isAIProofs,
          isInAppSdk: true,
        );
      } else {
        _logger.event(Level.SEVERE.withEvent(LogEventType.PROOF_SUBMISSION_FAILED), 'proof submission failed');

        final sessionManager = SessionManager();
        sessionManager.onProofSubmissionFailed(
          applicationId: request.applicationId,
          providerId: request.providerId,
          sessionId: effectiveSessionId,
          isInAppSdk: true,
        );
      }

      return ReclaimApiVerificationResponse(
        sessionId: effectiveSessionId,
        didSubmitManualVerification: false,
        proofs: encodableProofs,
        exception: null,
      );
    } catch (e, s) {
      final effectiveSessionId = SessionIdentity.latest?.sessionId ?? requestSessionId;
      _logger.event(Level.SEVERE.withEvent(LogEventType.PROOF_SUBMISSION_FAILED), 'Failed verification response', e, s);

      final sessionManager = SessionManager();
      sessionManager.onProofSubmissionFailed(
        applicationId: request.applicationId,
        providerId: request.providerId,
        sessionId: effectiveSessionId,
        isInAppSdk: true,
      );

      return ReclaimApiVerificationResponse(
        sessionId: effectiveSessionId,
        didSubmitManualVerification: e is ReclaimVerificationManualReviewException,
        proofs: const [],
        exception: ReclaimApiVerificationException(
          message: e.toString(),
          stackTraceAsString: s.toString(),
          type: _fromExceptionToApiExceptionType(e),
        ),
      );
    }
  }

  ReclaimApiVerificationExceptionType _fromExceptionToApiExceptionType(Object e) {
    if (e is ReclaimException) {
      switch (e) {
        case ReclaimVerificationCancelledException():
          return ReclaimApiVerificationExceptionType.verificationCancelled;
        case ReclaimVerificationDismissedException():
        case ReclaimVerificationSkippedException():
          return ReclaimApiVerificationExceptionType.verificationDismissed;
        case ReclaimExpiredSessionException():
        case ReclaimInitSessionException():
          return ReclaimApiVerificationExceptionType.sessionExpired;
        case ReclaimVerificationProviderScriptException():
        case ReclaimVerificationNoActivityDetectedException():
        case ReclaimVerificationRequirementException():
        case ReclaimVerificationProviderLoadException():
        case ReclaimAttestorException():
        case ReclaimVerificationProviderFailedException():
          return ReclaimApiVerificationExceptionType.verificationFailed;
      }
    }
    return ReclaimApiVerificationExceptionType.unknown;
  }
}
