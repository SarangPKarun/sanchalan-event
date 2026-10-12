import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/enums.dart';
import '../../models/vendor.dart';

/// Filters for the organizer's vendor directory. Used as a provider family key,
/// so it is a value class.
class VendorFilters {
  const VendorFilters({this.priceTier, this.category, this.region});

  final VendorPriceTier? priceTier;

  /// A vendor category key, e.g. `photography`.
  final String? category;
  final String? region;

  Map<String, dynamic> toQuery() => {
        if (priceTier != null) 'priceTier': enumWireValue(priceTier!),
        if (category != null) 'category': category,
        if (region != null) 'region': region,
      };

  @override
  bool operator ==(Object other) =>
      other is VendorFilters &&
      other.priceTier == priceTier &&
      other.category == category &&
      other.region == region;

  @override
  int get hashCode => Object.hash(priceTier, category, region);
}

class VendorRepository {
  VendorRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _call(String method, String path, {Object? body}) async {
    final res = await _dio.request<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(method: method),
    );
    return res.data!;
  }

  // --- directory (organizer side) ---

  Future<List<Vendor>> listVendors([VendorFilters filters = const VendorFilters()]) async {
    final res = await _dio.get<Map<String, dynamic>>('/vendors', queryParameters: filters.toQuery());
    return ListVendorsResponse.fromJson(res.data!).vendors;
  }

  Future<Vendor> getVendor(String id) async => Vendor.fromJson(await _call('GET', '/vendors/$id'));

  Future<List<VendorCategory>> listCategories() async =>
      ListVendorCategoriesResponse.fromJson(await _call('GET', '/vendor-categories')).categories;

  // --- self-service (vendor side) ---

  Future<List<CategoryProposal>> listMyProposals() async =>
      ListCategoryProposalsResponse.fromJson(await _call('GET', '/vendor/me/category-proposals')).proposals;

  Future<CategoryProposal> proposeCategory(String label, {String? description}) async =>
      CategoryProposal.fromJson(await _call(
        'POST',
        '/vendor/me/category-proposals',
        body: {'label': label, if (description != null && description.isNotEmpty) 'description': description},
      ));

  Future<VendorMeResponse> getMe() async => VendorMeResponse.fromJson(await _call('GET', '/vendor/me'));

  Future<UpdateVendorProfileResponse> updateProfile(UpdateVendorProfileBody body) async =>
      UpdateVendorProfileResponse.fromJson(await _call('PATCH', '/vendor/me', body: body.toJson()));

  Future<UpdateVendorProfileResponse> setCategories(List<String> categoryKeys) async =>
      UpdateVendorProfileResponse.fromJson(await _call(
        'PUT',
        '/vendor/me/categories',
        body: SetVendorCategoriesBody(categoryKeys: categoryKeys).toJson(),
      ));

  Future<UpdateVendorProfileResponse> addPastWork(PastWorkBody body) async =>
      UpdateVendorProfileResponse.fromJson(
        await _call('POST', '/vendor/me/past-work', body: body.toJson()),
      );

  Future<UpdateVendorProfileResponse> updatePastWork(String itemId, PastWorkBody body) async =>
      UpdateVendorProfileResponse.fromJson(
        await _call('PATCH', '/vendor/me/past-work/$itemId', body: body.toJson()),
      );

  Future<UpdateVendorProfileResponse> deletePastWork(String itemId) async =>
      UpdateVendorProfileResponse.fromJson(await _call('DELETE', '/vendor/me/past-work/$itemId'));

  Future<UpdateVendorProfileResponse> reorderPastWork(List<String> itemIds) async =>
      UpdateVendorProfileResponse.fromJson(await _call(
        'PUT',
        '/vendor/me/past-work/order',
        body: ReorderPastWorkBody(itemIds: itemIds).toJson(),
      ));

  Future<VendorMeResponse> submit() async =>
      VendorMeResponse.fromJson(await _call('POST', '/vendor/me/submit'));

  Future<VendorMeResponse> withdraw() async =>
      VendorMeResponse.fromJson(await _call('POST', '/vendor/me/withdraw'));
}

final vendorRepositoryProvider =
    Provider<VendorRepository>((ref) => VendorRepository(ref.watch(dioProvider)));
