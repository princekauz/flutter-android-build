import 'package:flutter/material.dart';

/// Shows a bottom-sheet form dialog with [children], a Save + Cancel
/// action bar at the bottom. Used by every entity editor.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required List<Widget> Function(BuildContext) builder,
    required VoidCallback onSave,
    String saveLabel = 'Save',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: FormDialog(
          title: title,
          onSave: onSave,
          saveLabel: saveLabel,
          children: builder(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSave,
                  child: Text(saveLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small gap between form fields.
const sizedBoxH = SizedBox(height: 12);

/// A bigger gap.
const sizedBoxH16 = SizedBox(height: 16);
