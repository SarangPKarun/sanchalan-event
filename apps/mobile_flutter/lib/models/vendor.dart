import 'package:json_annotation/json_annotation.dart';

import 'converters.dart';
import 'enums.dart';

part 'vendor.g.dart';

@JsonSerializable()
class VendorCategory {
  const VendorCategory({
    required this.id,
    required this.categoryKey,
    required this.applicableEventTypes,
  });
  factory VendorCategory.fromJson(Map<String, dynamic> json) => _$VendorCategoryFromJson(json);
  final String id;
  final String categoryKey;
  @JsonKey(defaultValue: <EventType>[])
  final List<EventType> applicableEventTypes;
  Map<String, dynamic> toJson() => _$VendorCategoryToJson(this);
}

/// Row of GET /vendor-categories.
typedef VendorCategoryListItem = VendorCategory;

@JsonSerializable(explicitToJson: true)
class ListVendorCategoriesResponse {
  const ListVendorCategoriesResponse({required this.categories});
  factory ListVendorCategoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$ListVendorCategoriesResponseFromJson(json);
  final List<VendorCategory> categories;
  Map<String, dynamic> toJson() => _$ListVendorCategoriesResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class VendorVendorCategory {
  const VendorVendorCategory({
    required this.vendorId,
    required this.vendorCategoryId,
    required this.vendorCategory,
  });
  factory VendorVendorCategory.fromJson(Map<String, dynamic> json) =>
      _$VendorVendorCategoryFromJson(json);
  final String vendorId;
  final String vendorCategoryId;
  final VendorCategory vendorCategory;
  Map<String, dynamic> toJson() => _$VendorVendorCategoryToJson(this);
}

/// A "past work" entry on a vendor profile (text only for now).
@JsonSerializable()
class VendorPortfolioItem {
  const VendorPortfolioItem({
    required this.id,
    required this.vendorId,
    required this.title,
    this.mediaUrl,
    this.caption,
    required this.displayOrder,
    required this.createdAt,
  });
  factory VendorPortfolioItem.fromJson(Map<String, dynamic> json) =>
      _$VendorPortfolioItemFromJson(json);
  final String id;
  final String vendorId;
  final String title;
  final String? mediaUrl;
  final String? caption;
  final int displayOrder;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => _$VendorPortfolioItemToJson(this);
}

/// A vendor with its categories and past work, as returned by GET /vendors,
/// GET /vendors/:id and the admin vendor endpoints.
/// [startingPrice] is a Prisma Decimal on the server and arrives as a string.
@JsonSerializable(explicitToJson: true)
class Vendor {
  const Vendor({
    required this.id,
    this.businessName,
    this.contactPersonName,
    required this.phoneNumber,
    this.email,
    this.priceTier,
    this.serviceArea,
    this.description,
    this.yearsOfExperience,
    this.startingPrice,
    this.instagramUrl,
    this.websiteUrl,
    this.whatsappNumber,
    required this.status,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    required this.createdAt,
    required this.vendorVendorCategories,
    required this.portfolioItems,
  });
  factory Vendor.fromJson(Map<String, dynamic> json) => _$VendorFromJson(json);
  final String id;
  final String? businessName;
  final String? contactPersonName;
  final String phoneNumber;
  final String? email;
  final VendorPriceTier? priceTier;
  final String? serviceArea;
  final String? description;
  final int? yearsOfExperience;
  @NullableMoneyConverter()
  final double? startingPrice;
  final String? instagramUrl;
  final String? websiteUrl;
  final String? whatsappNumber;
  final VendorStatus status;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime createdAt;
  @JsonKey(defaultValue: <VendorVendorCategory>[])
  final List<VendorVendorCategory> vendorVendorCategories;
  @JsonKey(defaultValue: <VendorPortfolioItem>[])
  final List<VendorPortfolioItem> portfolioItems;
  Map<String, dynamic> toJson() => _$VendorToJson(this);

