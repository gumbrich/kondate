class SyncStatus {
  final DateTime? lastPulledAt;
  final DateTime? lastPushedAt;
  final String? lastError;

  const SyncStatus({
    required this.lastPulledAt,
    required this.lastPushedAt,
    required this.lastError,
  });

  const SyncStatus.initial()
      : lastPulledAt = null,
        lastPushedAt = null,
        lastError = null;

  SyncStatus pulledNow() {
    return SyncStatus(
      lastPulledAt: DateTime.now(),
      lastPushedAt: lastPushedAt,
      lastError: null,
    );
  }

  SyncStatus pushedNow() {
    return SyncStatus(
      lastPulledAt: lastPulledAt,
      lastPushedAt: DateTime.now(),
      lastError: null,
    );
  }

  SyncStatus withError(String error) {
    return SyncStatus(
      lastPulledAt: lastPulledAt,
      lastPushedAt: lastPushedAt,
      lastError: error,
    );
  }
}
