import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/loading_button.dart';

class AddEditFlatScreen extends StatefulWidget {
  final Flat? flat;
  final int? buildingId;
  const AddEditFlatScreen({super.key, this.flat, this.buildingId});

  @override
  State<AddEditFlatScreen> createState() => _AddEditFlatScreenState();
}

class _AddEditFlatScreenState extends State<AddEditFlatScreen> {
  final _form = GlobalKey<FormState>();
  final _flatNoCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  int? _buildingId;
  bool get editing => widget.flat != null;

  @override
  void initState() {
    super.initState();
    _buildingId = widget.flat?.buildingId ?? widget.buildingId;
    if (editing) {
      _flatNoCtrl.text = widget.flat!.flatNumber;
      _floorCtrl.text = widget.flat!.floor;
      _rentCtrl.text = widget.flat!.monthlyRent.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _flatNoCtrl.dispose(); _floorCtrl.dispose(); _rentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_buildingId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select building'))); return; }
    final f = Flat(id: widget.flat?.id, buildingId: _buildingId!, flatNumber: _flatNoCtrl.text.trim(),
      floor: _floorCtrl.text.trim(), monthlyRent: double.tryParse(_rentCtrl.text) ?? 0,
      status: widget.flat?.status ?? 'vacant');
    final p = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (editing) {
      await p.updateFlat(f);
    } else {
      await p.addFlat(f);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(
      content: Text(editing ? 'Flat updated' : 'Flat created successfully'),
      backgroundColor: AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Flat' : 'Add Flat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: R.constrain(context, child: Form(key: _form, child: Column(children: [
          if (!editing) DropdownButtonFormField<int>(
            value: _buildingId,
            decoration: const InputDecoration(labelText: 'Building *', prefixIcon: Icon(Icons.business)),
            items: p.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.buildingName))).toList(),
            onChanged: (v) => setState(() => _buildingId = v),
            validator: (v) => v == null ? 'Select building' : null,
          ),
          if (!editing) const SizedBox(height: 14),
          TextFormField(controller: _flatNoCtrl, decoration: const InputDecoration(labelText: 'Flat Number *', prefixIcon: Icon(Icons.tag)), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _floorCtrl, decoration: const InputDecoration(labelText: 'Floor (G, M, Roof, 1, 2...)', prefixIcon: Icon(Icons.layers))),
          const SizedBox(height: 14),
          TextFormField(controller: _rentCtrl, decoration: const InputDecoration(labelText: 'Monthly Rent (₹) *', prefixIcon: Icon(Icons.currency_rupee)), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 28),
          LoadingButton(
            label: editing ? 'Update Flat' : 'Add Flat',
            icon: Icons.check,
            onPressed: () async => _save(),
          ),
        ]))),
      ),
    );
  }
}
