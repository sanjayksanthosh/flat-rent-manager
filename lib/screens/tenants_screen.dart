import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import 'tenant_details_screen.dart';
import 'move_in_screen.dart';
import '../widgets/loading_button.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _sortBy = 'name';
  int? _filterBuilding;
  bool _showMovedOut = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    final tenantBuildingMap = <int, String>{};
    final tenantBuildingIdMap = <int, int>{};
    final tenantFlatMap = <int, String>{};
    final tenantMovedOut = <int, bool>{};
    for (var lease in p.leases) {
      if (lease.moveOutDate != null) tenantMovedOut[lease.tenantId] = true;
      if (lease.moveOutDate != null) continue;
      String flatNo = lease.flatNumber ?? '';
      String bldName = lease.buildingName ?? '';
      int? bldId = lease.buildingId;
      if (flatNo.isEmpty || bldName.isEmpty || bldId == null) {
        final flat = p.getFlat(lease.flatId);
        if (flat != null) {
          if (flatNo.isEmpty) flatNo = flat.flatNumber;
          if (bldName.isEmpty || bldId == null) {
            final bld = p.getBuilding(flat.buildingId);
            bldName = bld?.buildingName ?? '';
            bldId = bld?.id ?? bldId;
          }
        }
      }
      tenantFlatMap[lease.tenantId] = flatNo;
      tenantBuildingMap[lease.tenantId] = bldName;
      if (bldId != null) tenantBuildingIdMap[lease.tenantId] = bldId;
    }

    var filtered = p.tenants.where((t) {
      if (t.id == null) return false;
      if (!_showMovedOut && tenantMovedOut[t.id] == true) return false;
      if (_filterBuilding != null && (tenantBuildingIdMap[t.id] ?? -1) != _filterBuilding) return false;
      if (_searchCtrl.text.isNotEmpty) {
        final q = _searchCtrl.text.toLowerCase();
        if (!t.name.toLowerCase().contains(q) && !t.phone.contains(q) && !t.phone2.contains(q)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name': return a.name.compareTo(b.name);
        case 'building': return (tenantBuildingMap[a.id!] ?? '').compareTo(tenantBuildingMap[b.id!] ?? '');
        case 'moved_out': return (tenantMovedOut[a.id!] == true ? 1 : 0).compareTo(tenantMovedOut[b.id!] == true ? 1 : 0);
        default: return a.name.compareTo(b.name);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      body: p.loading && p.tenants.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty && _searchCtrl.text.isEmpty && _filterBuilding == null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.people_outline, size: 80,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No tenants',
                        style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                  ]))
              : RefreshIndicator(
                  onRefresh: () => p.loadAll(),
                  child: R.constrain(context, child: Column(children: [
                    _buildFilters(p),
                    Expanded(child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final t = filtered[i];
                        final flatDisplay = tenantFlatMap[t.id!] ?? '';
                        final buildingDisplay = tenantBuildingMap[t.id!] ?? '';

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              child: Text(t.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Row(children: [
                              Flexible(child: Text(t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary))),
                              if (buildingDisplay.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(buildingDisplay, style: TextStyle(fontSize: 10, color: AppTheme.info.withValues(alpha: 0.8))),
                                ),
                              ],
                            ]),
                            subtitle: Text(
                                'Flat No: ${flatDisplay.isNotEmpty ? flatDisplay : '-'} · ${t.phone}',
                                style: TextStyle(color: AppTheme.textSecondary)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _editTenant(context, t);
                                } else if (v == 'view') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              TenantDetailsScreen(
                                                  tenantId: t.id!)));
                                } else if (v == 'delete') {
                                  _deleteTenant(context, t, p);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'view',
                                    child: ListTile(
                                        leading: Icon(Icons.visibility,
                                            size: 20),
                                        title: Text('View'),
                                        dense: true)),
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                        leading: Icon(Icons.edit, size: 20),
                                        title: Text('Edit'),
                                        dense: true)),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                        leading: Icon(Icons.delete,
                                            size: 20,
                                            color: AppTheme.danger),
                                        title: Text('Delete',
                                            style:
                                                TextStyle(color: AppTheme.danger)),
                                        dense: true)),
                              ],
                            ),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TenantDetailsScreen(
                                        tenantId: t.id!))),
                          ),
                        );
                      },
                    )),
                  ])),
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'move_in_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoveInScreen())),
        backgroundColor: AppTheme.success, foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add), label: const Text('Move In'),
      ),
    );
  }

  void _editTenant(BuildContext ctx, Tenant t) {
    final nameCtrl = TextEditingController(text: t.name);
    final phoneCtrl = TextEditingController(text: t.phone);
    final phone2Ctrl = TextEditingController(text: t.phone2);
    final ksebCtrl = TextEditingController(text: t.ksebNo);
    final addressCtrl = TextEditingController(text: t.address);
    final idProofCtrl = TextEditingController(text: t.idProof);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Tenant'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: phone2Ctrl,
                  decoration: const InputDecoration(labelText: 'Phone 2 (optional)'),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextFormField(
                  controller: ksebCtrl,
                  decoration: const InputDecoration(labelText: 'KSEB Consumer No (optional)'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: idProofCtrl,
                  decoration: const InputDecoration(labelText: 'ID Proof')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final updated = Tenant(
                id: t.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                phone2: phone2Ctrl.text.trim(),
                ksebNo: ksebCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                idProof: idProofCtrl.text.trim(),
                documents: t.documents,
                amenities: t.amenities,
              );
              ctx.read<AppProvider>().updateTenant(updated);
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Tenant updated'),
                      backgroundColor: AppTheme.success));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTenant(BuildContext ctx, Tenant t, AppProvider p) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Delete ${t.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel')),
          LoadingButton(
            label: 'Delete',
            icon: Icons.delete,
            backgroundColor: AppTheme.danger,
            expanded: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () async {
              await p.deleteTenant(t.id!);
              if (!dCtx.mounted) return;
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Tenant deleted')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AppProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _sortBy,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'building', child: Text('Building')),
                DropdownMenuItem(value: 'moved_out', child: Text('Moved Out')),
              ],
              onChanged: (v) => setState(() => _sortBy = v!),
            )),
          ),
          const SizedBox(width: 8),
          if (p.buildings.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
                value: _filterBuilding,
                isDense: true,
                hint: const Text('All', style: TextStyle(fontSize: 13)),
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...p.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.buildingName))),
                ],
                onChanged: (v) => setState(() => _filterBuilding = v),
              )),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _showMovedOut ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: GestureDetector(
              onTap: () => setState(() => _showMovedOut = !_showMovedOut),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 16, color: _showMovedOut ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Moved', style: TextStyle(fontSize: 12, color: _showMovedOut ? AppTheme.primary : AppTheme.textSecondary)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search tenant/phone',
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ]),
    );
  }
}
