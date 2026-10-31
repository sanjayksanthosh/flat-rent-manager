import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/loading_button.dart';

class AddEditBuildingScreen extends StatefulWidget {
  final Building? building;
  const AddEditBuildingScreen({super.key, this.building});

  @override
  State<AddEditBuildingScreen> createState() => _AddEditBuildingScreenState();
}

class _AddEditBuildingScreenState extends State<AddEditBuildingScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _caretakerNameCtrl = TextEditingController();
  final _caretakerPhoneCtrl = TextEditingController();
  final _securityPhoneCtrl = TextEditingController();
  bool get editing => widget.building != null;

  @override
  void initState() {
    super.initState();
    if (editing) {
      _nameCtrl.text = widget.building!.buildingName;
      _addrCtrl.text = widget.building!.address;
      _areaCtrl.text = widget.building!.area;
      _caretakerNameCtrl.text = widget.building!.caretakerName;
      _caretakerPhoneCtrl.text = widget.building!.caretakerPhone;
      _securityPhoneCtrl.text = widget.building!.securityPhone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addrCtrl.dispose(); _areaCtrl.dispose();
    _caretakerNameCtrl.dispose(); _caretakerPhoneCtrl.dispose(); _securityPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<AppProvider>();
    final b = Building(id: widget.building?.id, buildingName: _nameCtrl.text.trim(), address: _addrCtrl.text.trim(), area: _areaCtrl.text.trim(),
      caretakerName: _caretakerNameCtrl.text.trim(), caretakerPhone: _caretakerPhoneCtrl.text.trim(), securityPhone: _securityPhoneCtrl.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (editing) {
      await p.updateBuilding(b);
    } else {
      await p.addBuilding(b);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(
      content: Text(editing ? 'Building updated' : 'Building created successfully'),
      backgroundColor: AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Building' : 'Add Building')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: R.constrain(context, child: Form(
          key: _form,
          child: Column(children: [
            _field(controller: _nameCtrl, label: 'Building Name', icon: Icons.business, required: true),
            const SizedBox(height: 14),
            _field(controller: _addrCtrl, label: 'Address', icon: Icons.location_on),
            const SizedBox(height: 14),
            _field(controller: _areaCtrl, label: 'Area / Location', icon: Icons.map),
            const SizedBox(height: 14),
            _field(controller: _caretakerNameCtrl, label: 'Caretaker Name', icon: Icons.person),
            const SizedBox(height: 14),
            _field(controller: _caretakerPhoneCtrl, label: 'Caretaker Phone', icon: Icons.phone, phone: true),
            const SizedBox(height: 14),
            _field(controller: _securityPhoneCtrl, label: 'Security Phone', icon: Icons.security, phone: true),
            const SizedBox(height: 28),
            LoadingButton(
              label: editing ? 'Update Building' : 'Add Building',
              icon: Icons.check,
              onPressed: () async => _save(),
            ),
          ]),
        ),
        ),
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String label, required IconData icon, bool required = false, bool phone = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: '$label${required ? ' *' : ''}', prefixIcon: Icon(icon)),
      keyboardType: phone ? TextInputType.phone : TextInputType.text,
      validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
    );
  }
}
