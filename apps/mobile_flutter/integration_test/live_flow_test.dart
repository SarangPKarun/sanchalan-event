// End-to-end check against a real backend, run on a real device:
//
//   adb reverse tcp:3000 tcp:3000
//   flutter test integration_test/live_flow_test.dart -d <device> \
//     --dart-define=API_URL=http://localhost:3000 --dart-define=ADMIN_PASSWORD=...
//
// It creates throwaway accounts (phone numbers derived from the clock) and relies on the
// backend's fixed development OTP (123456). Not part of the normal `flutter test` run.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/auth_storage.dart';
import 'package:sanchalan/core/config.dart';
import 'package:sanchalan/core/providers.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/router.dart';
import 'package:sanchalan/features/organizer/widgets/task_tile.dart';
import 'package:sanchalan/shared/widgets/app_text_field.dart';

const adminPassword = String.fromEnvironment('ADMIN_PASSWORD');
const otp = '123456';

final stamp = (DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
final organizerPhone = '98765$stamp';
final vendorPhone = '98764$stamp';
final eventName = 'Live Test Wedding $stamp';
final businessName = 'Live Test Photos $stamp';

/// Pumps until [finder] matches, failing with [what] after [timeout]. Real network calls
/// and spinners make pumpAndSettle unreliable here.
Future<void> waitFor(WidgetTester tester, Finder finder, String what, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  debugPrint('WAIT $what');
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .toList();
  final shown = texts.length <= 50 ? texts : [...texts.take(15), '...', ...texts.skip(texts.length - 30)];
  fail('Timed out after ${timeout.inSeconds}s waiting for: $what\nLocation: ${location(tester)}\nOn screen: ${shown.join(' | ')}');
}

Future<void> tapAndPump(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 400));
}

/// For forms and sheets: scroll the target into view first (the phone screen is smaller than the test viewport).
Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 300));
  await tapAndPump(tester, f);
}

Finder input(String label) =>
    find.descendant(of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SanchalanApp)));

String location(WidgetTester tester) => container(tester).read(routerProvider).state.uri.path;

Future<void> startApp(WidgetTester tester, {bool signedOut = true}) async {
  if (signedOut) await const FlutterSecureStorage().deleteAll();
  await tester.pumpWidget(const ProviderScope(child: SanchalanApp()));
  await tester.pump(const Duration(seconds: 1));
  // Log every API call with its result and duration, so a failure can be read from the test output.
  final dio = container(tester).read(dioProvider);
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) {
      o.extra['t0'] = DateTime.now().millisecondsSinceEpoch;
      h.next(o);
    },
    onResponse: (r, h) {
      final ms = DateTime.now().millisecondsSinceEpoch - (r.requestOptions.extra['t0'] as int);
      debugPrint('API ${r.requestOptions.method} ${r.requestOptions.path} -> ${r.statusCode} (${ms}ms)');
      h.next(r);
    },
    onError: (e, h) {
      final ms = DateTime.now().millisecondsSinceEpoch - ((e.requestOptions.extra['t0'] as int?) ?? 0);
      debugPrint('API ${e.requestOptions.method} ${e.requestOptions.path} -> ${e.response?.statusCode ?? e.type.name} (${ms}ms) ${e.response?.data ?? e.message}');
      h.next(e);
    },
  ));
}

