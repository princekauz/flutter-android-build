import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A row with a label and a tappable date+time picker.
///
/// Tap to open. Shows "None" if `value` is null. Optional `includeTime`
/// switches to date-only.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.includeTime = true,
    this.allowClear = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool includeTime;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = value == null
        ? 'None'
        : (includeTime
            ? DateFormat('EEE, MMM d · HH:mm').format(value!)
            : DateFormat('EEE, MMM d').format(value!));

    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null && allowClear
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: value == null ? scheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 10),
    );
    if (date == null || !context.mounted) return;
    if (!includeTime) {
      onChanged(date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      onChanged(date); // user picked date but not time — store date at midnight
      return;
    }
    onChanged(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }
}

/// A row with a label and a tappable date-only picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return DateTimeField(
      label: label,
      value: value,
      onChanged: onChanged,
      includeTime: false,
      allowClear: allowClear,
    );
  }
}

/// Reusable form section header.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}
