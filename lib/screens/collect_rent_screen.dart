import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_share_plus/whatsapp_share_plus.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../responsive.dart';
import '../widgets/loading_button.dart';

class CollectRentScreen extends StatefulWidget {
  final int? leaseId;
  final String? tenantName;
  final String? flatNo;
  final double? amount;
  const CollectRentScreen({super.key, this.leaseId, this.tenantName, this.flatNo, this.amount});

  @override
  State<CollectRentScreen> createState() => _CollectRentScreenState();
}

class _CollectRentScreenState extends State<CollectRentScreen> {
  int? _buildingId;
  int? _flatId;
  int? _leaseId;
  Lease? _lease;
  final _amountCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _method = 'Cash';
  String _date = DateTime.now().toIso8601String().split('T')[0];
  int _payMonth = DateTime.now().month;
  int _payYear = DateTime.now().year;

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    if (widget.leaseId != null) {
      final p = context.read<AppProvider>();
      _leaseId = widget.leaseId;
      final l = p.leases.firstWhere((x) => x.id == _leaseId, orElse: () => Lease(tenantId: 0, flatId: 0, leaseStart: '', leaseEnd: ''));
      _lease = l;
      _flatId = l.flatId;
      final flat = p.getFlat(l.flatId);
      if (flat != null) _buildingId = flat.buildingId;
      if (widget.amount != null) {
        _amountCtrl.text = widget.amount!.toStringAsFixed(0);
      } else if (l.id != null) {
        _amountCtrl.text = p.rentFor(l).toStringAsFixed(0);
      }
      if (l.id != null && l.leaseStart.isNotEmpty) {
        final now = DateTime.now();
        final startParts = l.leaseStart.split('-');
        final startMonth = startParts.length >= 2 ? int.tryParse(startParts[1]) ?? 1 : 1;
        final startYear = startParts.length >= 3 ? int.tryParse(startParts[0]) ?? now.year : now.year;
        final oldestPending = _findOldestPendingMonth(p, l, startMonth, startYear);
        _payMonth = oldestPending.month;
        _payYear = oldestPending.year;
      }
    }
    _syncDateToPeriod();
  }

  @override
  void dispose() { _amountCtrl.dispose(); _discountCtrl.dispose(); _dateCtrl.dispose(); super.dispose(); }

  /// The payment date follows the period being paid for, so collecting an old
  /// month does not stamp today's date on the receipt.
  void _syncDateToPeriod() {
    final now = DateTime.now();
    final lastDay = DateTime(_payYear, _payMonth + 1, 0).day;
    final day = (_payYear == now.year && _payMonth == now.month)
        ? now.day
        : now.day.clamp(1, lastDay);
    _date = '${_payYear.toString().padLeft(4, '0')}-${_payMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    _dateCtrl.text = _date;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (d != null) setState(() {
      _date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      _dateCtrl.text = _date;
    });
  }

  void _onFlatSelected() {
    final p = context.read<AppProvider>();
    var activeLease = p.leases.firstWhere(
      (l) => l.flatId == _flatId && l.moveOutDate == null,
      orElse: () => Lease(tenantId: 0, flatId: 0, leaseStart: '', leaseEnd: ''),
    );
    if (activeLease.id == null) {
      setState(() { _leaseId = null; _lease = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active lease for this flat'), backgroundColor: AppTheme.danger));
      return;
    }
    // Fill in missing details from tenants/flats lists
    if (activeLease.tenantName?.isEmpty != false ||
        activeLease.flatNumber?.isEmpty != false ||
        activeLease.buildingName?.isEmpty != false) {
      final tenant = p.tenants.firstWhere(
        (t) => t.id == activeLease.tenantId,
        orElse: () => Tenant(name: '', phone: ''),
      );
      final flat = p.flats.firstWhere(
        (f) => f.id == activeLease.flatId,
        orElse: () => Flat(buildingId: 0, flatNumber: ''),
      );
      final building = p.buildings.firstWhere(
        (b) => b.id == flat.buildingId,
        orElse: () => Building(buildingName: ''),
      );
      activeLease = Lease(
        id: activeLease.id,
        tenantId: activeLease.tenantId,
        flatId: activeLease.flatId,
        leaseStart: activeLease.leaseStart,
        leaseEnd: activeLease.leaseEnd,
        monthlyRent: flat.monthlyRent,
        advanceMonths: activeLease.advanceMonths,
        securityDeposit: activeLease.securityDeposit,
        moveOutDate: activeLease.moveOutDate,
        tenantName: tenant.name.isNotEmpty ? tenant.name : activeLease.tenantName,
        tenantPhone: tenant.phone.isNotEmpty ? tenant.phone : activeLease.tenantPhone,
        flatNumber: flat.flatNumber.isNotEmpty ? flat.flatNumber : activeLease.flatNumber,
        buildingName: building.buildingName.isNotEmpty ? building.buildingName : flat.buildingName,
        buildingId: building.id != null ? building.id : activeLease.buildingId,
      );
    }
    final now = DateTime.now();
    final leaseStartParts = activeLease.leaseStart.split('-');
    final leaseStartMonth = leaseStartParts.length >= 2 ? int.tryParse(leaseStartParts[1]) ?? 1 : 1;
    final leaseStartYear = leaseStartParts.length >= 3 ? int.tryParse(leaseStartParts[0]) ?? now.year : now.year;
    final oldestPending = _findOldestPendingMonth(p, activeLease, leaseStartMonth, leaseStartYear);
    setState(() {
      _leaseId = activeLease.id;
      _lease = activeLease;
      _payMonth = oldestPending.month;
      _payYear = oldestPending.year;
      _amountCtrl.text = p.rentFor(activeLease).toStringAsFixed(0);
      _syncDateToPeriod();
    });
  }

  double _monthDue(AppProvider p, Lease lease, int m, int y) {
    final rent = p.rentFor(lease);
    final monthPmts = p.payments.where((pmt) => pmt.leaseId == lease.id && pmt.month == m && pmt.year == y).toList();
    final discounted = monthPmts.where((pmt) => pmt.discount > 0).toList();
    if (discounted.isNotEmpty) return (rent - discounted.first.discount).clamp(0, double.infinity).toDouble();
    final settled = monthPmts.where((pmt) => pmt.settled).toList();
    if (settled.isNotEmpty) return settled.fold<double>(0, (s, pmt) => s + pmt.amount);
    return rent;
  }

  ({int month, int year}) _findOldestPendingMonth(AppProvider p, Lease lease, int startMonth, int startYear) {
    final now = DateTime.now();
    final leasePayments = p.payments.where((pmt) => pmt.leaseId == lease.id).toList();
    // Money received before the lease began is advance credit.
    double carryForward = leasePayments
        .where((pmt) => pmt.year < startYear || (pmt.year == startYear && pmt.month < startMonth))
        .fold<double>(0, (s, pmt) => s + pmt.amountPaid);
    final totalMonths = ((now.year - startYear) * 12) + (now.month - startMonth) + 1;
    for (int i = 0; i < totalMonths; i++) {
      final m = ((startMonth + i - 1) % 12) + 1;
      final y = startYear + ((startMonth + i - 1) ~/ 12);
      final monthTotal = leasePayments
          .where((pmt) => pmt.month == m && pmt.year == y)
          .fold<double>(0, (s, pmt) => s + pmt.amountPaid);
      final available = monthTotal + carryForward;
      final monthDue = _monthDue(p, lease, m, y);
      if (available + 0.5 < monthDue) return (month: m, year: y);
      carryForward = available - monthDue;
    }
    // Everything up to now is covered — default to the next period (or the
    // lease start if it has not begun yet).
    final next = DateTime(now.year, now.month + 1);
    final start = DateTime(startYear, startMonth);
    final candidate = start.isAfter(next) ? start : next;
    return (month: candidate.month, year: candidate.year);
  }

  Future<void> _save() async {
    if (_leaseId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a flat with active lease'))); return; }
    if (_amountCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount'))); return; }
    final p = context.read<AppProvider>();
    if (_lease == null || _lease!.id == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lease error — please reselect the flat'), backgroundColor: AppTheme.danger)); return; }

    final amountPaid = double.tryParse(_amountCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    if (amountPaid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount'), backgroundColor: AppTheme.danger));
      return;
    }
    final rent = p.rentFor(_lease!);
    if (discount < 0 || discount > rent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount cannot be more than the rent'), backgroundColor: AppTheme.danger));
      return;
    }
    final amount = (rent - discount).clamp(0, double.infinity).toDouble();
    final status = amountPaid >= amount ? 'paid' : (amountPaid > 0 ? 'partial' : 'not_paid');
    final isSettled = discount > 0 && amountPaid >= amount;

    await p.addPayment(RentPayment(
      leaseId: _leaseId!, month: _payMonth, year: _payYear,
      amount: amount, amountPaid: amountPaid,
      balance: amount - amountPaid,
      paymentDate: _date, paymentMethod: _method,
      status: status, settled: isSettled, discount: discount, monthlyRent: rent,
      tenantId: _lease!.tenantId, flatId: _lease!.flatId,
      buildingId: _lease!.buildingId,
      tenantName: _lease!.tenantName, flatNumber: _lease!.flatNumber,
      buildingName: _lease!.buildingName,
    ));

    if (!mounted) return;
    Navigator.pop(context, true);
    _showReceipt(amountPaid, isSettled ? 'settled' : status, discount, rent);
  }

  void _showReceipt(double amountPaid, String status, double discount, double rent) {
    final rKey = GlobalKey();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Receipt'),
        content: RepaintBoundary(
          key: rKey,
          child: _ReceiptWidget(
            flatNumber: _lease!.flatNumber ?? widget.flatNo ?? '-',
            tenantName: _lease!.tenantName ?? widget.tenantName ?? 'Tenant',
            month: _payMonth,
            year: _payYear,
            monthlyRent: rent,
            amountPaid: amountPaid,
            discount: discount,
            status: status == 'paid' ? 'Paid' : (status == 'settled' ? 'Settled' : (status == 'partial' ? 'Partial' : 'Unpaid')),
            date: _date,
            method: _method,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () async {
              final t = _lease;
              if (t == null) return;
              final name = t.tenantName ?? 'Tenant';
              final monthYear = '$_payMonth/$_payYear';
              final p = ctx.read<AppProvider>();
              final tenant = p.tenants.firstWhere(
                (x) => x.id == t.tenantId,
                orElse: () => Tenant(name: name, phone: ''),
              );
              final phone = tenant.phone;
              try {
                final boundary = rKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                if (boundary != null) {
                  final image = await boundary.toImage(pixelRatio: 3);
                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  if (byteData != null) {
                    final bytes = byteData.buffer.asUint8List();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (kIsWeb) {
                      await Share.shareXFiles(
                        [XFile.fromData(bytes, mimeType: 'image/png', name: 'rent_receipt_$monthYear.png')],
                        text: 'Rent Receipt for $name — $monthYear',
                      );
                    } else if (phone.isNotEmpty) {
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png');
                      await file.writeAsBytes(bytes);
                      await WhatsappSharePlus.shareImageToWhatsapp(
                        imagePath: file.path,
                        text: 'Rent Receipt for $name — $monthYear',
                        phone: phone,
                      );
                    }
                    return;
                  }
                }
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Receipt'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Collect Rent')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: R.constrain(context, child: Column(children: [
          if (widget.leaseId == null) ...[
            DropdownButtonFormField<int>(
              value: _buildingId,
              decoration: const InputDecoration(labelText: 'Select Building', prefixIcon: Icon(Icons.business)),
              items: p.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.buildingName))).toList(),
              onChanged: (v) => setState(() { _buildingId = v; _flatId = null; _leaseId = null; _lease = null; _amountCtrl.clear(); }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _flatId,
              decoration: const InputDecoration(labelText: 'Select Flat', prefixIcon: Icon(Icons.home)),
              items: p.flats.where((f) => f.buildingId == _buildingId && f.status == 'occupied').map((f) {
                final activeLease = p.leases.firstWhere(
                  (l) => l.flatId == f.id && l.moveOutDate == null,
                  orElse: () => Lease(tenantId: 0, flatId: 0, leaseStart: '', leaseEnd: ''),
                );
                return DropdownMenuItem(value: f.id, child: Text('${f.flatNumber} — ${activeLease.tenantName ?? ''}'));
              }).toList(),
              onChanged: (v) { setState(() => _flatId = v); WidgetsBinding.instance.addPostFrameCallback((_) => _onFlatSelected()); },
            ),
            const SizedBox(height: 14),
          ],
          if (_lease != null && _lease!.id != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('Flat', _lease!.flatNumber ?? '-'),
                  _row('Tenant', _lease!.tenantName ?? '-'),
                  _row('Rent', '₹${p.rentFor(_lease!).toStringAsFixed(0)}/mo'),
                  _row('Paying for', '${_monthNames[_payMonth - 1]} $_payYear'),
                ]),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _payMonth,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paying for (month)', prefixIcon: Icon(Icons.event)),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() { _payMonth = v; _syncDateToPeriod(); });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _payYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: _yearOptions
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() { _payYear = v; _syncDateToPeriod(); });
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee)), keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          TextFormField(controller: _discountCtrl, decoration: const InputDecoration(labelText: 'Discount (₹)', prefixIcon: Icon(Icons.currency_rupee), helperText: 'Deducted from rent — won\'t show as pending'), keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payment)),
            items: ['Cash', 'Bank Transfer', 'Cheque', 'UPI', 'Other'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 14),
          TextFormField(
            readOnly: true,
            controller: _dateCtrl,
            decoration: InputDecoration(labelText: 'Payment Date', prefixIcon: const Icon(Icons.date_range), suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate)),
          ),
          const SizedBox(height: 28),
          LoadingButton(
            label: 'Record Payment',
            icon: Icons.payments,
            backgroundColor: AppTheme.accent,
            onPressed: _save,
          ),
        ])),
      ),
    );
  }

  List<int> get _yearOptions {
    final now = DateTime.now().year;
    return <int>{for (int y = now - 3; y <= now + 5; y++) y, _payYear}.toList()..sort();
  }

  Widget _row(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)), Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary))],
    ));
  }
}

class _ReceiptWidget extends StatelessWidget {
  final String flatNumber, tenantName, status, date, method;
  final int month, year;
  final double monthlyRent, amountPaid, discount;

  const _ReceiptWidget({
    required this.flatNumber,
    required this.tenantName,
    required this.month,
    required this.year,
    required this.monthlyRent,
    required this.amountPaid,
    required this.discount,
    required this.status,
    required this.date,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 400 ? 360 : 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(30)),
            child: Text(status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 4)),
          ),
          const SizedBox(height: 16),
          const Text('Rent Receipt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const Divider(height: 24),
          _row('Flat No', flatNumber),
          _row('Tenant', tenantName),
          _row('Period', '$month/$year'),
          _row('Monthly Rent', '₹${monthlyRent.toStringAsFixed(0)}'),
          if (discount > 0) _row('Discount', '-₹${discount.toStringAsFixed(0)}'),
          _row('Amount Paid', '₹${amountPaid.toStringAsFixed(0)}'),
          _row('Method', method),
          _row('Date', date),
          const Divider(height: 24),
          Text('Thank you!',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
