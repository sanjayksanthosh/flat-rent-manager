import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/loading_button.dart';

class MoveOutScreen extends StatefulWidget {
  const MoveOutScreen({super.key});

  @override
  State<MoveOutScreen> createState() => _MoveOutScreenState();
}

class _MoveOutScreenState extends State<MoveOutScreen> {
  int? _buildingId;
  int? _flatId;
  Lease? _activeLease;

  void _onFlatSelected() {
    if (_flatId == null) { setState(() => _activeLease = null); return; }
    setState(() => _activeLease = context.read<AppProvider>().getActiveLeaseByFlat(_flatId!));
  }

  void _confirmMoveOut() {
    if (_activeLease == null) return;
    showDialog(context: context, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Move Out'),
      content: Text('Move out ${_activeLease!.tenantName} from Flat ${_activeLease!.flatNumber}?\n\n'
          'Security Deposit: ₹${_activeLease!.securityDeposit.toStringAsFixed(0)}\n'
          'Monthly Rent: ₹${context.read<AppProvider>().rentFor(_activeLease!).toStringAsFixed(0)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        LoadingButton(
          label: 'Complete Move Out',
          icon: Icons.exit_to_app,
          backgroundColor: AppTheme.danger,
          expanded: false,
          onPressed: () async {
            await context.read<AppProvider>().moveOut(_activeLease!.id!, DateTime.now().toIso8601String().split('T')[0]);
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            if (!mounted) return;
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Move out completed'), backgroundColor: AppTheme.success));
          },
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final occupiedFlats = p.flats.where((f) => f.status == 'occupied').toList();
    if (_buildingId != null) occupiedFlats.retainWhere((f) => f.buildingId == _buildingId);

    return Scaffold(
      appBar: AppBar(title: const Text('Move Out')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: R.constrain(context, child: Column(children: [
          DropdownButtonFormField<int>(
            value: _buildingId,
            decoration: const InputDecoration(labelText: 'Building', prefixIcon: Icon(Icons.business)),
            items: p.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.buildingName))).toList(),
            onChanged: (v) => setState(() { _buildingId = v; _flatId = null; _activeLease = null; }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: _flatId,
            decoration: const InputDecoration(labelText: 'Occupied Flat', prefixIcon: Icon(Icons.home)),
            items: occupiedFlats.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.flatNumber} — ${f.buildingName ?? ''}'))).toList(),
            onChanged: (v) { setState(() => _flatId = v); _onFlatSelected(); },
          ),
          if (_activeLease != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Lease Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                const SizedBox(height: 10),
                Divider(color: AppTheme.border.withValues(alpha: 0.5)),
                _row('Tenant', _activeLease!.tenantName ?? '-'),
                _row('Flat', _activeLease!.flatNumber ?? '-'),
                _row('Building', _activeLease!.buildingName ?? '-'),
                _row('Monthly Rent', '₹${p.rentFor(_activeLease!).toStringAsFixed(0)}'),
                _row('Deposit', '₹${_activeLease!.securityDeposit.toStringAsFixed(0)}'),
                _row('Lease End', _activeLease!.leaseEnd),
              ])),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
              onPressed: _confirmMoveOut,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Complete Move Out'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            )),
          ],
        ])),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: TextStyle(color: AppTheme.textSecondary)), Text(value, style: const TextStyle(fontWeight: FontWeight.w500))],
    ));
  }
}
