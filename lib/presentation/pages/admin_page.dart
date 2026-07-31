import 'package:flutter/material.dart';

import '../../domain/entities/permission.dart';
import '../../domain/repositories/params.dart';

/// Admin page for managing access control permissions.
///
/// Allows granting and revoking permissions (View, Create, Modify, Move)
/// per user or per sector. User-level permissions take precedence over
/// sector-level when both exist.
///
/// Requirements: 11.1, 11.2
class AdminPage extends StatefulWidget {
  /// Existing permission grants to display.
  final List<PermissionGrant> existingGrants;

  /// Callback invoked when a new permission grant is added.
  final void Function(PermissionGrant grant)? onGrantPermission;

  /// Callback invoked when a permission grant is revoked by index.
  final void Function(int index)? onRevokePermission;

  const AdminPage({
    super.key,
    required this.existingGrants,
    this.onGrantPermission,
    this.onRevokePermission,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetIdController = TextEditingController();
  String _targetType = 'user';
  final Set<Permission> _selectedPermissions = {};

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Management'),
      ),
      body: Column(
        children: [
          _buildGrantForm(context),
          const Divider(height: 1),
          Expanded(child: _buildGrantList(context)),
        ],
      ),
    );
  }

  Widget _buildGrantForm(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grant Permissions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              // Target type selector
              Row(
                children: [
                  const Text('Target: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _targetType,
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'sector', child: Text('Sector')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _targetType = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Target ID input
              TextFormField(
                controller: _targetIdController,
                decoration: InputDecoration(
                  labelText:
                      _targetType == 'user' ? 'User ID' : 'Sector ID',
                  border: const OutlineInputBorder(),
                  hintText: _targetType == 'user'
                      ? 'Enter user ID'
                      : 'Enter sector ID',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Target ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Permission checkboxes
              Text(
                'Permissions:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: Permission.values.map((permission) {
                  return FilterChip(
                    label: Text(_permissionLabel(permission)),
                    selected: _selectedPermissions.contains(permission),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPermissions.add(permission);
                        } else {
                          _selectedPermissions.remove(permission);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitGrant,
                  icon: const Icon(Icons.add),
                  label: const Text('Grant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitGrant() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one permission to grant.'),
        ),
      );
      return;
    }

    final grant = PermissionGrant(
      targetType: _targetType,
      targetId: _targetIdController.text.trim(),
      permissions: Set<Permission>.from(_selectedPermissions),
    );

    widget.onGrantPermission?.call(grant);

    // Reset form
    _targetIdController.clear();
    setState(() {
      _selectedPermissions.clear();
    });
  }

  Widget _buildGrantList(BuildContext context) {
    if (widget.existingGrants.isEmpty) {
      return const Center(
        child: Text('No permission grants configured.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.existingGrants.length,
      itemBuilder: (context, index) {
        final grant = widget.existingGrants[index];
        return _PermissionGrantTile(
          grant: grant,
          onRevoke: () => widget.onRevokePermission?.call(index),
        );
      },
    );
  }

  String _permissionLabel(Permission permission) {
    return switch (permission) {
      Permission.view => 'View',
      Permission.create => 'Create',
      Permission.modify => 'Modify',
      Permission.move => 'Move',
    };
  }
}

/// Displays a single permission grant with a revoke action.
class _PermissionGrantTile extends StatelessWidget {
  final PermissionGrant grant;
  final VoidCallback? onRevoke;

  const _PermissionGrantTile({
    required this.grant,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcon = grant.targetType == 'user' ? Icons.person : Icons.business;
    final permLabels = grant.permissions.map(_permissionLabel).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(typeIcon),
        title: Text(grant.targetId),
        subtitle: Text(
          '${grant.targetType == 'user' ? 'User' : 'Sector'} • $permLabels',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Revoke',
          onPressed: onRevoke,
        ),
      ),
    );
  }

  String _permissionLabel(Permission permission) {
    return switch (permission) {
      Permission.view => 'View',
      Permission.create => 'Create',
      Permission.modify => 'Modify',
      Permission.move => 'Move',
    };
  }
}
