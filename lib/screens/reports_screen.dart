import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/flat_model.dart';
import '../providers/app_provider.dart';
import '../services/whatsapp_helper.dart';
import '../theme.dart';
import '../responsive.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int? _buildingId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _reportData = [];
  bool _loading = false;
  bool _showVacant = false;
  int _lastDataVersion = -1;
  bool _initialLoadDone = false;
  Timer? _searchDebounce;

  int _lastPaymentsLength = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _buildingId = null);
      _lastPaymentsLength = context.read<AppProvider>().payments.length;
      _loadReport().then((_) { if (mounted) _initialLoadDone = true; });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<AppProvider>();
    final currentLength = p.payments.length;
    if (_initialLoadDone && currentLength != _lastPaymentsLength) {
      _lastPaymentsLength = currentLength;
      _loadReport();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    var buildingFlats = p.flats;
    if (_buildingId != null) buildingFlats = buildingFlats.where((f) => f.buildingId == _buildingId).toList();
    final month = _month;
    final year = _year;
    final search = _searchCtrl.text.trim().toLowerCase();
    final status = _statusFilter;
    final rows = <Map<String, dynamic>>[];
    for (var flat in buildingFlats) {
      final flatNumber = flat.flatNumber;
      if (search.isNotEmpty && !flatNumber.toLowerCase().contains(search)) continue;
      final flatLeases = p.getLeasesByFlat(flat.id!);
      Lease? leaseForMonth;
      for (var l in flatLeases) {
        final startParts = l.leaseStart.split('-');
        if (startParts.length < 3) continue;
        final startY = int.tryParse(startParts[0]) ?? 0;
        final startM = int.tryParse(startParts[1]) ?? 0;
        if (startY > year || (startY == year && startM > month)) continue;
        final endStr = l.moveOutDate ?? l.leaseEnd;
        final endParts = endStr.split('-');
        if (endParts.length >= 3) {
          final endY = int.tryParse(endParts[0]) ?? 9999;
          final endM = int.tryParse(endParts[1]) ?? 9999;
          if (endY < year || (endY == year && endM < month)) continue;
        }
        leaseForMonth = l;
        break;
      }
      if (leaseForMonth == null) {
        if (!_showVacant) continue;
      }
      final tenant = leaseForMonth != null ? p.getTenant(leaseForMonth.tenantId) : null;
      final tenantName = tenant?.name ?? leaseForMonth?.tenantName ?? '';
      if (search.isNotEmpty && !tenantName.toLowerCase().contains(search)) continue;
      final monthlyRent = leaseForMonth != null ? p.rentFor(leaseForMonth) : flat.monthlyRent;
      final leasePayments = leaseForMonth != null ? p.getPaymentsByLease(leaseForMonth.id!) : const <RentPayment>[];
      double allocatedAmount = 0;
      double outstanding = 0;
      String st;
      if (tenantName.isEmpty || leaseForMonth == null) {
        st = 'vacant';
      } else {
        final sp = leaseForMonth.leaseStart.split('-');
        final sy = sp.length >= 3 ? int.tryParse(sp[0]) ?? year : year;
        final sm = sp.length >= 2 ? int.tryParse(sp[1]) ?? month : month;
        final monthsCount = (year - sy) * 12 + (month - sm) + 1;
        final count = monthsCount > 0 ? monthsCount : 0;

        double discountsThroughMonth = 0;
        double discountsBeforeMonth = 0;
        double discountThisMonth = 0;
        double totalPaid = 0;
        for (final pmt in leasePayments) {
          totalPaid += pmt.amountPaid;
          final pmtIndex = (pmt.year - sy) * 12 + (pmt.month - sm) + 1;
          if (pmtIndex <= count) discountsThroughMonth += pmt.discount;
          if (pmtIndex < count) discountsBeforeMonth += pmt.discount;
          if (pmt.year == year && pmt.month == month) discountThisMonth += pmt.discount;
        }

        // Rent owed from the start of the lease through the report month.
        final rentDue = monthlyRent * count - discountsThroughMonth;
        final rentDueBefore = monthlyRent * (count > 0 ? count - 1 : 0) - discountsBeforeMonth;

        // Every payment counts as credit, including advance payments made
        // before the lease started or for future months.
        final creditBefore = totalPaid - rentDueBefore;
        allocatedAmount = creditBefore.clamp(0, monthlyRent).toDouble();
        outstanding = (monthlyRent - discountThisMonth - allocatedAmount).clamp(0, double.infinity).toDouble();

        final creditAfter = totalPaid - rentDue;
        if (creditAfter > 0.5) {
          st = 'advance_paid';
        } else if (creditAfter >= -0.5) {
          st = 'paid';
        } else if (allocatedAmount > 0.5) {
          st = 'partial';
        } else {
          st = 'pending';
        }
      }
      if (status != 'all' && status != st) continue;
      rows.add({
        'flatNumber': flatNumber,
        'tenantName': tenantName,
        'tenantPhone': tenant?.phone ?? leaseForMonth?.tenantPhone,
        'status': st,
        'monthlyRent': monthlyRent,
        'allocatedAmount': allocatedAmount,
        'outstanding': outstanding,
        'leaseStart': leaseForMonth?.leaseStart,
        'leaseEnd': leaseForMonth?.leaseEnd,
        'leaseId': leaseForMonth?.id,
      });
    }
    if (mounted) setState(() { _reportData = rows; _loading = false; });
  }

  String _buildingName(AppProvider p) {
    if (_buildingId == null) return 'All Buildings';
    final b = p.buildings.firstWhere((b) => b.id == _buildingId, orElse: () => Building(buildingName: ''));
    return b.buildingName;
  }

  int get _totalFlats => _reportData.length;
  int get _occupiedFlats => _reportData.where((r) => r['tenantName'] != null).length;
  int get _vacantFlats => _reportData.where((r) => r['tenantName'] == null).length;
  int get _paidFlats => _reportData.where((r) => r['status'] == 'paid' || r['status'] == 'advance_paid').length;
  int get _pendingFlats => _reportData.where((r) => r['status'] == 'pending').length;
  int get _partialFlats => _reportData.where((r) => r['status'] == 'partial').length;
  int get _advancePaidFlats => _reportData.where((r) => r['status'] == 'advance_paid').length;
  double get _totalRentExpected => _reportData.fold<double>(0, (s, r) => s + ((r['monthlyRent'] as num?)?.toDouble() ?? 0));
  double get _totalCollected => _reportData.fold<double>(0, (s, r) => s + ((r['allocatedAmount'] as num?)?.toDouble() ?? 0));
  double get _totalOutstanding => _reportData.fold<double>(0, (s, r) => s + ((r['outstanding'] as num?)?.toDouble() ?? 0));

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return AppTheme.success;
      case 'advance_paid': return Colors.blue;
      case 'partial': return AppTheme.warning;
      case 'pending': return AppTheme.warning;
      default: return AppTheme.danger;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Paid';
      case 'advance_paid': return 'Advance Paid';
      case 'partial': return 'Partial';
      case 'pending': return 'Pending';
      default: return 'Pending';
    }
  }

  List<List<String>> _csvRows() {
    final rows = <List<String>>[['Flat No', 'Tenant Name', 'Status', 'Monthly Rent', 'Amount Paid', 'Outstanding', 'Lease End Date']];
    for (var r in _reportData) {
      rows.add([
        r['flatNumber']?.toString() ?? '',
        r['tenantName']?.toString() ?? 'Vacant',
        _statusLabel(r['status']?.toString() ?? 'pending'),
        ((r['monthlyRent'] as num?)?.toDouble() ?? 0).toString(),
        ((r['allocatedAmount'] as num?)?.toDouble() ?? 0).toString(),
        ((r['outstanding'] as num?)?.toDouble() ?? 0).toString(),
        r['leaseEnd']?.toString() ?? '-',
      ]);
    }
    return rows;
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final name = _buildingName(context.read<AppProvider>());
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(text: 'Monthly Report - $name $_month/$_year'),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          data: _csvRows(),
        ),
        pw.SizedBox(height: 16),
        pw.Paragraph(text: 'Summary: Total: $_totalFlats, Occupied: $_occupiedFlats, Vacant: $_vacantFlats'),
        pw.Paragraph(text: 'Paid: $_paidFlats, Pending: $_pendingFlats, Partial: $_partialFlats, Advance Paid: $_advancePaidFlats'),
        pw.Paragraph(text: 'Expected: Rs.${_totalRentExpected.toStringAsFixed(0)}, Collected: Rs.${_totalCollected.toStringAsFixed(0)}, Outstanding: Rs.${_totalOutstanding.toStringAsFixed(0)}'),
      ],
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'monthly_report_$name$_month-$_year.pdf');
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];
    final rows = _csvRows();
    for (var data in rows) {
      sheet.appendRow(data.map((s) => TextCellValue(s) as CellValue?).toList());
    }
    final fileBytes = excel.save();
    if (fileBytes == null) return;
    final name = 'monthly_report_$_month-$_year.xlsx';
    if (kIsWeb) {
      await Share.shareXFiles([XFile.fromData(Uint8List.fromList(fileBytes), mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: name)], text: 'Monthly Report');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Report');
    }
  }

  Future<void> _exportCsv() async {
    final rows = _csvRows();
    final csv = const ListToCsvConverter().convert(rows);
    final name = 'monthly_report_$_month-$_year.csv';
    if (kIsWeb) {
      await Share.shareXFiles([XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name)], text: 'Monthly Report');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Report');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final currentVersion = p.buildings.length + p.flats.length + p.tenants.length + p.leases.length + p.payments.length;
    if (currentVersion != _lastDataVersion && !_loading && _initialLoadDone) {
      _lastDataVersion = currentVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadReport(); });
    } else if (currentVersion != _lastDataVersion) {
      _lastDataVersion = currentVersion;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
        actions: [
          if (_reportData.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              onSelected: (v) {
                switch (v) {
                  case 'pdf':
                    _exportPdf();
                    break;
                  case 'xlsx':
                    _exportExcel();
                    break;
                  case 'csv':
                    _exportCsv();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('PDF'), dense: true)),
                PopupMenuItem(value: 'xlsx', child: ListTile(leading: Icon(Icons.table_chart), title: Text('Excel'), dense: true)),
                PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.text_snippet), title: Text('CSV'), dense: true)),
              ],
            ),
        ],
      ),
      body: R.constrain(context, child: Column(children: [
        FiltersSection(
          buildingId: _buildingId,
          buildings: p.buildings,
          month: _month,
          year: _year,
          statusFilter: _statusFilter,
          searchCtrl: _searchCtrl,
          showVacant: _showVacant,
          onBuildingChanged: (v) {
            setState(() => _buildingId = v);
            _loadReport();
          },
          onMonthChanged: (v) {
            setState(() => _month = v!);
            _loadReport();
          },
          onYearChanged: (v) {
            setState(() => _year = v!);
            _loadReport();
          },
          onStatusChanged: (v) {
            setState(() => _statusFilter = v!);
            _loadReport();
          },
          onSearchChanged: () {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 250), () {
              if (mounted) _loadReport();
            });
          },
          onShowVacantChanged: (v) {
            setState(() => _showVacant = v);
            _loadReport();
          },
        ),
        if (_reportData.isNotEmpty)
          SizedBox(
            height: 52,
            child: SummaryBar(
              totalFlats: _totalFlats,
              occupiedFlats: _occupiedFlats,
              vacantFlats: _vacantFlats,
              paidFlats: _paidFlats,
              pendingFlats: _pendingFlats,
              partialFlats: _partialFlats,
              advancePaidFlats: _advancePaidFlats,
              totalRentExpected: _totalRentExpected,
              totalCollected: _totalCollected,
              totalOutstanding: _totalOutstanding,
            ),
          ),
        if (_loading && _reportData.isNotEmpty)
          const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2)),
        const Divider(height: 1),
        Expanded(
          child: _loading && _reportData.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _reportData.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline, size: 64, color: AppTheme.textSecondary),
                              SizedBox(height: 16),
                              Text(
                                'No rent records found for selected month',
                                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReport,
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ReportDataTable(
                                reportData: _reportData,
                                month: _month,
                                year: _year,
                                onViewFlat: _viewFlat,
                                onViewPayments: _viewPayments,
                                onShareReceipt: (r) => _shareReceipt(r),
                              ),
                            ),
                          ),
                        ),
        )
      ])),
    );
  }

  void _viewFlat(BuildContext ctx, Map<String, dynamic> r) {
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: Text('Flat ${r['flatNumber']}'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Tenant: ${r['tenantName'] ?? 'Vacant'}'),
                Text('Rent: ₹${((r['monthlyRent'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                Text('Lease: ${r['leaseStart'] ?? '-'} → ${r['leaseEnd'] ?? '-'}'),
              ]),
            ));
  }

  void _viewPayments(BuildContext ctx, Map<String, dynamic> r) {
    final leaseId = r['leaseId'] as int?;
    if (leaseId == null) return;
    final p = ctx.read<AppProvider>();
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: Text('Payments - ${r['flatNumber']}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: p
                      .getPaymentsByLease(leaseId)
                      .map((pmt) => ListTile(
                            dense: true,
                            title: Text('₹${pmt.amountPaid.toStringAsFixed(0)} · ${pmt.month}/${pmt.year}'),
                            subtitle: Text(pmt.paymentMethod),
                            trailing: AppTheme.statusChip(pmt.status, _statusColor(pmt.status)),
                          ))
                      .toList(),
                ),
              ),
            ));
  }

  Future<void> _shareReceipt(Map<String, dynamic> r) async {
    final tenantName = r['tenantName']?.toString() ?? '';
    final flatNumber = r['flatNumber']?.toString() ?? '';
    final phone = r['tenantPhone']?.toString() ?? '';
    final allocatedAmount = (r['allocatedAmount'] as num?)?.toDouble() ?? 0;
    final monthlyRent = (r['monthlyRent'] as num?)?.toDouble() ?? 0;
    if (phone.isNotEmpty) {
      WhatsAppHelper.sendPaymentReceipt(
        phone: phone,
        tenantName: tenantName,
        amountPaid: allocatedAmount,
        monthYear: '$_month/$_year',
        flatNumber: flatNumber,
        buildingName: null,
        paymentMethod: null,
        date: DateTime.now().toIso8601String().split('T')[0],
        balance: monthlyRent - allocatedAmount,
      );
    }
  }
}

