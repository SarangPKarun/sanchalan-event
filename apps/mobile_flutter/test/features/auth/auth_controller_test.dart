import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/core/providers.dart';
import 'package:sanchalan/features/auth/auth_controller.dart';
import 'package:sanchalan/features/auth/auth_state.dart';
import 'package:sanchalan/features/organizer/organizer_providers.dart';
import 'package:sanchalan/models/auth.dart';
import 'package:sanchalan/models/enums.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

void main() {
  const session = {
    accessTokenKey: 'old',
    refreshTokenKey: 'refresh-1',
    roleKey: 'vendor',
  };

  group('restore on start', () {
    test('no stored session -> unauthed', () async {
      final (c, adapter) = makeContainer(routes({}));
      expect(await settledAuth(c), const AuthState.unauthed());
      expect(adapter.requests, isEmpty);
    });

    test(
      'valid refresh token + stored role -> authed with a new access token',
      () async {
        final (c, _) = makeContainer(
          routes({
            'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
          }),
          secure: session,
        );
        expect(await settledAuth(c), const AuthState.authed(AuthRole.vendor));
        expect(await c.read(authStorageProvider).getAccessToken(), 'new');
        expect(
          await c.read(authStorageProvider).getRefreshToken(),
          'refresh-1',
        );
      },
    );

    test(
      'stored role missing -> tokens cleared, unauthed (force re-login)',
      () async {
        final (c, _) = makeContainer(
          routes({
            'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
          }),
          secure: {accessTokenKey: 'old', refreshTokenKey: 'refresh-1'},
        );
        expect(await settledAuth(c), const AuthState.unauthed());
        expect(await c.read(authStorageProvider).getRefreshToken(), isNull);
      },
    );

    for (final status in [401, 403]) {
      test('refresh rejected ($status) -> cleared, unauthed', () async {
        final (c, _) = makeContainer(
          routes({
            'POST /auth/refresh': (_) => jsonBody({'error': 'revoked'}, status),
          }),
          secure: session,
        );
        expect(await settledAuth(c), const AuthState.unauthed());
        expect(await c.read(authStorageProvider).getRefreshToken(), isNull);
      });
    }

    test('server error + cached role -> authed, session kept', () async {
      final (c, _) = makeContainer(
        routes({
          'POST /auth/refresh': (_) => jsonBody({'error': 'boom'}, 503),
        }),
        secure: session,
      );
      expect(await settledAuth(c), const AuthState.authed(AuthRole.vendor));
      expect(await c.read(authStorageProvider).getRefreshToken(), 'refresh-1');
    });

    test('offline + no cached role -> unauthed, tokens kept', () async {
      final (c, _) = makeContainer(
        (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
        secure: {accessTokenKey: 'old', refreshTokenKey: 'refresh-1'},
      );
      expect(await settledAuth(c), const AuthState.unauthed());
      expect(await c.read(authStorageProvider).getRefreshToken(), 'refresh-1');
    });
  });

  group('signIn / signOut', () {
    test('signIn stores tokens and role and flips to authed', () async {
      final (c, _) = makeContainer(routes({}));
      await settledAuth(c);
      await c
          .read(authControllerProvider.notifier)
          .signIn(
            const AuthTokens(
              accessToken: 'a',
              refreshToken: 'r',
              role: AuthRole.organizer,
              userId: 'u1',
            ),
          );
      expect(
        c.read(authControllerProvider),
        const AuthState.authed(AuthRole.organizer),
      );
      final storage = c.read(authStorageProvider);
      expect(await storage.getAccessToken(), 'a');
      expect(await storage.getRefreshToken(), 'r');
      expect(await storage.getRole(), AuthRole.organizer);
    });

    test('signOut calls /auth/logout and clears everything', () async {
      final (c, adapter) = makeContainer(
        routes({
          'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
          'POST /auth/logout': (_) => jsonBody({}),
        }),
        secure: session,
      );
      await settledAuth(c);
      await c.read(authControllerProvider.notifier).signOut();

      expect(adapter.last('/auth/logout').data, {'refreshToken': 'refresh-1'});
      expect(c.read(authControllerProvider), const AuthState.unauthed());
      expect(await c.read(authStorageProvider).getRefreshToken(), isNull);
      expect(await c.read(authStorageProvider).getRole(), isNull);
    });

    test('signOut still clears local state when /auth/logout fails', () async {
      final (c, _) = makeContainer(
        routes({
          'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
          'POST /auth/logout': (_) => jsonBody({'error': 'boom'}, 500),
        }),
        secure: session,
      );
      await settledAuth(c);
      await c.read(authControllerProvider.notifier).signOut();
      expect(c.read(authControllerProvider), const AuthState.unauthed());
      expect(await c.read(authStorageProvider).getRefreshToken(), isNull);
    });
  });

  group('session expiry from the API client', () {
    test('a dead session mid-use flips to unauthed', () async {
      final (c, _) = makeContainer(
        routes({
          'POST /auth/refresh': (o) {
            // First call restores the session; later calls are rejected.
            return o.data['refreshToken'] == 'refresh-1' && !_revoked
                ? jsonBody({'accessToken': 'new'})
                : jsonBody({'error': 'revoked'}, 401);
          },
          'GET /something': (_) => jsonBody({'error': 'expired'}, 401),
        }),
        secure: session,
      );
      _revoked = false;
      expect(await settledAuth(c), const AuthState.authed(AuthRole.vendor));

      _revoked = true;
      await expectLater(
        c.read(dioProvider).get<void>('/something'),
        throwsA(isA<DioException>()),
      );
      expect(c.read(authControllerProvider), const AuthState.unauthed());
      expect(await c.read(authStorageProvider).getRefreshToken(), isNull);
    });

    test(
      'the next sign-in starts with fresh organizer data, sign-out makes no request',
      () async {
        final (c, adapter) = makeContainer(
          routes({
            'POST /auth/refresh': (_) => jsonBody({'accessToken': 'new'}),
            'POST /auth/logout': (_) => jsonBody({}),
            'GET /organizers/me': (_) => fixtureBody('organizer_me_fresh'),
          }),
          secure: {...session, roleKey: 'organizer'},
        );
        await settledAuth(c);
        final sub = c.listen(organizerDataProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(organizerDataProvider.future);
        expect(adapter.count('/organizers/me'), 1);

        await c.read(authControllerProvider.notifier).signOut();
        expect(adapter.count('/organizers/me'), 1);

        await c
            .read(authControllerProvider.notifier)
            .signIn(
              const AuthTokens(
                accessToken: 'a2',
                refreshToken: 'r2',
                role: AuthRole.organizer,
                userId: 'u2',
              ),
            );
        await c.read(organizerDataProvider.future);
        expect(adapter.count('/organizers/me'), 2);
      },
    );
  });
}

bool _revoked = false;
