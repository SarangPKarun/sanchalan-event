import '../core/format.dart';
import '../models/event.dart';
import '../models/organizer.dart';
import '../models/roadmap.dart';
import '../models/vendor.dart';

/// Sample data for the design previews and widget tests. Built through the real
/// models (`fromJson`) with dates relative to [today], so countdowns and
/// overdue chips always look right.
class MockData {
  MockData({DateTime? today}) : today = dateOnly(today ?? DateTime.now());

  final DateTime today;

  String _date(int offsetDays) {
    final d = today.add(Duration(days: offsetDays));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _now => today.toIso8601String();

  late final Organizer organizer = Organizer.fromJson({
    'id': 'org-1',
    'phoneNumber': '+919876543210',
    'email': null,
    'displayName': 'Priya Sharma',
    'organizerType': 'family',
    'preferredLanguage': null,
    'createdAt': _now,
    'status': 'active',
  });

  // --- tasks ---

  Map<String, dynamic> _task(
    String id,
    String name,
    String categoryKey,
    int? dueOffset,
    String status, {
    String eventId = 'ev-wedding',
    String? description,
    List<String> dependsOn = const [],
  }) =>
      {
        'id': id,
        'eventGroupId': eventId,
        'subEventId': null,
        'taskCategoryId': 'cat-$categoryKey',
        'name': name,
        'description': description,
        'status': status,
        'dueDate': dueOffset == null ? null : _date(dueOffset),
        'source': 'ai_generated',
        'ownerType': 'organizer',
        'ownerUserId': null,
        'linkedVendorId': null,
        'linkedBudgetCategoryId': null,
        'createdAt': _now,
        'updatedAt': _now,
        'categoryKey': categoryKey,
        'dependsOnTaskIds': dependsOn,
      };

  late final List<TaskWithDependencies> weddingTasks = [
    for (final t in [
      _task('t1', 'Book the wedding venue', 'venue', -40, 'done'),
      _task('t2', 'Finalise the seating layout', 'venue', 12, 'not_started', dependsOn: ['t1']),
      _task('t3', 'Taste and choose the menu', 'catering', -5, 'not_started',
          description: 'Schedule a tasting for 6 to 8 people with your shortlisted caterer.'),
      _task('t4', 'Confirm final guest count with the caterer', 'catering', 30, 'not_started'),
      _task('t5', 'Finalise mandap and stage decor', 'decor', 10, 'in_progress'),
      _task('t6', 'Order flowers and garlands', 'decor', 35, 'not_started'),
      _task('t7', 'Book photographer and videographer', 'photography', -20, 'done'),
      _task('t8', 'Plan the shot list', 'photography', 25, 'not_started'),
      _task('t9', 'Buy bride and groom outfits', 'attire', -2, 'in_progress'),
      _task('t10', 'Book the tailor for fittings', 'attire', 8, 'not_started'),
      _task('t11', 'Design and print invitations', 'invitations', -15, 'done'),
      _task('t12', 'Send invitations to guests', 'invitations', 3, 'not_started'),
      _task('t13', 'Book the DJ and band', 'music_entertainment', 20, 'not_started'),
      _task('t14', 'Fix the muhurat with the priest', 'priest_officiant', -30, 'done'),
      _task('t15', 'Book rooms for outstation guests', 'guest_logistics', 18, 'not_started'),
      _task('t16', 'Arrange baraat transport', 'transport', 28, 'not_started'),
      _task('t17', 'Apply for marriage registration', 'legal_documentation', 14, 'not_started'),
    ])
      TaskWithDependencies.fromJson(t),
  ];

  late final List<TaskWithDependencies> removedTasks = [
    TaskWithDependencies.fromJson(
      _task('t18', 'Hire a live cooking counter', 'catering', null, 'not_applicable'),
    ),
  ];

  // --- events ---

  Map<String, dynamic> _budget(String id, String key, double amount, {String eventId = 'ev-wedding'}) => {
        'id': id,
        'eventGroupId': eventId,
        'categoryKey': key,
        'allocatedAmount': amount,
        'budgetTierOverride': null,
      };

  Map<String, dynamic> _subEvent(String eventId, String name, int offset, int guests) => {
        'id': 'sub-$eventId',
        'eventGroupId': eventId,
        'name': name,
        'subEventType': null,
        'date': _date(offset),
        'startTime': null,
        'endTime': null,
        'venueName': null,
        'venueAddress': null,
        'expectedGuestCount': guests,
        'status': 'planned',
      };

  Map<String, dynamic> _event({
    required String id,
    required String type,
    required String name,
    required String region,
    required double budget,
    required String tier,
    required int guests,
    required int dateOffset,
    required List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> tasks = const [],
  }) =>
      {
        'id': id,
        'organizerId': 'org-1',
        'eventType': type,
        'name': name,
        'region': region,
        'religionOrTradition': null,
        'totalBudget': budget,
        'budgetTier': tier,
        'guestCountEstimate': guests,
        'primaryDate': _date(dateOffset),
        'status': 'planning',
        'createdAt': _now,
        'subEvents': [_subEvent(id, name, dateOffset, guests)],
        'budgetCategories': categories,
        'tasks': tasks,
      };

  /// An upcoming wedding with a full roadmap and a budget that is almost all allocated.
  late final EventGroup wedding = EventGroup.fromJson(_event(
    id: 'ev-wedding',
    type: 'wedding',
    name: 'Priya & Rohan',
    region: 'Pune',
    budget: 1500000,
    tier: 'standard',
    guests: 250,
    dateOffset: 48,
    categories: [
      _budget('b1', 'venue', 450000),
      _budget('b2', 'catering', 400000),
      _budget('b3', 'decor', 200000),
      _budget('b4', 'photography', 150000),
      _budget('b5', 'attire', 120000),
      _budget('b6', 'music_entertainment', 80000),
      _budget('b7', 'misc', 40000),
    ],
    tasks: [for (final t in weddingTasks) t.toJson()],
  ));

  /// A past birthday whose budget is over-allocated (shows the warning state).
  late final EventGroup birthday = EventGroup.fromJson(_event(
    id: 'ev-birthday',
    type: 'birthday',
    name: "Aarav's 5th birthday",
    region: 'Pune',
    budget: 100000,
    tier: 'essential',
    guests: 40,
    dateOffset: -30,
    categories: [
      _budget('b8', 'catering', 60000, eventId: 'ev-birthday'),
      _budget('b9', 'decor', 50000, eventId: 'ev-birthday'),
    ],
    tasks: [
      _task('t20', 'Order the cake', 'catering', -35, 'done', eventId: 'ev-birthday'),
      _task('t21', 'Book the party hall', 'venue', -45, 'done', eventId: 'ev-birthday'),
    ],
  ));

  /// An upcoming event without a roadmap yet.
  late final EventGroup newEvent = EventGroup.fromJson(_event(
    id: 'ev-new',
    type: 'engagement_only',
    name: 'Meera & Karan engagement',
    region: 'Mumbai',
    budget: 600000,
    tier: 'premium',
    guests: 120,
    dateOffset: 90,
    categories: [
      _budget('b10', 'venue', 250000, eventId: 'ev-new'),
      _budget('b11', 'catering', 200000, eventId: 'ev-new'),
    ],
  ));

  List<EventGroup> get events => [wedding, birthday, newEvent];

  // --- vendors ---

  Map<String, dynamic> _vendor({
    required String id,
    required String name,
    required String contact,
    required List<String> categories,
    required String tier,
    required String area,
    required int years,
    required double from,
    required String description,
    List<Map<String, dynamic>> pastWork = const [],
    String? instagram,
    String? website,
    String? whatsapp,
  }) =>
      {
        'id': id,
        'businessName': name,
        'contactPersonName': contact,
        'phoneNumber': '+919811122233',
        'email': null,
        'priceTier': tier,
        'serviceArea': area,
        'description': description,
        'yearsOfExperience': years,
        'startingPrice': from,
        'instagramUrl': instagram,
        'websiteUrl': website,
        'whatsappNumber': whatsapp,
        'status': 'published',
        'rejectionReason': null,
        'submittedAt': _now,
        'reviewedAt': _now,
        'reviewedBy': null,
        'createdAt': _now,
        'vendorVendorCategories': [
          for (final c in categories)
            {
              'vendorId': id,
              'vendorCategoryId': 'vc-$c',
              'vendorCategory': {
                'id': 'vc-$c',
                'categoryKey': c,
                'applicableEventTypes': ['wedding'],
              },
            },
        ],
        'portfolioItems': pastWork,
      };

  Map<String, dynamic> _work(String vendorId, int i, String title, String caption) => {
        'id': '$vendorId-w$i',
        'vendorId': vendorId,
        'title': title,
        'mediaUrl': null,
        'caption': caption,
        'displayOrder': i,
        'createdAt': _now,
      };

  late final List<Vendor> vendors = [
    Vendor.fromJson(_vendor(
      id: 'v1',
      name: 'Shubh Photos',
      contact: 'Asha Kulkarni',
      categories: ['photography'],
      tier: 'premium',
      area: 'Pune',
      years: 7,
      from: 50000,
      description:
          'Candid wedding photography and cinematic films across Pune and Mumbai. We tell the story of your day as it really felt.',
      pastWork: [
        _work('v1', 0, 'Sharma wedding', 'Pune, 2025. Two-day celebration, 600 guests.'),
        _work('v1', 1, 'Deshmukh engagement', 'Lonavala, 2024.'),
      ],
      instagram: 'https://instagram.com/shubhphotos',
      website: 'https://shubhphotos.example',
      whatsapp: '+919811122233',
    )),
    Vendor.fromJson(_vendor(
      id: 'v2',
      name: 'Rasoi Royale Caterers',
      contact: 'Vikram Joshi',
      categories: ['catering'],
      tier: 'standard',
      area: 'Pune, Pimpri-Chinchwad',
      years: 12,
      from: 300000,
      description:
          'Pure vegetarian and Jain menus for weddings of 100 to 1,500 guests, with live counters and trained service staff.',
      pastWork: [_work('v2', 0, 'Kulkarni wedding', '800 guests, 5 live counters.')],
    )),
    Vendor.fromJson(_vendor(
      id: 'v3',
      name: 'Mandap & Blooms',
      contact: 'Neha Shah',
      categories: ['decor', 'venue'],
      tier: 'luxury',
      area: 'Mumbai, Pune',
      years: 9,
      from: 250000,
      description: 'Floral mandaps, stage design and complete venue styling.',
    )),
    Vendor.fromJson(_vendor(
      id: 'v4',
      name: 'Surtaal Events',
      contact: 'Rahul Patil',
      categories: ['music_entertainment'],
      tier: 'essential',
      area: 'Pune',
      years: 4,
      from: 25000,
      description: 'DJs, live bands and dhol-tasha for baraat and sangeet.',
    )),
    Vendor.fromJson(_vendor(
      id: 'v5',
      name: 'Heritage Banquets',
      contact: 'Sunita Rao',
      categories: ['venue', 'catering'],
      tier: 'premium',
      area: 'Pune',
      years: 15,
      from: 400000,
      description: 'Garden lawn and indoor banquet for up to 800 guests, with in-house catering.',
    )),
  ];
}