  List<String> get categoryKeys =>
      [for (final c in vendorVendorCategories) c.vendorCategory.categoryKey];
}

@JsonSerializable()
class ListVendorsResponse {
  const ListVendorsResponse({required this.vendors});
  factory ListVendorsResponse.fromJson(Map<String, dynamic> json) =>
      _$ListVendorsResponseFromJson(json);
  final List<Vendor> vendors;
  Map<String, dynamic> toJson() => _$ListVendorsResponseToJson(this);
}

@JsonEnum()
enum VendorRequiredField {
  businessName,
  contactPersonName,
  priceTier,
  serviceArea,
  description,
  categories,
  pastWork,
}

@JsonSerializable()
class VendorCompleteness {
  const VendorCompleteness({required this.complete, required this.missing});
  factory VendorCompleteness.fromJson(Map<String, dynamic> json) =>
      _$VendorCompletenessFromJson(json);
  final bool complete;
  @JsonKey(defaultValue: <VendorRequiredField>[])
  final List<VendorRequiredField> missing;
  Map<String, dynamic> toJson() => _$VendorCompletenessToJson(this);
}

/// Response of GET /vendor/me, POST /vendor/me/submit and /withdraw.
class VendorMeResponse {
  const VendorMeResponse({required this.vendor, required this.completeness});

  /// The API returns the vendor fields and `completeness` side by side.
  factory VendorMeResponse.fromJson(Map<String, dynamic> json) => VendorMeResponse(
        vendor: Vendor.fromJson(json),
        completeness: VendorCompleteness.fromJson(json['completeness'] as Map<String, dynamic>),
      );
  final Vendor vendor;
  final VendorCompleteness completeness;
  Map<String, dynamic> toJson() => {...vendor.toJson(), 'completeness': completeness.toJson()};
}

/// Response of profile, category and past-work edits.
class UpdateVendorProfileResponse {
  const UpdateVendorProfileResponse({required this.vendor, required this.reverificationTriggered});
  factory UpdateVendorProfileResponse.fromJson(Map<String, dynamic> json) =>
      UpdateVendorProfileResponse(
        vendor: VendorMeResponse.fromJson(json['vendor'] as Map<String, dynamic>),
        reverificationTriggered: json['reverificationTriggered'] as bool? ?? false,
      );

  final VendorMeResponse vendor;

  /// True when this edit moved a published vendor back to pending_review.
  final bool reverificationTriggered;
  Map<String, dynamic> toJson() =>
      {'vendor': vendor.toJson(), 'reverificationTriggered': reverificationTriggered};
}

@JsonSerializable(includeIfNull: false)
class UpdateVendorProfileBody {
  const UpdateVendorProfileBody({
    this.businessName,
    this.contactPersonName,
    this.email,
    this.priceTier,
    this.serviceArea,
    this.description,
    this.yearsOfExperience,
    this.startingPrice,
    this.instagramUrl,
    this.websiteUrl,
    this.whatsappNumber,
  });
  factory UpdateVendorProfileBody.fromJson(Map<String, dynamic> json) =>
      _$UpdateVendorProfileBodyFromJson(json);
  final String? businessName;
  final String? contactPersonName;
  final String? email;
  final VendorPriceTier? priceTier;
  final String? serviceArea;
  final String? description;
  final int? yearsOfExperience;
  final double? startingPrice;
  final String? instagramUrl;
  final String? websiteUrl;
  final String? whatsappNumber;
  Map<String, dynamic> toJson() => _$UpdateVendorProfileBodyToJson(this);
}

@JsonSerializable()
class SetVendorCategoriesBody {
  const SetVendorCategoriesBody({required this.categoryKeys});
  factory SetVendorCategoriesBody.fromJson(Map<String, dynamic> json) =>
      _$SetVendorCategoriesBodyFromJson(json);
  final List<String> categoryKeys;
  Map<String, dynamic> toJson() => _$SetVendorCategoriesBodyToJson(this);
}

@JsonSerializable()
class PastWorkBody {
  const PastWorkBody({required this.title, this.caption});
  factory PastWorkBody.fromJson(Map<String, dynamic> json) => _$PastWorkBodyFromJson(json);
  final String title;
  final String? caption;
  Map<String, dynamic> toJson() => _$PastWorkBodyToJson(this);
}

@JsonSerializable()
class ReorderPastWorkBody {
  const ReorderPastWorkBody({required this.itemIds});
  factory ReorderPastWorkBody.fromJson(Map<String, dynamic> json) =>
      _$ReorderPastWorkBodyFromJson(json);
  final List<String> itemIds;
  Map<String, dynamic> toJson() => _$ReorderPastWorkBodyToJson(this);
}
