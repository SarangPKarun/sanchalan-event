import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vendor.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../organizer/sheets/sheet_scaffold.dart';
import '../vendor_profile_logic.dart';

sealed class PastWorkResult {
  const PastWorkResult();
}

class PastWorkSaved extends PastWorkResult {
  const PastWorkSaved({required this.title, this.caption});

  final String title;
  final String? caption;
}

class PastWorkDeleted extends PastWorkResult {
  const PastWorkDeleted();
}

/// Add ([item] null) or edit one past-work example (text only for now).
Future<PastWorkResult?> showPastWorkSheet(BuildContext context, {VendorPortfolioItem? item}) =>
    showAppSheet<PastWorkResult>(context, (_) => PastWorkSheet(item: item));

class PastWorkSheet extends StatefulWidget {
  const PastWorkSheet({super.key, this.item});

  final VendorPortfolioItem? item;

  @override
  State<PastWorkSheet> createState() => _PastWorkSheetState();
}

class _PastWorkSheetState extends State<PastWorkSheet> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _caption = TextEditingController(text: widget.item?.caption ?? '');
  bool _showErrors = false;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  String? get _titleError => _showErrors || _title.text.length > 150 ? validatePastWorkTitle(_title.text) : null;

  void _save() {
    setState(() => _showErrors = true);
    if (validatePastWorkTitle(_title.text) != null || validatePastWorkCaption(_caption.text) != null) return;
    final caption = _caption.text.trim();
    Navigator.of(context).pop(PastWorkSaved(title: _title.text.trim(), caption: caption.isEmpty ? null : caption));
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: _isNew ? 'Add past work' : 'Edit past work',
      subtitle: 'Tell families about an event you have done.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: _isNew ? 'Add' : 'Save changes', onPressed: _save),
          if (!_isNew)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(const PastWorkDeleted()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete this entry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            ),
        ],
      ),
      children: [
        AppTextField(
          label: 'Title',
          controller: _title,
          hint: 'e.g. Sharma wedding',
          errorText: _titleError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Details (optional)',
          controller: _caption,
          hint: 'Where, when, how many guests',
          maxLines: 3,
          errorText: validatePastWorkCaption(_caption.text),
          helperText: '${_caption.text.trim().length}/500',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
