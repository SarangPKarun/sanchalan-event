import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/organizer/home_view.dart' show HomeStatus;
import 'package:sanchalan/features/organizer/organizer_profile_view.dart';
import 'package:sanchalan/features/organizer/vendor_detail_view.dart';
import 'package:sanchalan/features/organizer/vendors_view.dart';
import 'package:sanchalan/features/organizer/widgets/vendor_card.dart';
import 'package:sanchalan/features/vendor/vendor_repository.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/organizer.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/shared/widgets/skeleton.dart';

import '../../helpers/pump_screen.dart';

final mock = MockData(today: DateTime(2026, 10, 10));
const _tall = Size(400, 2200);

Widget vendors({
  HomeStatus status = HomeStatus.ready,
  List<Vendor>? list,
  VendorFilters filters = const VendorFilters(),
  ValueChanged<VendorFilters>? onFilters,
  ValueChanged<Vendor>? onOpen,
  VoidCallback? onRetry,
  String? forEvent,
}) =>
    VendorsView(
      status: status,
      vendors: list ?? mock.vendors,
      filters: filters,
      categoryKeys: const ['photography', 'catering', 'decor', 'venue'],
      forEventName: forEvent,
      onFiltersChanged: onFilters,
      onOpenVendor: onOpen,
      onRetry: onRetry,
    );

/// Taps a filter chip, scrolling the chip row to it first.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pump();
}

