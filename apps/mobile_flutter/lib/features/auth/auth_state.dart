import '../../models/enums.dart';

enum AuthStatus { loading, authed, unauthed }

class AuthState {
  const AuthState._(this.status, this.role);

  const AuthState.loading() : this._(AuthStatus.loading, null);
  const AuthState.unauthed() : this._(AuthStatus.unauthed, null);
  const AuthState.authed(AuthRole role) : this._(AuthStatus.authed, role);

  final AuthStatus status;

  /// Set only while [status] is [AuthStatus.authed].
  final AuthRole? role;

  bool get isAuthed => status == AuthStatus.authed;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status && other.role == role;

  @override
  int get hashCode => Object.hash(status, role);

  @override
  String toString() => 'AuthState($status, $role)';
}
