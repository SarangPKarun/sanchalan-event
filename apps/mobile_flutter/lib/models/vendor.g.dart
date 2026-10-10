// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VendorCategory _$VendorCategoryFromJson(Map<String, dynamic> json) =>
    VendorCategory(
      id: json['id'] as String,
      categoryKey: json['categoryKey'] as String,
      applicableEventTypes:
          (json['applicableEventTypes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$EventTypeEnumMap, e))
              .toList() ??
          [],
    );

Map<String, dynamic> _$VendorCategoryToJson(VendorCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'categoryKey': instance.categoryKey,
      'applicableEventTypes': instance.applicableEventTypes
          .map((e) => _$EventTypeEnumMap[e]!)
          .toList(),
    };

const _$EventTypeEnumMap = {
  EventType.wedding: 'wedding',
  EventType.birthday: 'birthday',
  EventType.corporate: 'corporate',
  EventType.religious: 'religious',
  EventType.engagementOnly: 'engagement_only',
  EventType.custom: 'custom',
};

ListVendorCategoriesResponse _$ListVendorCategoriesResponseFromJson(
  Map<String, dynamic> json,
) => ListVendorCategoriesResponse(
  categories: (json['categories'] as List<dynamic>)
      .map((e) => VendorCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ListVendorCategoriesResponseToJson(
  ListVendorCategoriesResponse instance,
) => <String, dynamic>{
  'categories': instance.categories.map((e) => e.toJson()).toList(),
};

VendorVendorCategory _$VendorVendorCategoryFromJson(
  Map<String, dynamic> json,
) => VendorVendorCategory(
  vendorId: json['vendorId'] as String,
  vendorCategoryId: json['vendorCategoryId'] as String,
  vendorCategory: VendorCategory.fromJson(
    json['vendorCategory'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$VendorVendorCategoryToJson(
  VendorVendorCategory instance,
) => <String, dynamic>{
  'vendorId': instance.vendorId,
  'vendorCategoryId': instance.vendorCategoryId,
  'vendorCategory': instance.vendorCategory.toJson(),
};

VendorPortfolioItem _$VendorPortfolioItemFromJson(Map<String, dynamic> json) =>
    VendorPortfolioItem(
      id: json['id'] as String,
      vendorId: json['vendorId'] as String,
      title: json['title'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      caption: json['caption'] as String?,
      displayOrder: (json['displayOrder'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$VendorPortfolioItemToJson(
  VendorPortfolioItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'vendorId': instance.vendorId,
  'title': instance.title,
  'mediaUrl': instance.mediaUrl,
  'caption': instance.caption,
  'displayOrder': instance.displayOrder,
  'createdAt': instance.createdAt.toIso8601String(),
};

Vendor _$VendorFromJson(Map<String, dynamic> json) => Vendor(
  id: json['id'] as String,
  businessName: json['businessName'] as String?,
  contactPersonName: json['contactPersonName'] as String?,
  phoneNumber: json['phoneNumber'] as String,
  email: json['email'] as String?,
  priceTier: $enumDecodeNullable(_$VendorPriceTierEnumMap, json['priceTier']),
  serviceArea: json['serviceArea'] as String?,
  description: json['description'] as String?,
  yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
  startingPrice: const NullableMoneyConverter().fromJson(json['startingPrice']),
  instagramUrl: json['instagramUrl'] as String?,
  websiteUrl: json['websiteUrl'] as String?,
  whatsappNumber: json['whatsappNumber'] as String?,
  status: $enumDecode(_$VendorStatusEnumMap, json['status']),
  rejectionReason: json['rejectionReason'] as String?,
  submittedAt: json['submittedAt'] == null
      ? null
      : DateTime.parse(json['submittedAt'] as String),
  reviewedAt: json['reviewedAt'] == null
      ? null
      : DateTime.parse(json['reviewedAt'] as String),
  reviewedBy: json['reviewedBy'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  vendorVendorCategories:
      (json['vendorVendorCategories'] as List<dynamic>?)
          ?.map((e) => VendorVendorCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  portfolioItems:
      (json['portfolioItems'] as List<dynamic>?)
          ?.map((e) => VendorPortfolioItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$VendorToJson(Vendor instance) => <String, dynamic>{
  'id': instance.id,
  'businessName': instance.businessName,
  'contactPersonName': instance.contactPersonName,
  'phoneNumber': instance.phoneNumber,
  'email': instance.email,
  'priceTier': _$VendorPriceTierEnumMap[instance.priceTier],
  'serviceArea': instance.serviceArea,
  'description': instance.description,
  'yearsOfExperience': instance.yearsOfExperience,
  'startingPrice': const NullableMoneyConverter().toJson(
    instance.startingPrice,
  ),
  'instagramUrl': instance.instagramUrl,
  'websiteUrl': instance.websiteUrl,
  'whatsappNumber': instance.whatsappNumber,
  'status': _$VendorStatusEnumMap[instance.status]!,
  'rejectionReason': instance.rejectionReason,
  'submittedAt': instance.submittedAt?.toIso8601String(),
  'reviewedAt': instance.reviewedAt?.toIso8601String(),
  'reviewedBy': instance.reviewedBy,
  'createdAt': instance.createdAt.toIso8601String(),
  'vendorVendorCategories': instance.vendorVendorCategories
      .map((e) => e.toJson())
      .toList(),
  'portfolioItems': instance.portfolioItems.map((e) => e.toJson()).toList(),
};

const _$VendorPriceTierEnumMap = {
  VendorPriceTier.essential: 'essential',
  VendorPriceTier.standard: 'standard',
  VendorPriceTier.premium: 'premium',
  VendorPriceTier.luxury: 'luxury',
};

const _$VendorStatusEnumMap = {
  VendorStatus.draft: 'draft',
  VendorStatus.pendingReview: 'pending_review',
  VendorStatus.published: 'published',
  VendorStatus.rejected: 'rejected',
  VendorStatus.suspended: 'suspended',
};

ListVendorsResponse _$ListVendorsResponseFromJson(Map<String, dynamic> json) =>
    ListVendorsResponse(
      vendors: (json['vendors'] as List<dynamic>)
          .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ListVendorsResponseToJson(
  ListVendorsResponse instance,
) => <String, dynamic>{'vendors': instance.vendors};

VendorCompleteness _$VendorCompletenessFromJson(Map<String, dynamic> json) =>
    VendorCompleteness(
      complete: json['complete'] as bool,
      missing:
          (json['missing'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$VendorRequiredFieldEnumMap, e))
              .toList() ??
          [],
    );

Map<String, dynamic> _$VendorCompletenessToJson(VendorCompleteness instance) =>
    <String, dynamic>{
      'complete': instance.complete,
      'missing': instance.missing
          .map((e) => _$VendorRequiredFieldEnumMap[e]!)
          .toList(),
    };

const _$VendorRequiredFieldEnumMap = {
  VendorRequiredField.businessName: 'businessName',
  VendorRequiredField.contactPersonName: 'contactPersonName',
  VendorRequiredField.priceTier: 'priceTier',
  VendorRequiredField.serviceArea: 'serviceArea',
  VendorRequiredField.description: 'description',
  VendorRequiredField.categories: 'categories',
  VendorRequiredField.pastWork: 'pastWork',
};

UpdateVendorProfileBody _$UpdateVendorProfileBodyFromJson(
  Map<String, dynamic> json,
) => UpdateVendorProfileBody(
  businessName: json['businessName'] as String?,
  contactPersonName: json['contactPersonName'] as String?,
  email: json['email'] as String?,
  priceTier: $enumDecodeNullable(_$VendorPriceTierEnumMap, json['priceTier']),
  serviceArea: json['serviceArea'] as String?,
  description: json['description'] as String?,
  yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
  startingPrice: (json['startingPrice'] as num?)?.toInt(),
  instagramUrl: json['instagramUrl'] as String?,
  websiteUrl: json['websiteUrl'] as String?,
  whatsappNumber: json['whatsappNumber'] as String?,
);

Map<String, dynamic> _$UpdateVendorProfileBodyToJson(
  UpdateVendorProfileBody instance,
) => <String, dynamic>{
  'businessName': ?instance.businessName,
  'contactPersonName': ?instance.contactPersonName,
  'email': ?instance.email,
  'priceTier': ?_$VendorPriceTierEnumMap[instance.priceTier],
  'serviceArea': ?instance.serviceArea,
  'description': ?instance.description,
  'yearsOfExperience': ?instance.yearsOfExperience,
  'startingPrice': ?instance.startingPrice,
  'instagramUrl': ?instance.instagramUrl,
  'websiteUrl': ?instance.websiteUrl,
  'whatsappNumber': ?instance.whatsappNumber,
};

SetVendorCategoriesBody _$SetVendorCategoriesBodyFromJson(
  Map<String, dynamic> json,
) => SetVendorCategoriesBody(
  categoryKeys: (json['categoryKeys'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SetVendorCategoriesBodyToJson(
  SetVendorCategoriesBody instance,
) => <String, dynamic>{'categoryKeys': instance.categoryKeys};

PastWorkBody _$PastWorkBodyFromJson(Map<String, dynamic> json) => PastWorkBody(
  title: json['title'] as String,
  caption: json['caption'] as String?,
);

Map<String, dynamic> _$PastWorkBodyToJson(PastWorkBody instance) =>
    <String, dynamic>{'title': instance.title, 'caption': instance.caption};

ReorderPastWorkBody _$ReorderPastWorkBodyFromJson(Map<String, dynamic> json) =>
    ReorderPastWorkBody(
      itemIds: (json['itemIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ReorderPastWorkBodyToJson(
  ReorderPastWorkBody instance,
) => <String, dynamic>{'itemIds': instance.itemIds};
