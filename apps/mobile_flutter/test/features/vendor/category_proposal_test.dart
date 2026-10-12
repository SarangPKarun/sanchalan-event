import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/dev/mock_data.dart';
import 'package:sanchalan/features/vendor/vendor_profile_editor_view.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/models/vendor_labels.dart';

import '../../helpers/pump_screen.dart';

Widget editor({
  List<CategoryProposal> proposals = const [],
  Future<String?> Function(String, String?)? onPropose,
}) =>
    VendorProfileEditorView(
      me: MockData(today: DateTime(2026, 10, 10)).vendorDraft,
      categoryKeys: vendorCategoryLabels.keys.toList(),
      categoryLabels: const {'mehendi_artist': 'Mehendi Artist'},
      proposals: proposals,
      onPropose: onPropose,
      onSave: (_) async => null,
      onSubmit: (_) async => null,
      onSavePastWork: (_, _) async => null,
      onDeletePastWork: (_) async => null,
    );

void main() {
  test('CategoryProposal parses the server shape', () {
    final p = CategoryProposal.fromJson({
      'id': 'p1',
      'label': 'Mehendi Artist',
      'categoryKey': 'mehendi_artist',
      'description': null,
      'status': 'rejected',
      'rejectionReason': 'Too narrow',
    });
    expect(p.status, CategoryProposalStatus.rejected);
    expect(p.rejectionReason, 'Too narrow');
  });

  testWidgets('no suggest option without a handler', (tester) async {
    await pumpScreen(tester, editor(), size: const Size(400, 3000));
    expect(find.text('Suggest a new category'), findsNothing);
  });

  testWidgets('suggesting sends label and description', (tester) async {
    (String, String?)? sent;
    await pumpScreen(
      tester,
      editor(onPropose: (l, d) async {
        sent = (l, d);
        return null;
      }),
      size: const Size(400, 3000),
    );
    await tester.tap(find.text('Suggest a new category'));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'Send for review');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'Mehendi Artist');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(sent, ('Mehendi Artist', null));
  });

  testWidgets('shows proposal status and rejection reason', (tester) async {
    await pumpScreen(
      tester,
      editor(
        onPropose: (_, _) async => null,
        proposals: const [
          CategoryProposal(
            id: 'p1',
            label: 'Sangeet choreography',
            categoryKey: 'sangeet_choreography',
            status: CategoryProposalStatus.rejected,
            rejectionReason: 'Covered by Music & Entertainment',
          ),
        ],
      ),
      size: const Size(400, 3000),
    );
    expect(find.text('Sangeet choreography'), findsOneWidget);
    expect(find.text('Not accepted'), findsOneWidget);
    expect(find.text('Covered by Music & Entertainment'), findsOneWidget);
  });
}
