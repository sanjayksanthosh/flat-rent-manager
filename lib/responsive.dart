import 'package:flutter/material.dart';

class R {
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static double sw(BuildContext context) => MediaQuery.of(context).size.width;
  static double sh(BuildContext context) => MediaQuery.of(context).size.height;

  static double pad(BuildContext context, double phone, {double? tablet}) =>
      isTablet(context) ? (tablet ?? phone * 1.4) : phone;

  static double font(BuildContext context, double phone, {double? tablet}) =>
      isTablet(context) ? (tablet ?? phone * 1.15) : phone;

  static double icon(BuildContext context, double phone, {double? tablet}) =>
      isTablet(context) ? (tablet ?? phone * 1.2) : phone;

  static int gridCols(BuildContext context) {
    final w = sw(context);
    if (w >= 1200) return 6;
    if (w >= 900) return 5;
    if (w >= 600) return 4;
    return 4;
  }

  static double maxWidth(BuildContext context) {
    final w = sw(context);
    if (w >= 900) return 700;
    if (w >= 600) return 520;
    return w;
  }

  static double contentMaxWidth(BuildContext context) {
    final w = sw(context);
    if (w >= 1200) return 1000;
    if (w >= 900) return 800;
    if (w >= 600) return 600;
    return w;
  }

  static Widget constrain(BuildContext context, {required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
        child: child,
      ),
    );
  }

  static double sheetHeight(BuildContext context) {
    final h = sh(context);
    if (isTablet(context)) return h * 0.65;
    return h * 0.85;
  }
}
