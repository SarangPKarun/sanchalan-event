import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/vendor/vendor_profile_logic.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';

final mock = MockData(today: DateTime(2026, 10, 10));

void main() {
  group('completeness', () {
    test('a full profile has nothing missing', () {
      final c = mock.vendorPublished.completeness;
      expect(c.complete, isTrue);
      expect(completenessPercent(c), 100);
      expect(completenessItems(c).every((i) => i.done), isTrue);
    });

    test('a half-filled draft is missing five things', () {
      final c = mock.vendorDraft.completeness;
      expect(c.complete, isFalse);
      expect(c.missing, [
        VendorRequiredField.priceTier,
        VendorRequiredField.serviceArea,
        VendorRequiredField.description,
        VendorRequiredField.categories,
        VendorRequiredField.pastWork,
      ]);
      expect(completenessPercent(c), 29); // 2 of 7
      final items = completenessItems(c);
      expect(items, hasLength(7));
      expect(items.where((i) => i.done).map((i) => i.field), [
        VendorRequiredField.businessName,
        VendorRequiredField.contactPersonName,
      ]);
      expect(items.first.label, 'Business name');
    });

    test('computeCompleteness follows the server rules', () {
      Vendor v(Map<String, dynamic> over) => Vendor.fromJson({...mock.vendorPublished.vendor.toJson(), ...over});
      expect(computeCompleteness(v({})).complete, isTrue);
      expect(computeCompleteness(v({'businessName': '   '})).missing, [VendorRequiredField.businessName]);
      expect(computeCompleteness(v({'description': 'Too short'})).missing, [VendorRequiredField.description]);
      expect(computeCompleteness(v({'description': 'x' * 30})).complete, isTrue);
      expect(computeCompleteness(v({'portfolioItems': <Object>[]})).missing, [VendorRequiredField.pastWork]);
      expect(computeCompleteness(v({'priceTier': null})).missing, [VendorRequiredField.priceTier]);
    });

    test('stillNeededMessage lists labels', () {
      expect(
        stillNeededMessage([VendorRequiredField.priceTier, VendorRequiredField.pastWork]),
        'Still needed: Price range, Past work.',
      );
    });
  });

  group('diffProfile', () {
    final saved = mock.vendorPublished.vendor;

    test('an untouched form changes nothing', () {
      final body = diffProfile(saved, VendorProfileForm.fromVendor(saved));
      expect(body.isEmpty, isTrue);
      expect(body.toJson(), isEmpty);
    });

    test('only the changed fields are sent, trimmed', () {
      final form = VendorProfileForm.fromVendor(saved);
      final body = diffProfile(
        saved,
        VendorProfileForm(
          businessName: '  Shubh Studios ',
          contactPersonName: form.contactPersonName,
          priceTier: VendorPriceTier.luxury,
          serviceArea: form.serviceArea,
          description: form.description,
          years: '8',
          startingPrice: '₹ 60,000',
          instagramUrl: form.instagramUrl,
          websiteUrl: form.websiteUrl,
          whatsappNumber: form.whatsappNumber,
          categoryKeys: form.categoryKeys,
        ),
      );
      expect(body.toJson(), {
        'businessName': 'Shubh Studios',
        'priceTier': 'luxury',
        'yearsOfExperience': 8,
        'startingPrice': 60000,
      });
    });

    test('required text can be edited but never blanked', () {
      final form = VendorProfileForm.fromVendor(saved);
      final body = diffProfile(
        saved,
        VendorProfileForm(
          businessName: '   ',
          contactPersonName: '',
          priceTier: null,
          serviceArea: '',
          description: '',
          years: form.years,
          startingPrice: form.startingPrice,
          instagramUrl: form.instagramUrl,
          websiteUrl: form.websiteUrl,
          whatsappNumber: form.whatsappNumber,
          categoryKeys: form.categoryKeys,
        ),
      );
      expect(body.toJson(), isEmpty);
    });

    test('optional fields are cleared with an explicit null', () {
      final form = VendorProfileForm.fromVendor(saved);
      final body = diffProfile(
        saved,
        VendorProfileForm(
          businessName: form.businessName,
          contactPersonName: form.contactPersonName,
          priceTier: form.priceTier,
          serviceArea: form.serviceArea,
          description: form.description,
          years: '',
          startingPrice: '',
          instagramUrl: '',
          websiteUrl: form.websiteUrl,
          whatsappNumber: '',
          categoryKeys: form.categoryKeys,
        ),
      );
      final json = body.toJson();
      expect(json, {
        'yearsOfExperience': null,
        'startingPrice': null,
        'instagramUrl': null,
        'whatsappNumber': null,
      });
      expect(json.containsKey('yearsOfExperience'), isTrue);
    });

    test('adding a value to an empty optional field sends it', () {
      final draft = mock.vendorDraft.vendor;
      final body = diffProfile(draft, VendorProfileForm(businessName: draft.businessName!, contactPersonName: draft.contactPersonName!, email: 'a@b.in', years: '5'));
      expect(body.toJson(), {'email': 'a@b.in', 'yearsOfExperience': 5});
    });

    test('numbers equal to the saved ones are not sent', () {
      final form = VendorProfileForm.fromVendor(saved);
      expect(form.startingPrice, '50000');
      expect(diffProfile(saved, form).toJson().containsKey('startingPrice'), isFalse);
    });
  });

  group('review triggers', () {
    final published = mock.vendorPublished.vendor;
    final formOf = VendorProfileForm.fromVendor;

    VendorProfileForm edit(VendorProfileForm f, {String? business, String? years, String? website, List<String>? cats, String? desc}) =>
        VendorProfileForm(
          businessName: business ?? f.businessName,
          contactPersonName: f.contactPersonName,
          email: f.email,
          priceTier: f.priceTier,
          serviceArea: f.serviceArea,
          description: desc ?? f.description,
          years: years ?? f.years,
          startingPrice: f.startingPrice,
          instagramUrl: f.instagramUrl,
          websiteUrl: website ?? f.websiteUrl,
          whatsappNumber: f.whatsappNumber,
          categoryKeys: cats ?? f.categoryKeys,
        );

    test('changing a watched field on a published profile triggers review', () {
      final f = formOf(published);
      expect(triggersReview(published, edit(f, business: 'New name')), isTrue);
      expect(triggersReview(published, edit(f, desc: '${f.description} More.')), isTrue);
      expect(triggersReview(published, edit(f, cats: ['photography', 'decor'])), isTrue);
    });

    test('changing other fields does not', () {
      final f = formOf(published);
      expect(triggersReview(published, edit(f, years: '9')), isFalse);
      expect(triggersReview(published, edit(f, website: 'https://new.example')), isFalse);
      expect(triggersReview(published, f), isFalse);
    });

    test('only published profiles are affected', () {
      for (final vm in [mock.vendorDraft, mock.vendorRejected, mock.vendorPending]) {
        final f = formOf(vm.vendor);
        expect(triggersReview(vm.vendor, edit(f, business: 'Changed')), isFalse, reason: vm.vendor.status.name);
      }
    });

    test('categoriesChanged ignores order', () {
      expect(categoriesChanged(published, ['photography']), isFalse);
      expect(categoriesChanged(published, []), isTrue);
      expect(categoriesChanged(published, ['photography', 'venue']), isTrue);
    });
  });

  group('validators', () {
    test('required text', () {
      expect(validateBusinessName(' '), 'Enter your business name.');
      expect(validateBusinessName('A' * 121), isNotNull);
      expect(validateBusinessName('Shubh'), isNull);
      expect(validateContactPerson(''), isNotNull);
      expect(validateServiceArea('P' * 201), isNotNull);
      expect(validateServiceArea('Pune'), isNull);
    });

    test('description counts down to the minimum and up from the maximum', () {
      expect(validateDescription('x' * 12), 'Write at least 30 characters (18 to go).');
      expect(validateDescription('x' * 30), isNull);
      expect(validateDescription('x' * 1000), isNull);
      expect(validateDescription('x' * 1003), 'Keep it under 1000 characters (3 too many).');
      expect(validateDescription('   ${'x' * 30}   '), isNull); // trimmed
    });

    test('email', () {
      expect(validateEmail(''), isNull);
      expect(validateEmail('asha@shubh.in'), isNull);
      expect(validateEmail('asha@'), isNotNull);
      expect(validateEmail('asha shubh@x.in'), isNotNull);
    });

    test('links must be full http(s) URLs', () {
      expect(validateWebUrl(''), isNull);
      expect(validateWebUrl('https://instagram.com/shubh'), isNull);
      expect(validateWebUrl('http://shubh.in'), isNull);
      expect(validateWebUrl('instagram.com/shubh'), isNotNull);
      expect(validateWebUrl('ftp://shubh.in'), isNotNull);
      expect(validateWebUrl('https://'), isNotNull);
    });

    test('WhatsApp number must be E.164', () {
      expect(validateWhatsapp(''), isNull);
      expect(validateWhatsapp('+919876543210'), isNull);
      expect(validateWhatsapp('9876543210'), isNotNull);
      expect(validateWhatsapp('+91 98765 43210'), isNotNull);
      expect(validateWhatsapp('+0123456789'), isNotNull);
    });

    test('numbers', () {
      expect(validateYears(''), isNull);
      expect(validateYears('0'), isNull);
      expect(validateYears('80'), isNull);
      expect(validateYears('81'), isNotNull);
      expect(validateStartingPrice('50,000'), isNull);
      expect(validateStartingPrice('100000001'), isNotNull);
    });

    test('categories need 1 to 5', () {
      expect(validateCategories([]), 'Choose at least one category.');
      expect(validateCategories(['a']), isNull);
      expect(validateCategories(['a', 'b', 'c', 'd', 'e']), isNull);
      expect(validateCategories(['a', 'b', 'c', 'd', 'e', 'f']), 'Choose up to 5 categories.');
    });

    test('past work fields', () {
      expect(validatePastWorkTitle('  '), isNotNull);
      expect(validatePastWorkTitle('T' * 151), isNotNull);
      expect(validatePastWorkTitle('Sharma wedding'), isNull);
      expect(validatePastWorkCaption('c' * 501), isNotNull);
      expect(validatePastWorkCaption(''), isNull);
    });

    test('validateRequired lists every missing piece of an empty form', () {
      expect(validateRequired(const VendorProfileForm()).keys, [
        'businessName', 'contactPersonName', 'priceTier', 'serviceArea', 'description', 'categories',
      ]);
      expect(validateRequired(VendorProfileForm.fromVendor(mock.vendorPublished.vendor)), isEmpty);
    });

    test('validateFormats ignores blank optional fields and flags bad ones', () {
      expect(validateFormats(const VendorProfileForm()), isEmpty);
      final errors = validateFormats(const VendorProfileForm(
        email: 'nope',
        years: '99',
        instagramUrl: 'insta.com',
        whatsappNumber: '12345',
      ));
      expect(errors.keys, containsAll(['email', 'yearsOfExperience', 'instagramUrl', 'whatsappNumber']));
    });
  });

  group('mock vendor variants', () {
    test('each status', () {
      expect(mock.vendorDraft.vendor.status, VendorStatus.draft);
      expect(mock.vendorRejected.vendor.rejectionReason, contains('clearer description'));
      expect(mock.vendorPending.vendor.submittedAt!.toUtc(), DateTime.utc(2026, 10, 8));
      expect(mock.vendorPublished.vendor.reviewedAt, isNotNull);
      expect(mock.vendorSuspended.vendor.status, VendorStatus.suspended);
      expect(mock.vendorPublished.vendor.portfolioItems, isNotEmpty);
    });
  });
}
