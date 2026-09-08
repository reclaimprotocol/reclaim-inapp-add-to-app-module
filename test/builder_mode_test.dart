import 'package:flutter_test/flutter_test.dart';
import 'package:reclaim_verifier_module/reclaim_verifier_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ReclaimOverride.clearAll);

  test('api=2 is Builder mode', () {
    final link = ReclaimVerificationLink.fromUri(
      Uri.parse('https://verify.example.test/?sessionId=session-1&api=2&redirect_uri=host%3A%2F%2Fdone'),
    );

    expect(link.mode, ReclaimVerificationMode.builder);
    expect(link.sessionId, 'session-1');
    expect(link.uri.queryParameters['redirect_uri'], 'host://done');
  });

  test('unknown api values remain legacy', () {
    expect(
      ReclaimVerificationLink.fromUri(Uri.parse('https://verify.example.test/?api=1&template=%7B%7D')).mode,
      ReclaimVerificationMode.legacy,
    );
  });

  test('rejects a Builder URL without a session before transport setup', () async {
    final api = ReclaimModuleExternalApi();
    addTearDown(api.dispose);

    final response = await api.startVerificationFromUrl('https://verify.example.test/?api=2');

    expect(response.sessionId, 'unknown');
    expect(response.exception?.message, contains('require a sessionId'));
  });

  test('configures Builder transport without replacing legacy overrides', () async {
    const featureOverride = ReclaimFeatureFlagData(cookiePersist: true);
    ReclaimOverride.set(featureOverride);
    final api = ReclaimModuleExternalApi();
    addTearDown(api.dispose);

    await api.setBuilderModeOverrides(
      ClientBuilderModeOverrides(
        baseUrl: 'https://builder.example.test',
        verificationClientId: '550e8400-e29b-41d4-a716-446655440000',
      ),
    );

    expect(ReclaimOverrides.builderVerification?.baseUrl, 'https://builder.example.test');
    expect(ReclaimOverrides.builderVerification?.verificationClientId, '550e8400-e29b-41d4-a716-446655440000');
    expect(ReclaimOverrides.featureFlag, same(featureOverride));

    await api.clearAllOverrides();

    expect(ReclaimOverrides.builderVerification, isNull);
    expect(ReclaimOverrides.featureFlag, isNull);
  });

  test('rejects an insecure Builder override before verification starts', () async {
    final api = ReclaimModuleExternalApi();
    addTearDown(api.dispose);

    await expectLater(
      api.setBuilderModeOverrides(
        ClientBuilderModeOverrides(
          baseUrl: 'http://builder.example.test',
          verificationClientId: '550e8400-e29b-41d4-a716-446655440000',
        ),
      ),
      throwsArgumentError,
    );
  });
}