void main() {
  group('VendorsView', () {
    testWidgets('lists vendors with their key facts', (tester) async {
      await pumpScreen(tester, vendors(forEvent: 'Priya & Rohan'), size: _tall);
      expect(find.text('Vendors'), findsOneWidget);
      expect(find.text('For Priya & Rohan'), findsOneWidget);
      expect(find.text('5 vendors'), findsOneWidget);
      expect(find.text('Shubh Photos'), findsOneWidget);
      expect(find.text('Premium'), findsWidgets);
      expect(find.text('From ₹50K'), findsOneWidget);
      expect(find.text('7 yrs experience'), findsOneWidget);
      expect(find.text('Photography'), findsWidgets);
    });

    testWidgets('card shows at most three categories and a +N note', (tester) async {
      final many = Vendor.fromJson({
        ...mock.vendors.first.toJson(),
        'vendorVendorCategories': [
          for (final k in ['venue', 'catering', 'decor', 'photography', 'attire'])
            {
              'vendorId': 'v1',
              'vendorCategoryId': k,
              'vendorCategory': {'id': k, 'categoryKey': k, 'applicableEventTypes': ['wedding']},
            },
        ],
      });
      await pumpScreen(tester, Scaffold(body: VendorCard(vendor: many)), size: _tall);
      expect(find.text('+2 more'), findsOneWidget);
    });

    testWidgets('tapping a vendor opens it', (tester) async {
      Vendor? opened;
      await pumpScreen(tester, vendors(onOpen: (v) => opened = v), size: _tall);
      await tester.tap(find.text('Surtaal Events'));
      expect(opened!.id, 'v4');
    });

    testWidgets('filter chips report new filters (keeping the other one)', (tester) async {
      final calls = <VendorFilters>[];
      await pumpScreen(
        tester,
        vendors(filters: const VendorFilters(priceTier: VendorPriceTier.premium), onFilters: calls.add),
        size: _tall,
      );
      await tapChip(tester, 'Catering');
      expect(calls.last.category, 'catering');
      expect(calls.last.priceTier, VendorPriceTier.premium);

      await tapChip(tester, 'Any price');
      expect(calls.last.priceTier, isNull);

      await tapChip(tester, 'Luxury');
      expect(calls.last.priceTier, VendorPriceTier.luxury);

      await tapChip(tester, 'All categories');
      expect(calls.last.category, isNull);
    });

    testWidgets('selected filters are highlighted', (tester) async {
      await pumpScreen(
        tester,
        vendors(filters: const VendorFilters(category: 'decor', priceTier: VendorPriceTier.luxury)),
        size: _tall,
      );
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Décor')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Luxury')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All categories')).selected, isFalse);
    });

    testWidgets('no matches with filters offers Clear filters', (tester) async {
      final calls = <VendorFilters>[];
      await pumpScreen(
        tester,
        vendors(list: [], filters: const VendorFilters(category: 'decor'), onFilters: calls.add),
      );
      expect(find.text('No vendors match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      expect(calls.single.category, isNull);
      expect(calls.single.priceTier, isNull);
    });

    testWidgets('no vendors at all has no clear button', (tester) async {
      await pumpScreen(tester, vendors(list: []));
      expect(find.text('No vendors yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
    });

    testWidgets('loading and error', (tester) async {
      var retries = 0;
      await pumpScreen(tester, vendors(status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsNWidgets(3));
      await pumpScreen(tester, vendors(status: HomeStatus.error, onRetry: () => retries++));
      expect(find.text('Could not load vendors.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    for (final status in HomeStatus.values) {
      for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
        testWidgets('${status.name} fits $size at text scale $scale', (tester) async {
          await pumpScreen(tester, vendors(status: status, forEvent: 'Priya & Rohan'), size: size, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('VendorDetailView', () {
    Widget detail({
      HomeStatus status = HomeStatus.ready,
      Vendor? vendor,
      bool noVendor = false,
      VoidCallback? onCall,
      VoidCallback? onWhatsApp,
      ValueChanged<String>? onLink,
      VoidCallback? onRetry,
    }) =>
        VendorDetailView(
          status: status,
          vendor: noVendor ? null : (vendor ?? mock.vendors.first),
          onCall: onCall,
          onWhatsApp: onWhatsApp,
          onOpenLink: onLink,
          onRetry: onRetry,
        );

    testWidgets('shows the profile, facts, past work and links', (tester) async {
      await pumpScreen(tester, detail(), size: _tall);
      expect(find.text('Shubh Photos'), findsOneWidget);
      expect(find.text('Premium pricing'), findsOneWidget);
      expect(find.textContaining('Candid wedding photography'), findsOneWidget);
      expect(find.text('7 years'), findsOneWidget);
      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.text('Pune'), findsWidgets);
      expect(find.text('Asha Kulkarni'), findsOneWidget);
      expect(find.text('Past work'), findsOneWidget);
      expect(find.text('Sharma wedding'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
    });

    testWidgets('Call, WhatsApp and links call back', (tester) async {
      final calls = <String>[];
      await pumpScreen(
        tester,
        detail(onCall: () => calls.add('call'), onWhatsApp: () => calls.add('whatsapp'), onLink: calls.add),
        size: _tall,
      );
      await tester.tap(find.text('Call'));
      await tester.tap(find.text('WhatsApp'));
      await tester.tap(find.text('Instagram'));
      expect(calls, ['call', 'whatsapp', 'https://instagram.com/shubhphotos']);
    });

    testWidgets('a sparse vendor shows only what exists, and no WhatsApp button', (tester) async {
      await pumpScreen(tester, detail(vendor: mock.vendors[3]), size: _tall); // Surtaal: no past work or links
      expect(find.text('Past work'), findsNothing);
      expect(find.text('Links'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Call'), findsOneWidget);
    });

    testWidgets('loading, missing vendor and error', (tester) async {
      var retries = 0;
      await pumpScreen(tester, detail(status: HomeStatus.loading));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, detail(noVendor: true));
      expect(find.byType(Skeleton), findsWidgets);
      await pumpScreen(tester, detail(status: HomeStatus.error, onRetry: () => retries++));
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    for (final v in [0, 3]) {
      for (final (size, scale) in [(const Size(360, 640), 1.0), (const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
        testWidgets('vendor $v fits $size at text scale $scale', (tester) async {
          await pumpScreen(tester, detail(vendor: mock.vendors[v]), size: size, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('OrganizerProfileView', () {
    testWidgets('shows who is signed in and reports edit and sign out', (tester) async {
      final calls = <String>[];
      await pumpScreen(
        tester,
        OrganizerProfileView(
          organizer: mock.organizer,
          onEdit: () => calls.add('edit'),
          onSignOut: () => calls.add('signout'),
        ),
        size: const Size(400, 900),
      );
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Family organizer'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.tap(find.text('Sign out'));
      expect(calls, ['edit', 'signout']);
    });

    testWidgets('a new organizer without a name or type still renders', (tester) async {
      final bare = mock.organizer.toJson()
        ..['displayName'] = null
        ..['organizerType'] = null;
      await pumpScreen(
        tester,
        OrganizerProfileView(organizer: Organizer.fromJson(bare)),
        size: const Size(400, 900),
      );
      expect(find.text('Organizer'), findsOneWidget);
    });

    for (final (size, scale) in [(const Size(360, 640), 1.3), (const Size(320, 480), 1.3)]) {
      testWidgets('fits $size at text scale $scale', (tester) async {
        await pumpScreen(tester, OrganizerProfileView(organizer: mock.organizer), size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
