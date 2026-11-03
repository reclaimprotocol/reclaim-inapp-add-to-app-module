// Post-processes Pigeon output after `make generate`. Swift: restores the
// released `Sendable?` signatures. Kotlin: strips trailing whitespace only.
import 'dart:io';

const _swiftOutput = 'generated/ios/Sources/ReclaimInAppSdk/Messages.swift';
const _kotlinOutput = 'generated/android/src/main/java/org/reclaimprotocol/inapp_sdk/Messages.kt';

void main() {
  _preserveSwiftSendableSignatures();
  _removeKotlinTrailingWhitespace();
}

/// Restores the released `Sendable?` Swift signatures that Pigeon cannot emit.
///
/// Pigeon v27.3.0's Swift generator writes untyped JSON maps as
/// `[String: Any?]?`, `[[String: Any?]]` and `[AnyHashable?: Any?]`, which are
/// not `Sendable` under Swift 6 strict concurrency. Module 0.43.0 and earlier
/// ship the `Sendable?` forms in public protocols (for example
/// `ReclaimHostOverridesApiProtocol.updateSession`/`logSession` metadata,
/// `ReclaimApiVerificationResponse.proofs`, `startVerificationFromJson` and
/// `fetchAttestorAuthenticationRequest`). Rewriting them after every
/// regeneration keeps iOS hosts source-compatible; removing this step would be
/// a breaking change.
///
/// Kotlin needs no rewrite: Pigeon's `Any?` maps already match the released
/// Android API.
///
/// [_replaceRequired] throws when a pattern is missing, so a Pigeon upgrade that
/// changes the output gets reviewed instead of silently skipped.
void _preserveSwiftSendableSignatures() {
  final file = File(_swiftOutput);
  var source = file.readAsStringSync();

  source = _replaceRequired(source, '[[String: Any?]]', '[[String: Sendable?]]');
  source = _replaceRequired(source, '[String: Any?]?', '[String: Sendable?]?');
  source = _replaceRequired(source, '[AnyHashable?: Any?]', '[AnyHashable?: Sendable?]');

  file.writeAsStringSync(source);
}

void _removeKotlinTrailingWhitespace() {
  final file = File(_kotlinOutput);
  final source = file.readAsStringSync();
  file.writeAsStringSync(source.replaceAll(RegExp(r'[ \t]+$', multiLine: true), ''));
}

String _replaceRequired(String source, String generated, String compatible) {
  if (!source.contains(generated)) {
    throw StateError('Pigeon output no longer contains $generated. Review the Swift compatibility transform.');
  }
  return source.replaceAll(generated, compatible);
}
