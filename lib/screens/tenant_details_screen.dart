import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../services/whatsapp_helper.dart';
import '../widgets/document_attachments.dart';
import '../widgets/loading_button.dart';
import 'collect_rent_screen.dart';
import '../responsive.dart';

class TenantDetailsScreen extends StatelessWidget {
  final int tenantId;
  const TenantDetailsScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final t = p.getTenant(tenantId);
    if (t == null) return Scaffold(appBar: AppBar(title: const Text('Tenant')), body: const Center(child: Text('Not found')));
    final leases = p.getLeasesByTenant(tenantId);
    Lease? activeLease;
    try { activeLease = leases.firstWhere((l) => l.moveOutDate == null); } catch (_) {}

    // Fill missing flat/building info
    if (activeLease != null && (activeLease.flatNumber == null || activeLease.flatNumber!.isEmpty || activeLease.buildingName == null || activeLease.buildingName!.isEmpty)) {
      final flat = p.getFlat(activeLease.flatId);
      final building = flat != null ? p.getBuilding(flat.buildingId) : null;
      activeLease = Lease(
        id: activeLease.id,
        tenantId: activeLease.tenantId,
        flatId: activeLease.flatId,
        leaseStart: activeLease.leaseStart,
        leaseEnd: activeLease.leaseEnd,
        monthlyRent: activeLease.monthlyRent,
        advanceMonths: activeLease.advanceMonths,
        securityDeposit: activeLease.securityDeposit,
        moveOutDate: activeLease.moveOutDate,
        tenantName: t.name,
        tenantPhone: t.phone,
        flatNumber: activeLease.flatNumber ?? (flat?.flatNumber ?? ''),
        buildingName: activeLease.buildingName ?? (building?.buildingName ?? ''),
        buildingId: building?.id ?? activeLease.buildingId,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _editTenant(context, t),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: R.constrain(context, child: Column(children: [
          _infoCard('Personal Details', [
            _row('Phone', t.phone),
            if (t.phone2.isNotEmpty) _row('Phone 2', t.phone2),
            if (t.ksebNo.isNotEmpty) _row('KSEB No', t.ksebNo),
            _row('Address', t.address),
            if (t.idProof.isNotEmpty) _row('ID Proof', t.idProof),
          ]),
          const SizedBox(height: 12),
          _DocumentSection(tenant: t),
          if (activeLease != null) ..._buildLeaseSection(context, t, activeLease),
          if (leases.isNotEmpty) ...[
            const SizedBox(height: 16),
            _infoCard('Lease History', leases.map((l) {
              String flatLabel = l.flatNumber ?? '';
              String bldLabel = l.buildingName ?? '';
              if (flatLabel.isEmpty) {
                final flat = p.getFlat(l.flatId);
                if (flat != null) {
                  flatLabel = flat.flatNumber;
                  final bld = p.getBuilding(flat.buildingId);
                  bldLabel = bld?.buildingName ?? '';
                }
              }
              return ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text('${flatLabel.isNotEmpty ? flatLabel : '-'} · ${bldLabel.isNotEmpty ? bldLabel : '-'}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text('${l.leaseStart} -> ${l.leaseEnd} ${l.moveOutDate != null ? '(Moved out ${l.moveOutDate})' : '(Active)'}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              trailing: Text('${p.rentFor(l).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            );
            }).toList()),
          ],
          if (activeLease != null) ...[
            const SizedBox(height: 16),
            _infoCard('Payment History', [
              _PaymentHistory(leaseId: activeLease.id!),
            ]),
          ],
        ])),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 10),
          Divider(color: AppTheme.border.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          ...children,
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)), Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: valueColor ?? AppTheme.textPrimary))],
    ));
  }

  void _notify(BuildContext ctx, Tenant t, Lease lease) {
    final second = t.phone2.isNotEmpty;
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Notify Tenant'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _notifyTile(dCtx, ctx, t, lease, t.phone, second ? 'WhatsApp (${t.phone})' : 'WhatsApp', Icons.chat, AppTheme.success),
        if (second)
          _notifyTile(dCtx, ctx, t, lease, t.phone2, 'WhatsApp (${t.phone2})', Icons.chat, AppTheme.success),
        ListTile(
          leading: const Icon(Icons.phone, color: AppTheme.primary),
          title: const Text('Phone Call'),
          onTap: () { Navigator.pop(dCtx); WhatsAppHelper.callPhone(phone: t.phone); },
        ),
      ]),
    ));
  }

  Widget _notifyTile(BuildContext dCtx, BuildContext ctx, Tenant t, Lease lease, String phone, String label, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: () {
        Navigator.pop(dCtx);
        final p = ctx.read<AppProvider>();
        final dueSummary = p.dueSummary.firstWhere(
          (d) => d['tenantId'] == t.id,
          orElse: () => <String, dynamic>{},
        );
        final pendingAmt = (dueSummary['dueAmount'] as num?)?.toDouble();
        WhatsAppHelper.sendReminder(
          phone: phone,
          tenantName: t.name,
          rentAmount: p.rentFor(lease),
          dueDay: 5,
          flatNumber: lease.flatNumber,
          buildingName: lease.buildingName,
          pendingAmount: pendingAmt,
          leaseEnd: lease.leaseEnd,
        );
      },
    );
  }

  List<Widget> _buildLeaseSection(BuildContext ctx, Tenant t, Lease al) {
    final provider = ctx.read<AppProvider>();

    final dues = provider.computeLeaseDues(al);
    final pendingRent = dues.pendingRent;
    final advanceAmount = dues.advanceAmount;
    final monthlyRent = provider.rentFor(al);

    return [
      const SizedBox(height: 12),
      _infoCard('Current Lease', [
        _row('Flat', al.flatNumber ?? '-'),
        _row('Building', al.buildingName ?? '-'),
        _row('Monthly Rent', '\u{20B9}${monthlyRent.toStringAsFixed(0)}'),
        _row('Deposit', '\u{20B9}${al.securityDeposit.toStringAsFixed(0)}'),
        _row('Lease', '${al.leaseStart} -> ${al.leaseEnd}'),
        if (al.moveOutDate != null) _row('Move Out', al.moveOutDate!),
        Divider(color: AppTheme.border.withValues(alpha: 0.5)),
        _row('Pending Rent', '\u{20B9}${pendingRent.toStringAsFixed(0)}',
            valueColor: pendingRent > 0 ? AppTheme.danger : AppTheme.success),
        _row('Advance Credit', '\u{20B9}${advanceAmount.toStringAsFixed(0)}',
            valueColor: advanceAmount > 0 ? AppTheme.info : AppTheme.textSecondary),
      ]),
      if (t.amenities.isNotEmpty) ...[
        const SizedBox(height: 12),
        _infoCard('Amenities', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: t.amenities.map((a) {
              final name = a['name'] as String? ?? '';
              final count = a['count'] as int? ?? 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Text('$name × $count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              );
            }).toList(),
          ),
        ]),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CollectRentScreen(leaseId: al.id!, tenantName: t.name, flatNo: al.flatNumber ?? '', amount: monthlyRent))),
          icon: const Icon(Icons.payments, size: 18), label: const Text('Collect Rent'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          onPressed: () => _notify(ctx, t, al),
          icon: const Icon(Icons.notifications, size: 18), label: const Text('Notify'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning, side: const BorderSide(color: AppTheme.warning)),
        )),
      ]),
      if (al.moveOutDate == null) ...[
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => _moveOut(ctx, al, provider),
          icon: const Icon(Icons.exit_to_app, size: 18), label: const Text('Move Out'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
        )),
      ],
    ];
  }

  void _moveOut(BuildContext ctx, Lease lease, AppProvider p) {
    final tenant = p.getTenant(lease.tenantId);
    final hasAmenities = tenant != null && tenant.amenities.isNotEmpty;

    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Move Out'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Confirm move out for ${lease.tenantName} from Flat ${lease.flatNumber}?'),
          const SizedBox(height: 8),
          Text('Security Deposit: ₹${lease.securityDeposit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (hasAmenities) ...[
            const SizedBox(height: 12),
            const Text('Amenities to verify:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...tenant.amenities.map((a) {
              final name = a['name'] as String? ?? '';
              final count = a['count'] as int? ?? 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Text('$name × $count', style: const TextStyle(fontSize: 13)),
                ]),
              );
            }),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        LoadingButton(
          label: 'Confirm Move Out',
          icon: Icons.check_circle,
          backgroundColor: AppTheme.danger,
          expanded: false,
          onPressed: () async {
            await p.moveOut(lease.id!, DateTime.now().toIso8601String().split('T')[0]);
            final flat = p.getFlat(lease.flatId);
            if (flat != null) {
              await p.updateFlat(Flat(id: flat.id, buildingId: flat.buildingId, flatNumber: flat.flatNumber,
                  floor: flat.floor, monthlyRent: flat.monthlyRent, status: 'vacant'));
            }
            if (!dCtx.mounted) return;
            Navigator.pop(dCtx);
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Tenant moved out'), backgroundColor: AppTheme.success));
          },
        ),
      ],
    ));
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
}

