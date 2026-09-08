import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:reclaim_inapp_sdk/capability_access.dart';
import 'package:reclaim_inapp_sdk/logging.dart';
import 'package:reclaim_inapp_sdk/overrides.dart';
import 'package:reclaim_inapp_sdk/reclaim_inapp_sdk.dart';
import 'package:reclaim_inapp_sdk/ui.dart';
import 'package:reclaim_inapp_sdk/utils.dart';
// ignore: implementation_imports
import 'package:reclaim_tee_operator_flutter/src/common/download/download.dart' show downloadWithHttp;

import '../utils/json.dart';
import 'pigeon/messages.pigeon.dart';

part 'api_impl.dart';
part 'api_session.dart';

abstract interface class ReclaimModuleExternalApi extends ReclaimModuleApi {
  factory ReclaimModuleExternalApi() = _ReclaimModuleExternalApiImpl;

  Future<void> setSessionIdentityListener(void Function(SessionIdentity?)? onSessionIdentity);

  void setVerificationContext(BuildContext context);

  /// Configures direct Builder transport used by `api=2` links.
  ///
  /// [baseUrl] must be HTTPS. [verificationClientId] is the registered
  /// Verification Client UUID sent as `x-reclaim-vc-id`, not a signing secret.
  Future<void> configureBuilderVerification({required String baseUrl, required String verificationClientId});

  /// Sets the Builder transport override used by `api=2` links.
  @override
  Future<void> setBuilderModeOverrides(ClientBuilderModeOverrides overrides);

  @override
  Future<void> setOverrides(
    ClientProviderInformationOverride? provider,
    ClientFeatureOverrides? feature,
    ClientLogConsumerOverride? logConsumer,
    ClientReclaimSessionManagementOverride? sessionManagement,
    ClientReclaimAppInfoOverride? appInfo,
    String? capabilityAccessToken, {
    ReclaimHostOverridesApi? overridesHandlerApi,
  });

  void dispose();
}
