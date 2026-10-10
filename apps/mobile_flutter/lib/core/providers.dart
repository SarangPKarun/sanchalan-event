import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Bumped by the API client when the session is dead (refresh rejected, tokens
/// already cleared). The auth controller listens and flips to unauthed; this
/// indirection keeps the client free of any dependency on the auth layer.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: ref.watch(authStorageProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).bump(),
  );
});

/// The configured Dio instance. Repositories take this.
final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
