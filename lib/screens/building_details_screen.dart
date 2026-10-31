import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/flat_model.dart';
import '../theme.dart';
import '../responsive.dart';
import '../services/whatsapp_helper.dart';
import 'add_edit_building_screen.dart';
import 'add_edit_flat_screen.dart';
import '../widgets/loading_button.dart';

class BuildingDetailsScreen extends StatelessWidget {
  final Building building;
  const BuildingDetailsScreen({super.key, required this.building});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final current = p.getBuilding(building.id!) ?? building;
    final flats = p.getFlatsByBuilding(current.id!);

    return Scaffold(
      appBar: AppBar(title: Text(current.buildingName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditBuildingScreen(building: current)));
              if (v == 'delete') _deleteBuilding(context, current, p);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Edit'))),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 20, color: AppTheme.danger), title: Text('Delete', style: TextStyle(color: AppTheme.danger)))),
            ],
          ),
        ],
      ),
              body: flats.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.home_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12), Text('No flats yet', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
            ]))
          : RefreshIndicator(
              onRefresh: () => p.loadAll(),
              child: R.constrain(context, child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (current.caretakerName.isNotEmpty || current.caretakerPhone.isNotEmpty || current.securityPhone.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          if (current.caretakerName.isNotEmpty)
                            _contactRow(Icons.person, 'Caretaker', current.caretakerName, current.caretakerPhone),
                          if (current.securityPhone.isNotEmpty)
                            _contactRow(Icons.security, 'Security', current.securityPhone, current.securityPhone),
                        ]),
                      ),
                    ),
                  ...flats.map((f) => _flatCard(context, f, p)),
                ],
              )),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditFlatScreen(buildingId: building.id))),
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Add Flat'),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String name, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('$label: $name', style: const TextStyle(fontSize: 13))),
        if (phone.isNotEmpty)
          GestureDetector(
            onTap: () => WhatsAppHelper.callPhone(phone: phone),
            child: Icon(Icons.phone, size: 18, color: AppTheme.primary),
          ),
      ]),
    );
  }

  Widget _flatCard(BuildContext context, Flat f, AppProvider p) {
    final isOcc = f.status == 'occupied';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: (isOcc ? AppTheme.success : AppTheme.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(f.flatNumber, style: TextStyle(fontWeight: FontWeight.bold, color: isOcc ? AppTheme.success : AppTheme.textSecondary, fontSize: 15))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Flat ${f.flatNumber} · Floor ${f.floor}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('₹${f.monthlyRent.toStringAsFixed(0)}/mo', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            AppTheme.statusChip(isOcc ? 'Occupied' : 'Vacant', isOcc ? AppTheme.success : AppTheme.textSecondary),
            if (f.tenant != null) ...[
              const SizedBox(height: 4),
              Text('Tenant: ${f.tenant!['name']}', style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w500)),
            ],
          ])),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditFlatScreen(flat: f)));
              if (v == 'delete') _deleteFlat(context, f, p);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Edit'))),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 20, color: AppTheme.danger), title: Text('Delete', style: TextStyle(color: AppTheme.danger)))),
            ],
          ),
        ]),
      ),
    );
  }

  void _deleteBuilding(BuildContext ctx, Building b, AppProvider p) {
    final flats = p.getFlatsByBuilding(b.id!);
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Building'),
      content: Text(flats.isEmpty
          ? 'Delete ${b.buildingName}? This cannot be undone.'
          : 'Delete ${b.buildingName} and all ${flats.length} flat(s)? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        LoadingButton(
          label: 'Delete',
          icon: Icons.delete,
          backgroundColor: AppTheme.danger,
          expanded: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onPressed: () async {
            for (var f in flats) { await p.deleteFlat(f.id!); }
            await p.deleteBuilding(b.id!);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (!ctx.mounted) return;
            Navigator.pop(ctx, true);
          },
        ),
      ],
    ));
  }

  void _deleteFlat(BuildContext ctx, Flat flat, AppProvider p) {
    if (flat.status == 'occupied') {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cannot delete — tenant assigned'), backgroundColor: AppTheme.danger));
      return;
    }
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Flat'), content: Text('Delete Flat ${flat.flatNumber}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        LoadingButton(
          label: 'Delete',
          icon: Icons.delete,
          backgroundColor: AppTheme.danger,
          expanded: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onPressed: () async {
            await p.deleteFlat(flat.id!);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
          },
        ),
      ],
    ));
  }
}
