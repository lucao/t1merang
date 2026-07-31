import 'package:flutter/material.dart';

import '../../domain/repositories/params.dart';

/// A dialog for creating a new activity with title input and validation.
///
/// Requirements: 1.1, 1.6
class CreateActivityDialog extends StatefulWidget {
  final String currentUserId;
  final String currentSectorId;
  final void Function(CreateActivityParams params)? onActivityCreated;

  const CreateActivityDialog({
    super.key,
    required this.currentUserId,
    required this.currentSectorId,
    this.onActivityCreated,
  });

  /// Shows the dialog and returns the [CreateActivityParams] on success,
  /// or null if the user cancelled.
  static Future<CreateActivityParams?> show(
    BuildContext context, {
    required String currentUserId,
    required String currentSectorId,
  }) {
    return showDialog<CreateActivityParams>(
      context: context,
      builder: (_) => CreateActivityDialog(
        currentUserId: currentUserId,
        currentSectorId: currentSectorId,
      ),
    );
  }

  @override
  State<CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<CreateActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the title field when the dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.trim().length > 200) {
      return 'Title must be 200 characters or less';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final params = CreateActivityParams(
        title: _titleController.text.trim(),
        sectorId: widget.currentSectorId,
        createdBy: widget.currentUserId,
      );

      if (widget.onActivityCreated != null) {
        widget.onActivityCreated!(params);
      }

      Navigator.of(context).pop(params);
    }
    // On validation failure, entered data is preserved (text stays in controller).
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Activity'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Enter activity title',
            border: OutlineInputBorder(),
          ),
          maxLength: 200,
          validator: _validateTitle,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
