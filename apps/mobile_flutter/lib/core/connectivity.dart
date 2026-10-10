import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone has a network connection. Wrapped so tests can fake it.
/// This reports the network interface (Wi-Fi or mobile data), not whether the
/// internet is actually reachable, so it only drives a gentle banner and never blocks anything.
abstract class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get onChanged;
}

class PlatformConnectivityService implements ConnectivityService {
  const PlatformConnectivityService();

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async => _online(await Connectivity().checkConnectivity());

  @override
  Stream<bool> get onChanged => Connectivity().onConnectivityChanged.map(_online);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) => const PlatformConnectivityService());

/// true while online (assumed online until the first check answers).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline();
  yield* service.onChanged;
});
