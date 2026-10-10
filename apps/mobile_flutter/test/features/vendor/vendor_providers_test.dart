import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/vendor/vendor_providers.dart';
import 'package:sanchalan/features/vendor/vendor_repository.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';

import '../../helpers/container.dart';
import '../../helpers/fake_adapter.dart';

void main() {
  Future<VendorMeResponse> load(ProviderContainer c) async {
    final sub = c.listen(vendorDataProvider, (_, _) {});
    addTearDown(sub.close);
    return c.read(vendorDataProvider.future);
  }

  test('loads the vendor profile with completeness', () async {
    final (c, _) = makeContainer(routes({'GET /vendor/me': (_) => fixtureBody('vendor_me_draft')}));
    final me = await load(c);
    expect(me.vendor.status, VendorStatus.draft);
    expect(me.completeness.complete, isFalse);
  });

  test('failure is an error state with no automatic retry; refetch recovers', () async {
    var fail = true;
    final (c, adapter) = makeContainer(routes({
      'GET /vendor/me': (_) =>
          fail ? jsonBody({'error': 'boom'}, 500) : fixtureBody('vendor_me_draft'),
    }));
    final sub = c.listen(vendorDataProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(c.read(vendorDataProvider.future), throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.count('/vendor/me'), 1);

    fail = false;
    await c.read(vendorDataProvider.notifier).refetch();
    expect(c.read(vendorDataProvider).hasValue, isTrue);
  });

  test('apply replaces the vendor without a loading flip', () async {
    final (c, _) = makeContainer(routes({'GET /vendor/me': (_) => fixtureBody('vendor_me_draft')}));
    await load(c);

    final states = <AsyncValue<VendorMeResponse>>[];
    c.listen(vendorDataProvider, (_, next) => states.add(next));
    final submitted =
        VendorMeResponse.fromJson(fixture('vendor_submit') as Map<String, dynamic>);
    c.read(vendorDataProvider.notifier).apply(submitted);

    expect(states.any((s) => s.isLoading), isFalse);
    expect(c.read(vendorDataProvider).value!.vendor.status, VendorStatus.pendingReview);
  });

  test('vendors family is keyed by filters and sends them as query params', () async {
    final (c, adapter) = makeContainer(routes({'GET /vendors': (_) => fixtureBody('vendors_list')}));
    const filters = VendorFilters(priceTier: VendorPriceTier.premium, category: 'photography');
    // Auto-dispose providers are dropped between reads, so keep this one alive.
    final sub = c.listen(vendorsProvider(filters), (_, _) {});
    addTearDown(sub.close);
    final list = await c.read(vendorsProvider(filters).future);
    expect(list, hasLength(1));
    expect(adapter.last('/vendors').queryParameters, {'priceTier': 'premium', 'category': 'photography'});

    // Equal filters share one provider instance.
    await c.read(vendorsProvider(const VendorFilters(
      priceTier: VendorPriceTier.premium,
      category: 'photography',
    )).future);
    expect(adapter.count('/vendors'), 1);
  });

  test('vendor detail and categories', () async {
    final (c, _) = makeContainer(routes({
      'GET /vendors/v1': (_) => fixtureBody('vendor_detail'),
      'GET /vendor-categories': (_) => fixtureBody('vendor_categories'),
    }));
    expect((await c.read(vendorDetailProvider('v1').future)).businessName, 'Shubh Photos');
    expect(await c.read(vendorCategoriesProvider.future), hasLength(10));
  });
}
