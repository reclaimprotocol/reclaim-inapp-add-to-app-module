import 'dart:convert';

T? fromStringToObject<T>({
  required String content,
  required T Function(Map<String, dynamic>) fromJson,
  required void Function(Object e, StackTrace s) onInvalidContent,
}) {
  try {
    final map = json.decode(content);
    if (map is! Map) {
      onInvalidContent(FormatException('decoded json string wasn\'t a map'), StackTrace.current);
      return null;
    }
    return fromJson(map as Map<String, dynamic>);
  } catch (e, s) {
    onInvalidContent(e, s);
    return null;
  }
}
