import 'dart:io';

const _swiftOutput = 'generated/ios/Sources/ReclaimInAppSdk/Messages.swift';
const _kotlinOutput = 'generated/android/src/main/java/org/reclaimprotocol/inapp_sdk/Messages.kt';

void main() {
  _preserveSwiftSendableSignatures();
  _removeKotlinTrailingWhitespace();
}

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
