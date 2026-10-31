import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

class WhatsAppHelper {
  /// Rent reminder message (Notify button)
  static Future<void> sendReminder({
    required String phone,
    required String tenantName,
    required double rentAmount,
    int? dueDay,
    String? flatNumber,
    String? buildingName,
    double? pendingAmount,
    String? leaseEnd,
  }) async {
    final now = DateTime.now();
    String message = '\u{1F3E0} *RENT REMINDER*\n'
        '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Tenant: $tenantName\n'
        'Flat: ${flatNumber ?? ''}${buildingName != null ? ', $buildingName' : ''}\n'
        '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Monthly Rent: \u{20B9}${rentAmount.toStringAsFixed(0)}\n';

    if (dueDay != null) {
      final dueDateThisMonth = DateTime(now.year, now.month, dueDay);
      final diff = dueDateThisMonth.difference(now).inDays;
      message += 'Due Date: ${dueDay}th of every month\n';
      if (diff > 0) {
        message += 'Status: \u{23F0} Due in $diff day(s)\n';
      } else if (diff == 0) {
        message += 'Status: \u{26A0}\u{FE0F} Due TODAY\n';
      } else {
        message += 'Status: \u{274C} Overdue by ${-diff} day(s)\n';
      }
    }

    if (pendingAmount != null && pendingAmount > 0) {
      message += 'Pending Amount: \u{20B9}${pendingAmount.toStringAsFixed(0)}\n';
    }

    if (leaseEnd != null) {
      message += 'Lease Ends: $leaseEnd\n';
    }

    message += '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Please make the payment at the earliest.\n'
        'Thank you! \u{1F64F}';

    _launchWhatsApp(phone, message);
  }

  /// Payment receipt message (after rent is collected)
  static Future<void> sendPaymentReceipt({
    required String phone,
    required String tenantName,
    required double amountPaid,
    required String monthYear,
    String? flatNumber,
    String? buildingName,
    String? paymentMethod,
    String? date,
    double? balance,
  }) async {
    String message = '\u{2705} *PAYMENT RECEIVED*\n'
        '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Tenant: $tenantName\n'
        'Flat: ${flatNumber ?? ''}${buildingName != null ? ', $buildingName' : ''}\n'
        '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Amount Paid: \u{20B9}${amountPaid.toStringAsFixed(0)}\n'
        'Period: $monthYear\n';

    if (paymentMethod != null) {
      message += 'Method: $paymentMethod\n';
    }
    if (date != null) {
      message += 'Date: $date\n';
    }
    if (balance != null && balance > 0) {
      message += 'Balance Due: \u{20B9}${balance.toStringAsFixed(0)}\n';
    } else if (balance != null && balance <= 0) {
      message += '\u{2705} Fully Paid\n';
    }

    message += '\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\n'
        'Thank you for the payment! \u{1F389}';

    _launchWhatsApp(phone, message);
  }

  static Future<void> callPhone({required String phone}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'tel:+91$cleanPhone';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static Future<void> _launchWhatsApp(String phone, String message) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final urls = [
      'whatsapp://send?phone=91$cleanPhone&text=${Uri.encodeComponent(message)}',
      'https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(message)}',
    ];
    for (final urlStr in urls) {
      try {
        await launchUrl(Uri.parse(urlStr), mode: LaunchMode.externalApplication);
        break;
      } catch (_) {}
    }
  }
}