// --- Filter Section ---
class FiltersSection extends StatelessWidget {
  final int? buildingId;
  final List<Building> buildings;
  final int month;
  final int year;
  final String statusFilter;
  final TextEditingController searchCtrl;
  final bool showVacant;
  final ValueChanged<int?> onBuildingChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<bool> onShowVacantChanged;

  const FiltersSection({
    super.key,
    this.buildingId,
    required this.buildings,
    required this.month,
    required this.year,
    required this.statusFilter,
    required this.searchCtrl,
    required this.showVacant,
    required this.onBuildingChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onShowVacantChanged,
  });

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: buildingId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Building',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('All Buildings',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13))),
                ...buildings
                    .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.buildingName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13)))),
              ],
              onChanged: onBuildingChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: month,
              decoration: const InputDecoration(
                  labelText: 'Month',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: List.generate(12, (i) => i + 1)
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(_monthName(m),
                          style: TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onMonthChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(
                  labelText: 'Year',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: List.generate(10, (i) => DateTime.now().year - 2 + i)
                  .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y', style: TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onYearChanged,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
            value: statusFilter,
            decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            items: const [
              DropdownMenuItem(
                  value: 'all', child: Text('All', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: 'paid', child: Text('Paid', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: 'pending',
                  child: Text('Pending', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: 'partial',
                  child: Text('Partial', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(
                  value: 'advance_paid',
                  child: Text('Advance Paid', style: TextStyle(fontSize: 13))),
            ],
            onChanged: onStatusChanged,
          ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                  labelText: 'Search flat/tenant',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: Icon(Icons.search, size: 20)),
              onChanged: (_) => onSearchChanged(),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => onShowVacantChanged(!showVacant),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: showVacant ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: showVacant ? AppTheme.primary : AppTheme.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility, size: 16, color: showVacant ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('Vacant', style: TextStyle(fontSize: 11, color: showVacant ? AppTheme.primary : AppTheme.textSecondary)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

// Summary bar
class SummaryBar extends StatelessWidget {
  final int totalFlats, occupiedFlats, vacantFlats, paidFlats, pendingFlats,
      partialFlats, advancePaidFlats;
  final double totalRentExpected, totalCollected, totalOutstanding;

  const SummaryBar({
    super.key,
    required this.totalFlats,
    required this.occupiedFlats,
    required this.vacantFlats,
    required this.paidFlats,
    required this.pendingFlats,
    required this.partialFlats,
    required this.advancePaidFlats,
    required this.totalRentExpected,
    required this.totalCollected,
    required this.totalOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _miniCard('Total', '$totalFlats', AppTheme.primary),
          _miniCard('Occupied', '$occupiedFlats', AppTheme.success),
          _miniCard('Vacant', '$vacantFlats', AppTheme.warning),
          _miniCard('Paid', '$paidFlats', AppTheme.success),
          _miniCard('Pending', '$pendingFlats', AppTheme.warning),
          _miniCard('Partial', '$partialFlats', AppTheme.warning),
          _miniCard('Advance', '$advancePaidFlats', Colors.blue),
          _miniCard('Expected', '₹${totalRentExpected.toStringAsFixed(0)}',
              AppTheme.primary),
          _miniCard('Collected', '₹${totalCollected.toStringAsFixed(0)}',
              AppTheme.accent),
          _miniCard('Outstanding', '₹${totalOutstanding.toStringAsFixed(0)}',
              AppTheme.danger),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color.withValues(alpha: 0.8))),
          ]),
    );
  }
}

// Report data table
class ReportDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final int month;
  final int year;
  final Function(BuildContext, Map<String, dynamic>) onViewFlat;
  final Function(BuildContext, Map<String, dynamic>) onViewPayments;
  final Function(Map<String, dynamic>) onShareReceipt;

  const ReportDataTable({
    super.key,
    required this.reportData,
    required this.month,
    required this.year,
    required this.onViewFlat,
    required this.onViewPayments,
    required this.onShareReceipt,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return AppTheme.success;
      case 'advance_paid': return Colors.blue;
      case 'partial': return AppTheme.warning;
      case 'pending': return AppTheme.warning;
      default: return AppTheme.danger;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Paid';
      case 'advance_paid': return 'Advance Paid';
      case 'partial': return 'Partial';
      case 'pending': return 'Pending';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor:
          WidgetStateProperty.all(AppTheme.primary.withValues(alpha: 0.08)),
      columnSpacing: 16,
      columns: const [
        DataColumn(
            label: Text('Flat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Tenant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Rent',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Paid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        DataColumn(
            label: Text('Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      ],
      rows: reportData.map((r) {
        final status = r['status'] as String? ?? 'pending';
        final sColor = _statusColor(status);
        return DataRow(cells: [
          DataCell(Text(r['flatNumber']?.toString() ?? '',
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          DataCell(Text(r['tenantName']?.toString() ?? 'Vacant',
              style: TextStyle(
                  fontSize: 13,
                  color: r['tenantName'] == null
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary))),
          DataCell(AppTheme.statusChip(_statusLabel(status), sColor)),
          DataCell(Text(
              '₹${((r['monthlyRent'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13))),
          DataCell(Text(
              '₹${((r['allocatedAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13))),
          DataCell(Text(
              '₹${((r['outstanding'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ((r['outstanding'] as num?)?.toDouble() ?? 0) > 0
                      ? AppTheme.danger
                      : AppTheme.textPrimary))),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            _actionIcon(Icons.visibility, 'View',
                () => onViewFlat(context, r)),
            _actionIcon(Icons.history, 'Payments',
                () => onViewPayments(context, r)),
            if (status == 'paid' || status == 'advance_paid')
              _actionIcon(Icons.share, 'Share Receipt',
                  () => onShareReceipt(r)),
          ])),
        ]);
      }).toList(),
    );
  }

  Widget _actionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
      ),
    );
  }
}
