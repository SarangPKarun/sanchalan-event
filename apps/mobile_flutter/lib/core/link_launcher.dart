import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens things outside the app (phone dialer, WhatsApp, browser, mail).
/// Each method returns false when nothing could handle it.
abstract class LinkLauncher {
  Future<bool> call(String phoneNumber);
  Future<bool> whatsApp(String phoneNumber);
  Future<bool> openUrl(String url);
  Future<bool> email(String address);
}

class UrlLauncherService implements LinkLauncher {
  const UrlLauncherService();

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> call(String phoneNumber) => _launch(Uri(scheme: 'tel', path: phoneNumber));

  /// `https://wa.me/<digits>` opens WhatsApp when installed and a web page otherwise.
  @override
  Future<bool> whatsApp(String phoneNumber) =>
      _launch(Uri.https('wa.me', '/${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}'));

  @override
  Future<bool> openUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return Future.value(false);
    return _launch(uri);
  }

  @override
  Future<bool> email(String address) => _launch(Uri(scheme: 'mailto', path: address));
}

final linkLauncherProvider = Provider<LinkLauncher>((ref) => const UrlLauncherService());
