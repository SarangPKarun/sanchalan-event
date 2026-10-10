import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Called when the session is dead (refresh rejected). The auth provider
/// (Step 4) overrides this to reset auth state; go_router then redirects to /phone.
final sessionExpiredCallbackProvider = Provider<void Function()>((ref) => () {});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: ref.watch(authStorageProvider),
    onSessionExpired: () => ref.read(sessionExpiredCallbackProvider)(),
  );
});

/// The configured Dio instance. Prefer this in repositories.
final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
