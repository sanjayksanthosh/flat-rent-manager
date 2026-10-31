import 'package:flutter/material.dart';

class LoadingButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final bool expanded;
  final OutlinedBorder? shape;

  const LoadingButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 52,
    this.expanded = true,
    this.shape,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _loading = false;

  Future<void> _handle() async {
    if (_loading || widget.onPressed == null) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final fg = widget.foregroundColor ?? Colors.white;
    final child = _loading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );

    return SizedBox(
      width: widget.expanded ? double.infinity : null,
      height: widget.height,
      child: ElevatedButton(
        onPressed: _loading ? null : widget.onPressed == null ? null : _handle,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          disabledForegroundColor: fg.withValues(alpha: 0.9),
          shape: widget.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: child,
      ),
    );
  }
}