class _DocumentSection extends StatelessWidget {
  final Tenant tenant;
  const _DocumentSection({required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DocumentsEditor(
          documents: tenant.documents,
          emptyText: 'No documents attached. Add ID proof, agreement or photos.',
          onChanged: (docs) {
            final updated = Tenant(
              id: tenant.id,
              name: tenant.name,
              phone: tenant.phone,
              phone2: tenant.phone2,
              ksebNo: tenant.ksebNo,
              address: tenant.address,
              idProof: tenant.idProof,
              documents: docs,
              amenities: tenant.amenities,
            );
            context.read<AppProvider>().updateTenant(updated);
          },
        ),
      ),
    );
  }
}

class _PaymentHistory extends StatefulWidget {
  final int leaseId;
  const _PaymentHistory({required this.leaseId});

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  Future<void> _shareReceiptAsWhatsApp(BuildContext ctx, dynamic pmt) async {
    final p = context.read<AppProvider>();
    final lease = p.leases.firstWhere(
      (l) => l.id == widget.leaseId,
      orElse: () => Lease(tenantId: 0, flatId: 0, leaseStart: '', leaseEnd: ''),
    );
    final tenant = p.tenants.firstWhere(
      (t) => t.id == lease.tenantId,
      orElse: () => Tenant(name: 'Tenant', phone: ''),
    );
    if (tenant.phone.isEmpty) return;

    final tenantName = tenant.name;
    final balance = pmt.amount - pmt.amountPaid;

    await WhatsAppHelper.sendPaymentReceipt(
      phone: tenant.phone,
      tenantName: tenantName,
      amountPaid: pmt.amountPaid,
      monthYear: '${pmt.month}/${pmt.year}',
      flatNumber: lease.flatNumber,
      buildingName: lease.buildingName,
      paymentMethod: pmt.paymentMethod,
      date: pmt.paymentDate,
      balance: balance > 0 ? balance : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final payments = p.getPaymentsByLease(widget.leaseId);
    if (payments.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('No payments yet', style: TextStyle(color: AppTheme.textSecondary)));
    return Column(children: payments.take(10).map((pmt) {
      final statusColor = pmt.status == 'paid' ? AppTheme.success : (pmt.status == 'partial' ? AppTheme.warning : AppTheme.warning);
      return ListTile(
        dense: true, contentPadding: EdgeInsets.zero,
        title: Text('₹${pmt.amountPaid.toStringAsFixed(0)} · ${pmt.month}/${pmt.year}', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(pmt.paymentMethod, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.share, size: 20, color: AppTheme.primary),
            onPressed: () => _shareReceiptAsWhatsApp(context, pmt),
          ),
          AppTheme.statusChip(pmt.status == 'paid' ? 'Paid' : (pmt.status == 'partial' ? 'Partial' : 'Pending'), statusColor),
        ]),
      );
    }).toList());
  }
}

