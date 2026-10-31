import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import 'add_edit_building_screen.dart';
import 'building_details_screen.dart';

class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Buildings')),
      body: p.loading && p.buildings.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : p.buildings.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.business_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No buildings yet', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Text('Tap + to add your first building', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.4))),
              ]))
            : RefreshIndicator(
                onRefresh: () => p.loadAll(),
                child: R.constrain(context, child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: p.buildings.length,
                  itemBuilder: (_, i) {
                    final b = p.buildings[i];
                    final flats = p.getFlatsByBuilding(b.id!);
                    final occupied = flats.where((f) => f.status == 'occupied').length;
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BuildingDetailsScreen(building: b))),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.business, color: AppTheme.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(b.buildingName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              if (b.area.isNotEmpty) Text(b.area, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              const SizedBox(height: 6),
                              Row(children: [
                                _miniChip('${flats.length} flats', AppTheme.info),
                                const SizedBox(width: 8),
                                _miniChip('$occupied occupied', AppTheme.success),
                              ]),
                            ])),
                            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                          ]),
                        ),
                      ),
                    );
                  },
                )),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditBuildingScreen())),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Building'),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    );
  }
}
