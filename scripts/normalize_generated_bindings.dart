// Post-processes Pigeon output after `make gen_schema`, restoring the released
// native API that Pigeon v27.3.0 cannot generate on its own.
//
// Pigeon copies a schema `dynamic` verbatim into Kotlin and Swift
// (`Map<String, dynamic>`, `[String: dynamic]`), which neither language has.
// Releases up to 0.43.0 hand-edited the generated files; the schema now uses
// `Object?` instead, which Pigeon maps to `Any?` on both platforms, and this
// script does the rest:
//
// - Both: fail if `dynamic` reappears.
// - Swift: `Any?` JSON maps become the released `Sendable?` forms, and the
//   `MessagesBinaryMessenger` typealias is restored.
// - Kotlin: `Any?` already matches the released API; trailing whitespace is
//   stripped.
//
// Run it once on fresh Pigeon output: the Swift rewrites require the `Any?`
// forms to be present.
import 'dart:io';

const _swiftOutput = 'generated/ios/Sources/ReclaimInAppSdk/Messages.swift';
const _kotlinOutput = 'generated/android/src/main/java/org/reclaimprotocol/inapp_sdk/Messages.kt';

void main() {
  _rejectDynamic(_swiftOutput);
  _rejectDynamic(_kotlinOutput);
  _preserveSwiftSendableSignatures();
  _stripKotlinTrailingWhitespace();
}

/// Neither Kotlin nor Swift has a `dynamic` type; type the schema field as
/// `Object?` instead.
void _rejectDynamic(String path) {
  if (RegExp(r'\bdynamic\b').hasMatch(File(path).readAsStringSync())) {
    throw StateError('Pigeon emitted `dynamic` in $path. Type the schema field as `Object?`.');
  }
}

/// Restores the released Swift API that Pigeon cannot emit.
///
/// Pigeon writes untyped JSON maps as `[String: Any?]?`, `[[String: Any?]]`
/// and `[AnyHashable?: Any?]`, which are not `Sendable` under Swift 6 strict
/// concurrency. Module 0.43.0 and earlier ship the `Sendable?` forms in public
/// protocols (for example `ReclaimHostOverridesApiProtocol.updateSession` /
/// `logSession` metadata, `ReclaimApiVerificationResponse.proofs`,
/// `startVerificationFromJson` and `fetchAttestorAuthenticationRequest`), and
/// declare `typealias MessagesBinaryMessenger = any FlutterBinaryMessenger`,
/// which Pigeon does not generate.
///
/// Removing this step would break existing iOS hosts. [_replaceRequired]
/// throws when a pattern is missing, so a Pigeon upgrade that changes the
/// output gets reviewed instead of silently skipped.
void _preserveSwiftSendableSignatures() {
  final file = File(_swiftOutput);
  var source = file.readAsStringSync();

  source = _replaceRequired(source, '[[String: Any?]]', '[[String: Sendable?]]');
  source = _replaceRequired(source, '[String: Any?]?', '[String: Sendable?]?');
  source = _replaceRequired(source, '[AnyHashable?: Any?]', '[AnyHashable?: Sendable?]');

  const messengerAlias = 'typealias MessagesBinaryMessenger = any FlutterBinaryMessenger';
  if (!source.contains(messengerAlias)) {
    // Declared right after the platform `import` block, as in released modules.
    source = _replaceRequired(source, '#endif\n\n', '#endif\n\n$messengerAlias\n\n', firstOnly: true);
  }

  file.writeAsStringSync(source);
}

void _stripKotlinTrailingWhitespace() {
  final file = File(_kotlinOutput);
  file.writeAsStringSync(file.readAsStringSync().replaceAll(RegExp(r'[ \t]+$', multiLine: true), ''));
}

String _replaceRequired(String source, String generated, String compatible, {bool firstOnly = false}) {
  if (!source.contains(generated)) {
    throw StateError('Pigeon output no longer contains $generated. Review the generated-bindings transform.');
  }
  return firstOnly ? source.replaceFirst(generated, compatible) : source.replaceAll(generated, compatible);
}