/// Welcome, phone and OTP screens.
Future<void> signIn(WidgetTester tester, String phone, {required bool vendor}) async {
  await waitFor(tester, find.text('Get started'), 'welcome screen');
  await tapAndPump(tester, find.text('Get started'));
  await waitFor(tester, find.text('Send code'), 'phone screen');
  if (vendor) await tapAndPump(tester, find.text("I'm a vendor"));
  await tester.enterText(find.byType(TextField), phone);
  await tester.pump(const Duration(milliseconds: 300));
  await tapAndPump(tester, find.text('Send code'));
  await waitFor(tester, find.text('Enter the code'), 'OTP screen after sending a code');
  await tester.enterText(find.byType(EditableText), otp);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> signOut(WidgetTester tester, {required bool vendor}) async {
  if (vendor) {
    await tapAndPump(tester, find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapAndPump(tester, find.text('Sign out'));
  } else {
    await tapAndPump(tester, find.text('Profile'));
    await tapAndPump(tester, find.text('Sign out'));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')));
  await waitFor(tester, find.text('Get started'), 'welcome screen after signing out');
}

Future<Dio> adminClient() async {
  final dio = Dio(BaseOptions(baseUrl: apiUrl, validateStatus: (_) => true));
  final login = await dio.post<Map<String, dynamic>>('/admin/auth/login', data: {
    'email': 'admin@sanchalan.internal',
    'password': adminPassword,
  });
  expect(login.statusCode, 200, reason: 'admin login failed: ${login.data}');
  dio.options.headers['Authorization'] = 'Bearer ${login.data!['accessToken']}';
  return dio;
}

/// Approves the pending vendor with [name] the way an admin would.
Future<void> approveVendor(String name) async {
  final dio = await adminClient();
  final list = await dio.get<Map<String, dynamic>>('/admin/vendors', queryParameters: {'status': 'pending_review'});
  final vendors = (list.data!['vendors'] as List).cast<Map<String, dynamic>>();
  final vendor = vendors.firstWhere((v) => v['businessName'] == name, orElse: () => fail('No pending vendor named $name'));
  final res = await dio.post<Map<String, dynamic>>('/admin/vendors/${vendor['id']}/approve');
  expect(res.statusCode, 200, reason: 'approve failed: ${res.data}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('organizer: sign up, create an event, build the plan, edit tasks and budget', (tester) async {
    await startApp(tester);
    expect(location(tester), AppPaths.welcome);
    await signIn(tester, organizerPhone, vendor: false);

    // Profile setup
    await waitFor(tester, find.text('Tell us about you'), 'profile setup after a correct code');
    await tester.enterText(find.byType(TextField), 'Live Tester');
    await tapAndPump(tester, find.text('Family'));
    await tapAndPump(tester, find.text('Continue'));
    await waitFor(tester, find.text('Plan your first event'), 'empty home after profile setup');

    // New event (the server asks an LLM for the budget split)
    await tapAndPump(tester, find.text('Create event'));
    await waitFor(tester, find.text('Create event'), 'event form');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), eventName);
    await tester.enterText(fields.at(1), 'Pune');
    await tester.enterText(fields.at(2), '200');
    await tester.enterText(fields.at(3), '15,00,000');
    await tester.pump(const Duration(milliseconds: 300));
    await tapVisible(tester, find.text('Choose a date'));
    await waitFor(tester, find.text('OK'), 'date picker');
    await tapAndPump(tester, find.text('OK'));
    await tapVisible(tester, find.text('Create event'));
    await waitFor(tester, find.text('Get your roadmap'), 'new event opened', timeout: const Duration(seconds: 120));
    expect(location(tester), startsWith('/event-home/'));

    // Roadmap (LLM)
    await tapAndPump(tester, find.text('Generate my roadmap'));
    await waitFor(tester, find.textContaining('tasks done'), 'generated roadmap', timeout: const Duration(seconds: 180));
    expect(find.byType(TaskTile), findsWidgets);

    // Finish the first task
    String allCount() => (find.textContaining('All (').evaluate().first.widget as Text).data!;
    final before = allCount();
    await tapAndPump(tester, find.byType(TaskTile).first);
    await waitFor(tester, find.text('Task details'), 'task sheet');
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Done')));
    await tapAndPump(tester, find.text('Save changes'));
    await waitFor(tester, find.text('Done (1)'), 'task marked done');

    // Add a task
    await tapAndPump(tester, find.text('Add task').first);
    await waitFor(tester, find.text('New task'), 'new task sheet');
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'Buy return gifts');
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Catering')));
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Choose a date')));
    await waitFor(tester, find.text('OK'), 'date picker in the task sheet');
    await tapAndPump(tester, find.text('OK'));
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add task')));
    await waitFor(tester, find.byWidgetPredicate((w) => w is Text && w.data != null && w.data!.startsWith('All (') && w.data != before), 'task count to change');

    // Budget: add a category
    await tapAndPump(tester, find.widgetWithText(Tab, 'Budget'));
    await tapAndPump(tester, find.text('Add category').first);
    await waitFor(tester, find.text('Add budget category'), 'budget sheet');
    await tapAndPump(tester, find.text('Something else'));
    final sheetFields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(sheetFields.first, 'Return gifts');
    await tester.enterText(sheetFields.last, '20000');
    await tester.pump(const Duration(milliseconds: 300));
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add category')));
    await waitFor(tester, find.text('Return gifts'), 'new budget category');

    // Back to the list and sign out
    final nav = container(tester).read(routerProvider);
    nav.go(AppPaths.events);
    await waitFor(tester, find.text(eventName), 'event in the list');
    await signOut(tester, vendor: false);
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('vendor: fill the profile, submit, get approved, edit a live profile', (tester) async {
    expect(adminPassword, isNotEmpty, reason: 'pass --dart-define=ADMIN_PASSWORD=...');
    await startApp(tester);
    await signIn(tester, vendorPhone, vendor: true);
    await waitFor(tester, find.text('Finish your profile'), 'vendor dashboard after signing in');
    expect(location(tester), AppPaths.vendorHome);

    await tapAndPump(tester, find.text('Continue setting up'));
    await waitFor(tester, find.text('Your business profile'), 'editor');
    await tester.enterText(input('Business name'), businessName);
    await tester.enterText(input('Contact person'), 'Asha Tester');
    await tester.enterText(input('Service area'), 'Pune');
    await tester.enterText(input('Description'), 'Candid wedding photography across Pune and Mumbai, built by the live test.');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Photography'));
    await tapAndPump(tester, find.widgetWithText(FilterChip, 'Photography'));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Premium'));
    await tapAndPump(tester, find.widgetWithText(ChoiceChip, 'Premium'));

    // Past work
    await tester.ensureVisible(find.text('Add past work'));
    await tapAndPump(tester, find.text('Add past work'));
    await waitFor(tester, find.text('Add past work').last, 'past work sheet');
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)).first, 'Sharma wedding');
    await tester.pump(const Duration(milliseconds: 300));
    await tapAndPump(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add')));
    await waitFor(tester, find.text('Sharma wedding'), 'past work added');

    // Submit
    await tester.ensureVisible(find.text('Submit for review'));
    await tapAndPump(tester, find.text('Submit for review'));
    await waitFor(tester, find.text('Your profile is under review'), 'under review dashboard', timeout: const Duration(seconds: 45));
    expect(location(tester), AppPaths.vendorHome);

    // An admin approves; the vendor signs in again and is live
    await approveVendor(businessName);
    await signOut(tester, vendor: true);
    await signIn(tester, vendorPhone, vendor: true);
    await waitFor(tester, find.text("You're live"), 'live dashboard after approval');

    // Editing a watched field on a live profile asks first, then goes back to review
    await tapAndPump(tester, find.text('Edit profile'));
    await waitFor(tester, find.text('Edit profile').last, 'editor for a live profile');
    await tester.enterText(input('Business name'), '$businessName Studio');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Save changes'));
    await tapAndPump(tester, find.text('Save changes'));
    await waitFor(tester, find.text('Send for review again?'), 'review warning');
    await tapAndPump(tester, find.text('Save and send'));
    await waitFor(tester, find.text('Your profile is under review'), 'back in review', timeout: const Duration(seconds: 30));
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('organizer sees the approved vendor; the session survives a restart; an expired token is refreshed', (tester) async {
    // The vendor from the previous test is pending again; approve it so it is listed.
    await approveVendor('$businessName Studio');

    await startApp(tester);
    await signIn(tester, organizerPhone, vendor: false);
    await waitFor(tester, find.text(eventName), 'home with the event', timeout: const Duration(seconds: 40));
    expect(location(tester), AppPaths.home);

    await tapAndPump(tester, find.text('Vendors'));
    await waitFor(tester, find.text('$businessName Studio'), 'approved vendor in the directory', timeout: const Duration(seconds: 30));
    await tapAndPump(tester, find.text('$businessName Studio'));
    await waitFor(tester, find.text('Call'), 'vendor detail');

    // Restart the app without signing out: the session is restored.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await startApp(tester, signedOut: false);
    await waitFor(tester, find.text('Hello, Live'), 'signed-in home after a restart', timeout: const Duration(seconds: 40));

    // An invalid access token is replaced through the refresh token and the request still succeeds.
    await AuthStorage().setAccessToken('not-a-valid-token');
    final dio = container(tester).read(dioProvider);
    final res = await tester.runAsync(() => dio.get<Map<String, dynamic>>('/organizers/me'));
    expect(res!.statusCode, 200);
    final newToken = await AuthStorage().getAccessToken();
    expect(newToken, isNot('not-a-valid-token'));
  }, timeout: const Timeout(Duration(minutes: 6)));
}
