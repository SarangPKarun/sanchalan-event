import 'package:flutter/material.dart';

import '../../../core/category_icons.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums.dart';
import '../../../models/roadmap.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../event_stats.dart';
import 'sheet_scaffold.dart';

sealed class TaskSheetResult {
  const TaskSheetResult();
}

class TaskSaved extends TaskSheetResult {
  const TaskSaved({
    required this.name,
    required this.categoryKey,
    this.dueDate,
    this.status,
  });

  final String name;
  final String categoryKey;
  final DateTime? dueDate;

  /// Only set when editing an existing task.
  final TaskStatus? status;
}

class TaskDeleted extends TaskSheetResult {
  const TaskDeleted();
}

/// Add ([task] null) or edit a roadmap task.
Future<TaskSheetResult?> showTaskSheet(
  BuildContext context, {
  TaskWithDependencies? task,
  required List<String> categoryKeys,
  DateTime? today,
}) => showAppSheet<TaskSheetResult>(
  context,
  (_) => TaskSheet(task: task, categoryKeys: categoryKeys, today: today),
);

class TaskSheet extends StatefulWidget {
  const TaskSheet({
    super.key,
    this.task,
    required this.categoryKeys,
    this.today,
  });

  final TaskWithDependencies? task;
  final List<String> categoryKeys;
  final DateTime? today;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final _name = TextEditingController(text: widget.task?.name ?? '');
  late String? _category = widget.task?.categoryKey;
  late DateTime? _due = widget.task?.dueDate;
  late TaskStatus _status = _initialStatus;
  bool _showErrors = false;

  bool get _isNew => widget.task == null;

  TaskStatus get _initialStatus {
    final s = widget.task?.status ?? TaskStatus.notStarted;
    // The API only accepts these three; overdue is just "open and late".
    return s == TaskStatus.done || s == TaskStatus.inProgress
        ? s
        : TaskStatus.notStarted;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _showErrors && _name.text.trim().isEmpty ? 'Give the task a name.' : null;
  String? get _categoryError =>
      _showErrors && _category == null ? 'Choose a category.' : null;
  String? get _dueError =>
      _showErrors && _isNew && _due == null ? 'Choose a due date.' : null;

  Future<void> _pickDate() async {
    final today = dateOnly(widget.today ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 4),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    setState(() => _showErrors = true);
    if (_name.text.trim().isEmpty || _category == null || (_isNew && _due == null)) {
      return;
    }
    Navigator.of(context).pop(
      TaskSaved(
        name: _name.text.trim(),
        categoryKey: _category!,
        dueDate: _due,
        status: _isNew ? null : _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final task = widget.task;
    final effective = task == null
        ? null
        : effectiveStatus(task, today: widget.today);
    return SheetFrame(
      title: _isNew ? 'New task' : 'Task details',
      subtitle: effective == TaskStatus.overdue
          ? dueLabel(task!.dueDate, today: widget.today)
          : null,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: _isNew ? 'Add task' : 'Save changes',
            onPressed: _save,
          ),
          if (!_isNew)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(const TaskDeleted()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove this task'),
              style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            ),
        ],
      ),
      children: [
        AppTextField(
          label: 'What needs to be done?',
          controller: _name,
          hint: 'e.g. Book the band',
          errorText: _nameError,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        if (task?.description != null) ...[
          const SizedBox(height: AppSpace.m),
          Text(
            task!.description!,
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ],
        if (!_isNew) ...[
          const SizedBox(height: AppSpace.l),
          Text('Status', style: text.titleSmall),
          const SizedBox(height: AppSpace.s),
          SegmentedButton<TaskStatus>(
            showSelectedIcon: false,
            segments: [
              for (final s in [
                TaskStatus.notStarted,
                TaskStatus.inProgress,
                TaskStatus.done,
              ])
                ButtonSegment(
                  value: s,
                  label: Text(taskStatusLabel(s), maxLines: 1),
                ),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ],
        const SizedBox(height: AppSpace.l),
        Text('Due date', style: text.titleSmall),
        const SizedBox(height: AppSpace.s),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(_due == null ? 'Choose a date' : formatLongDate(_due!)),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
        ),
        if (_dueError != null) _FieldError(_dueError!),
        const SizedBox(height: AppSpace.l),
        Text('Category', style: text.titleSmall),
        const SizedBox(height: AppSpace.s),
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final key in widget.categoryKeys)
              ChoiceChip(
                avatar: Icon(categoryIcon(key), size: 18),
                label: Text(categoryLabel(key)),
                selected: _category == key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _category = key),
              ),
          ],
        ),
        if (_categoryError != null) _FieldError(_categoryError!),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.xs),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.errorText),
    ),
  );
}
