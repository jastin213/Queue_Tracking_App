/// Combines device and profile read history without discarding older keys.
///
/// Keys are opaque identities: legacy and per-event keys remain distinct, and
/// unknown historical keys must survive synchronization between app versions.
Set<String> mergeAdminNotificationReadKeys(
  Iterable<String> existing,
  dynamic stored,
) {
  final merged = <String>{};

  void addKey(Object? value) {
    if (value is! String) return;
    final key = value.trim();
    if (key.isNotEmpty) merged.add(key);
  }

  for (final key in existing) {
    addKey(key);
  }
  if (stored is Iterable) {
    for (final value in stored) {
      addKey(value);
    }
  }

  return merged;
}

/// Returns only device keys missing from the profile, ready for arrayUnion.
/// Never use this difference as a replacement for the full cloud history.
List<String> adminNotificationReadKeysToSync({
  required Iterable<String> local,
  required dynamic cloud,
}) {
  final localKeys = mergeAdminNotificationReadKeys(local, null);
  final cloudKeys = mergeAdminNotificationReadKeys(const <String>[], cloud);
  return localKeys.difference(cloudKeys).toList()..sort();
}
