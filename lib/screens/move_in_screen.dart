import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/document_attachments.dart';
import '../widgets/loading_button.dart';

class MoveInScreen extends StatefulWidget {
  final int? buildingId;
  final int? flatId;
  const MoveInScreen({super.key, this.buildingId, this.flatId});

  @override
  State<MoveInScreen> createState() => _MoveInScreenState();
}

class _MoveInScreenState extends State<MoveInScreen> {
  int _step = 0;
  int? _buildingId;
  int? _flatId;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _ksebCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  List<Map<String, String>> _documents = [];
  final _leaseStartCtrl = TextEditingController();
  final _leaseEndCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selectedAmenities = [];

  static const Map<String, IconData> _amenityIcons = {
    'fan': Icons.wind_power,
    'ceiling fan': Icons.wind_power,
    'ac': Icons.ac_unit,
    'air conditioner': Icons.ac_unit,
    'light': Icons.lightbulb,
    'lights': Icons.lightbulb,
    'tube light': Icons.lightbulb_outline,
    'bed': Icons.bed,
    'bedsheet': Icons.bed,
    'sofa': Icons.weekend,
    'tv': Icons.tv,
    'television': Icons.tv,
    'fridge': Icons.kitchen,
    'refrigerator': Icons.kitchen,
    'washing machine': Icons.local_laundry_service,
    'geyser': Icons.hot_tub,
    'water heater': Icons.hot_tub,
    'water purifier': Icons.water_drop,
    'ro': Icons.water_drop,
    'curtain': Icons.curtains,
    'curtains': Icons.curtains,
    'wardrobe': Icons.inventory_2,
    'almirah': Icons.inventory_2,
    'mirror': Icons.center_focus_strong,
    'table': Icons.table_chart,
    'dining table': Icons.table_chart,
    'chair': Icons.chair,
    'wifi': Icons.wifi,
    'internet': Icons.wifi,
    'microwave': Icons.microwave,
    'oven': Icons.microwave,
    'exhaust fan': Icons.air,
    'chimney': Icons.air,
    'camera': Icons.videocam,
    'cctv': Icons.videocam,
    'intercom': Icons.phone_in_talk,
    'lock': Icons.lock,
    'smart lock': Icons.lock,
    'mattress': Icons.bed,
    'pillow': Icons.bed,
    'dining chair': Icons.chair,
    'shoe rack': Icons.inventory,
    'bookshelf': Icons.library_books,
    'coffee table': Icons.table_chart,
    'side table': Icons.table_chart,
    'power backup': Icons.battery_charging_full,
    'inverter': Icons.battery_charging_full,
    'generator': Icons.electric_bolt,
    'water tank': Icons.water,
    'gas pipeline': Icons.local_gas_station,
    'modular kitchen': Icons.kitchen,
    'kitchen cabinet': Icons.kitchen,
    'bathroom fittings': Icons.bathtub,
    'geyser bathroom': Icons.bathtub,
    'shower': Icons.shower,
    'wash basin': Icons.bathtub,
    'toilet': Icons.wc,
    'soap dish': Icons.bathtub,
    'towel rack': Icons.bathtub,
    'dustbin': Icons.delete_outline,
    'fire extinguisher': Icons.fire_extinguisher,
    'smoke detector': Icons.smoke_free,
    'doorbell': Icons.doorbell,
    'nameplate': Icons.abc,
    'iron': Icons.iron,
    'ironing board': Icons.iron,
    'vacuum cleaner': Icons.cleaning_services,
    'air purifier': Icons.air,
    'dehumidifier': Icons.air,
    'water heater geyser': Icons.hot_tub,
    'storage': Icons.storage,
    'loft': Icons.archive,
    'balcony': Icons.balcony,
    'parking': Icons.local_parking,
    'car parking': Icons.local_parking,
    'bike parking': Icons.two_wheeler,
    'elevator': Icons.elevator,
    'lift': Icons.elevator,
    'staircase': Icons.stairs,
    'garden': Icons.yard,
    'pool': Icons.pool,
    'gym': Icons.fitness_center,
    'clubhouse': Icons.meeting_room,
    'play area': Icons.sports_baseball,
    'community hall': Icons.groups,
    'security': Icons.security,
    'guard': Icons.security,
  };

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _phone2Ctrl.dispose(); _ksebCtrl.dispose();
    _addrCtrl.dispose();
    _leaseStartCtrl.dispose(); _leaseEndCtrl.dispose(); _depositCtrl.dispose(); _rentCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.buildingId != null && widget.flatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {
          _buildingId = widget.buildingId;
          _flatId = widget.flatId;
          final p = context.read<AppProvider>();
          final flat = p.getFlat(widget.flatId!);
          if (flat != null && flat.monthlyRent > 0) {
            _rentCtrl.text = flat.monthlyRent.toStringAsFixed(0);
          }
          _step = 1;
        });
      });
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (d != null) ctrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _next() {
    if (_step == 0) {
      if (_flatId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a flat'))); return; }
      setState(() => _step = 1);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Phone required')));
      return;
    }
    if (_leaseStartCtrl.text.isEmpty || _leaseEndCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lease dates required')));
      return;
    }
    final p = context.read<AppProvider>();
    final existingFlat = p.getFlat(_flatId!);
    final rent = double.tryParse(_rentCtrl.text) ?? existingFlat?.monthlyRent ?? 0;
    if (rent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid monthly rent'), backgroundColor: AppTheme.danger));
      return;
    }
    final tenant = Tenant(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      phone2: _phone2Ctrl.text.trim(),
      ksebNo: _ksebCtrl.text.trim(),
      address: _addrCtrl.text.trim(),
      documents: List<Map<String, String>>.from(_documents),
      amenities: _selectedAmenities,
    );
    final messenger = ScaffoldMessenger.of(context);
    final created = await p.addTenant(tenant);
    final lease = Lease(
      tenantId: created.id ?? 0, flatId: _flatId!,
      leaseStart: _leaseStartCtrl.text.trim(), leaseEnd: _leaseEndCtrl.text.trim(),
      monthlyRent: rent,
      securityDeposit: double.tryParse(_depositCtrl.text) ?? 0,
    );
    await p.createLease(lease);
    if (existingFlat != null) {
      await p.updateFlat(Flat(id: _flatId, buildingId: existingFlat.buildingId, flatNumber: existingFlat.flatNumber,
          floor: existingFlat.floor, monthlyRent: rent, status: 'occupied'));
    }
    if (!mounted) return;
    Navigator.pop(context, true);
    messenger.showSnackBar(const SnackBar(content: Text('Tenant moved in successfully'), backgroundColor: AppTheme.success));
  }

  IconData _getAmenityIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (_amenityIcons.containsKey(lower)) return _amenityIcons[lower]!;
    for (final entry in _amenityIcons.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) return entry.value;
    }
    return Icons.category;
  }

  Color _getAmenityColor(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('fan') || lower.contains('ac') || lower.contains('air')) return const Color(0xFF3B82F6);
    if (lower.contains('light') || lower.contains('lamp')) return const Color(0xFFF59E0B);
    if (lower.contains('bed') || lower.contains('mattress') || lower.contains('pillow')) return const Color(0xFF8B5CF6);
    if (lower.contains('sofa') || lower.contains('chair') || lower.contains('table')) return const Color(0xFFEC4899);
    if (lower.contains('tv') || lower.contains('television')) return const Color(0xFF1A1A2E);
    if (lower.contains('fridge') || lower.contains('refrigerator') || lower.contains('kitchen')) return const Color(0xFF10B981);
    if (lower.contains('wash') || lower.contains('laundry')) return const Color(0xFF06B6D4);
    if (lower.contains('water') || lower.contains('ro') || lower.contains('geyser')) return const Color(0xFF0EA5E9);
    if (lower.contains('wifi') || lower.contains('internet') || lower.contains('camera') || lower.contains('cctv')) return const Color(0xFF6366F1);
    if (lower.contains('curtain') || lower.contains('wardrobe') || lower.contains('mirror')) return const Color(0xFFD946EF);
    if (lower.contains('security') || lower.contains('lock') || lower.contains('guard')) return const Color(0xFFEF4444);
    if (lower.contains('parking') || lower.contains('car') || lower.contains('bike')) return const Color(0xFF78716C);
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final vacantFlats = p.flats.where((f) => f.status == 'vacant').toList();
    if (_buildingId != null) vacantFlats.retainWhere((f) => f.buildingId == _buildingId);

    return Scaffold(
      appBar: AppBar(title: Text(_step == 0 ? 'Select Flat' : 'Tenant Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: R.constrain(context, child: Column(children: [
          _stepIndicator(),
          const SizedBox(height: 24),
          _step == 0 ? _buildStep1(p, vacantFlats) : _buildStep2(p),
        ])),
      ),
    );
  }

  Widget _stepIndicator() {
    return Row(children: [
      _stepDot(0, 'Select Flat'), _stepLine(), _stepDot(1, 'Details'),
    ]);
  }

  Widget _stepDot(int index, String label) {
    final active = _step >= index;
    final done = _step > index;
    return Expanded(child: Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppTheme.success : (active ? AppTheme.primary : AppTheme.border),
        ),
        child: Center(child: done
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : Text('${index + 1}', style: TextStyle(color: active ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w600))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: active ? AppTheme.primary : AppTheme.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    ]));
  }

  Widget _stepLine() {
    return Container(width: 40, height: 2, color: _step > 0 ? AppTheme.success : AppTheme.border);
  }

  Widget _buildStep1(AppProvider p, List<Flat> vacantFlats) {
    return Column(children: [
      DropdownButtonFormField<int>(
        value: _buildingId,
        decoration: const InputDecoration(labelText: 'Building', prefixIcon: Icon(Icons.business)),
        items: p.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.buildingName))).toList(),
        onChanged: (v) => setState(() { _buildingId = v; _flatId = null; }),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(
        value: _flatId,
        decoration: const InputDecoration(labelText: 'Vacant Flat', prefixIcon: Icon(Icons.home)),
        items: vacantFlats.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.flatNumber} — Floor ${f.floor} (₹${f.monthlyRent.toStringAsFixed(0)})'))).toList(),
        onChanged: (v) => setState(() => _flatId = v),
      ),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _next, child: const Text('Next'))),
    ]);
  }

  Widget _buildStep2(AppProvider p) {
    return Column(children: [
      TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tenant Name *', prefixIcon: Icon(Icons.person))),
      const SizedBox(height: 12),
      TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      TextFormField(controller: _phone2Ctrl, decoration: const InputDecoration(labelText: 'Phone 2 (optional)', prefixIcon: Icon(Icons.phone_android)), keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      TextFormField(controller: _ksebCtrl, decoration: const InputDecoration(labelText: 'KSEB Consumer No (optional)', prefixIcon: Icon(Icons.bolt)), keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      TextFormField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: DocumentsEditor(
          documents: _documents,
          onChanged: (docs) => setState(() => _documents = docs),
          emptyText: 'Attach ID proof, agreement or other documents (images/PDF)',
        ),
      ),
      const SizedBox(height: 20),
      const Align(alignment: Alignment.centerLeft, child: Text('Rental Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
      const SizedBox(height: 12),
      TextFormField(controller: _leaseStartCtrl, readOnly: true,
        decoration: InputDecoration(labelText: 'Lease Start *', prefixIcon: const Icon(Icons.date_range), suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => _pickDate(_leaseStartCtrl))),
        onTap: () => _pickDate(_leaseStartCtrl)),
      const SizedBox(height: 12),
      TextFormField(controller: _leaseEndCtrl, readOnly: true,
        decoration: InputDecoration(labelText: 'Lease End *', prefixIcon: const Icon(Icons.date_range), suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => _pickDate(_leaseEndCtrl))),
        onTap: () => _pickDate(_leaseEndCtrl)),
      const SizedBox(height: 12),
      TextFormField(controller: _rentCtrl, decoration: const InputDecoration(labelText: 'Monthly Rent (₹) *', prefixIcon: Icon(Icons.currency_rupee)), keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      TextFormField(controller: _depositCtrl, decoration: const InputDecoration(labelText: 'Security Deposit (₹)', prefixIcon: Icon(Icons.money)), keyboardType: TextInputType.number),
      const SizedBox(height: 24),
      _buildAmenitiesSection(p),
      const SizedBox(height: 24),
      LoadingButton(
        label: 'Save & Create Lease',
        icon: Icons.check_circle,
        backgroundColor: AppTheme.success,
        onPressed: _save,
      ),
    ]);
  }

  Widget _buildAmenitiesSection(AppProvider p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.chair, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        const Text('Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () => _showAddAmenityDialog(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 16, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text('Add New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Tap to select, long press to remove', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      const SizedBox(height: 12),
      if (p.amenitiesCatalog.isEmpty && _selectedAmenities.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Icon(Icons.chair_alt, size: 36, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('No amenities yet', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Tap "Add New" to create amenities', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4), fontSize: 11)),
          ]),
        )
      else ...[
        if (p.amenitiesCatalog.isNotEmpty) ...[
          Text('Available Amenities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.amenitiesCatalog.map((a) {
              final name = a['name'] as String? ?? '';
              final isSelected = _selectedAmenities.any((s) => s['name'] == name);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAmenities.removeWhere((s) => s['name'] == name);
                    } else {
                      _selectedAmenities.add({'name': name, 'count': 1});
                    }
                  });
                },
                onLongPress: () => _showRemoveAmenityDialog(p, name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _getAmenityColor(name).withValues(alpha: 0.15) : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? _getAmenityColor(name) : AppTheme.border.withValues(alpha: 0.5),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getAmenityIcon(name), size: 18, color: isSelected ? _getAmenityColor(name) : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(name, style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? _getAmenityColor(name) : AppTheme.textPrimary,
                    )),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
        if (_selectedAmenities.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Selected Amenities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ..._selectedAmenities.map((a) {
            final name = a['name'] as String? ?? '';
            final count = a['count'] as int? ?? 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _getAmenityColor(name).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getAmenityColor(name).withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getAmenityColor(name).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getAmenityIcon(name), size: 20, color: _getAmenityColor(name)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                Container(
                  decoration: BoxDecoration(
                    color: _getAmenityColor(name).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: 18, color: _getAmenityColor(name)),
                      onPressed: () {
                        setState(() {
                          if (count <= 1) {
                            _selectedAmenities.removeWhere((s) => s['name'] == name);
                          } else {
                            final idx = _selectedAmenities.indexWhere((s) => s['name'] == name);
                            if (idx != -1) _selectedAmenities[idx] = {'name': name, 'count': count - 1};
                          }
                        });
                      },
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _getAmenityColor(name))),
                    IconButton(
                      icon: Icon(Icons.add, size: 18, color: _getAmenityColor(name)),
                      onPressed: () {
                        setState(() {
                          final idx = _selectedAmenities.indexWhere((s) => s['name'] == name);
                          if (idx != -1) _selectedAmenities[idx] = {'name': name, 'count': count + 1};
                        });
                      },
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ]),
                ),
              ]),
            );
          }),
        ],
      ],
    ]);
  }

  void _showAddAmenityDialog(AppProvider p) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Amenity'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Amenity Name *', hintText: 'e.g. Fan, AC, Bed'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('Tip: Common names get better icons', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = ctrl.text.trim();
              final exists = p.amenitiesCatalog.any((a) => (a['name'] as String?)?.toLowerCase() == name.toLowerCase());
              if (exists) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Amenity already exists'), backgroundColor: AppTheme.warning));
                return;
              }
              p.addAmenityToCatalog({'name': name, 'icon': name.toLowerCase()});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to amenities'), backgroundColor: AppTheme.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRemoveAmenityDialog(AppProvider p, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Amenity'),
        content: Text('Remove "$name" from the amenities catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              p.removeAmenityFromCatalog(name);
              setState(() => _selectedAmenities.removeWhere((s) => s['name'] == name));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name removed from catalog'), backgroundColor: AppTheme.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
