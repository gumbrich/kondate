class SyncStatus {
  final DateTime? lastPulledAt;
  final DateTime? lastPushedAt;
  final String? lastRemoteUpdatedAt;
  final String? lastError;

  const SyncStatus({
    required this.lastPulledAt,
    required this.lastPushedAt,
    required this.lastRemoteUpdatedAt,
    required this.lastError,
  });

  const SyncStatus.initial()
      : lastPulledAt = null,
        lastPushedAt = null,
        lastRemoteUpdatedAt = null,
        lastError = null;

  SyncStatus pulledNow({required String remoteUpdatedAt}) {
    return SyncStatus(
      lastPulledAt: DateTime.now(),
      lastPushedAt: lastPushedAt,
      lastRemoteUpdatedAt: remoteUpdatedAt,
      lastError: null,
    );
  }

  SyncStatus pushedNow() {
    return SyncStatus(
      lastPulledAt: lastPulledAt,
      lastPushedAt: DateTime.now(),
      lastRemoteUpdatedAt: lastRemoteUpdatedAt,
      lastError: null,
    );
  }

  SyncStatus withError(String error) {
    return SyncStatus(
      lastPulledAt: lastPulledAt,
      lastPushedAt: lastPushedAt,
      lastRemoteUpdatedAt: lastRemoteUpdatedAt,
      lastError: error,
    );
  }
}
