import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/auth.dart';
import '../organizer/organizer_providers.dart';
import '../vendor/vendor_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// Session state. Port of apps/mobile/lib/auth-context.tsx.
/// The router (Step 5) redirects based on this.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.listen(sessionExpiredProvider, (_, _) => _onSessionExpired());
    Future.microtask(_restore);
    return const AuthState.loading();
  }

  /// Resume a stored session on app start.
  Future<void> _restore() async {
    final storage = ref.read(authStorageProvider);
    final refreshToken = await storage.getRefreshToken();
    if (!ref.mounted) return;
    if (refreshToken == null) {
      state = const AuthState.unauthed();
      return;
    }
    try {
      final accessToken = await ref.read(authRepositoryProvider).refresh(refreshToken);
      await storage.setAccessToken(accessToken);
      // /auth/refresh only returns a new access token; the role was persisted
      // by signIn, so it is read back from there.
      final role = await storage.getRole();
      if (!ref.mounted) return;
      if (role == null) {
        // No role means no screen is reachable. Force a fresh sign-in instead.
        await storage.clear();
        if (!ref.mounted) return;
        state = const AuthState.unauthed();
        return;
      }
      state = AuthState.authed(role);
    } catch (e) {
      if (isAuthRejection(e)) {
        await storage.clear();
        if (!ref.mounted) return;
        state = const AuthState.unauthed();
        return;
      }
      // Transient failure (offline, timeout, 5xx): keep the stored session and
      // enter the app; the API client refreshes lazily on the next 401.
      final cachedRole = await storage.getRole();
      if (!ref.mounted) return;
      state = cachedRole == null ? const AuthState.unauthed() : AuthState.authed(cachedRole);
    }
  }

  Future<void> signIn(AuthTokens tokens) async {
    final storage = ref.read(authStorageProvider);
    await storage.setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    await storage.setRole(tokens.role);
    state = AuthState.authed(tokens.role);
  }

  Future<void> signOut() async {
    final storage = ref.read(authStorageProvider);
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken != null) await ref.read(authRepositoryProvider).logout(refreshToken);
    } catch (_) {
      // Best-effort: local state is cleared regardless.
    } finally {
      await storage.clear();
      _reset();
    }
  }

  /// The API client already cleared the tokens; just reflect it.
  void _onSessionExpired() => _reset();

  void _reset() {
    if (!ref.mounted) return;
    state = const AuthState.unauthed();
    // The next login must not see the previous user's data.
    ref.invalidate(organizerDataProvider);
    ref.invalidate(vendorDataProvider);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
