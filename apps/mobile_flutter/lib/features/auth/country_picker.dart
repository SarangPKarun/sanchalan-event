import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'country_codes.dart';

/// Opens a searchable list of countries and returns the one picked (or null).
Future<Country?> showCountryPicker(
  BuildContext context, {
  required Country selected,
}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final Country selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a country', style: text.headlineSmall),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    autofocus: false,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search country or code',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('No country found', style: text.bodyMedium),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        final selected = c == widget.selected;
                        return ListTile(
                          minTileHeight: kMinTouchTarget,
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          title: Text(c.name),
                          subtitle: Text(c.dialCode),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : null,
                          selected: selected,
                          selectedTileColor: AppColors.primaryContainer,
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
