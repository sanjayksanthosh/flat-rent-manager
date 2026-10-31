import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../responsive.dart';
import '../theme.dart';
import '../services/whatsapp_helper.dart';
import 'collect_rent_screen.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: p.loading && p.payments.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : p.payments.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.payments_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16), Text('No payments yet', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
              ]))
            : RefreshIndicator(
                onRefresh: () => p.loadAll(),
                child: R.constrain(context, child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: p.payments.length,
                  itemBuilder: (_, i) {
                    final payment = p.payments[i];
                    final statusColor = payment.status == 'paid' ? AppTheme.success : (payment.status == 'partial' ? AppTheme.warning : AppTheme.warning);
                    final lease = p.getLease(payment.leaseId);
                    final tenant = lease != null ? p.getTenant(lease.tenantId) : null;
                    final tenantName = tenant?.name ?? payment.tenantName ?? 'Tenant';
                    final flatFromPayment = lease != null && lease.flatId != 0 ? p.getFlat(lease.flatId) : null;
                    final flatNo = payment.flatNumber ?? lease?.flatNumber ?? flatFromPayment?.flatNumber ?? '';
                    final bldName = payment.buildingName ?? lease?.buildingName ?? '';
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.payments, color: statusColor, size: 22),
                        ),
                        title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Flat $flatNo · ${bldName.isNotEmpty ? "$bldName · " : ""}${payment.month}/${payment.year}',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.share, size: 20, color: AppTheme.primary),
                            tooltip: 'Share Receipt',
                            onPressed: () async {
                              final phone = tenant?.phone ?? lease?.tenantPhone ?? '';
                              if (phone.isNotEmpty) {
                                await WhatsAppHelper.sendPaymentReceipt(
                                  phone: phone,
                                  tenantName: tenantName,
                                  amountPaid: payment.amountPaid,
                                  monthYear: '${payment.month}/${payment.year}',
                                  flatNumber: flatNo,
                                  buildingName: bldName.isNotEmpty ? bldName : null,
                                  paymentMethod: payment.paymentMethod,
                                  date: payment.paymentDate,
                                  balance: payment.balance > 0 ? payment.balance : null,
                                );
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No phone number for this tenant')),
                                  );
                                }
                              }
                            },
                          ),
                          AppTheme.statusChip(payment.status == 'paid' ? 'Paid' : (payment.status == 'partial' ? 'Partial' : 'Pending'), statusColor),
                        ]),
                      ),
                    );
                  },
                )),
              ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'collect_rent_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectRentScreen())),
        backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Collect Rent'),
      ),
    );
  }
}
