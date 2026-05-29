import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../utils/app_colors.dart';

/// Shows a slide-in notification banner at the TOP of the screen.
/// Auto-dismisses after [duration] (default 5 s). Tap to dismiss early.
class AppNotification {
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    final colors = AppColors.of(context);
    backgroundColor ??= colors.surface;
    textColor ??= colors.textDark;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(
        message: message,
        backgroundColor: backgroundColor!,
        textColor: textColor!,
        icon: icon,
        iconColor: iconColor ?? textColor!,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismiss: () { if (entry.mounted) entry.remove(); },
      ),
    );
    overlay.insert(entry);
  }

  static void error(BuildContext context, String message) => show(
    context,
    message: message,
    backgroundColor: AppTheme.error,
    textColor: Colors.white,
    icon: Icons.error_outline,
  );

  static void success(BuildContext context, String message) => show(
    context,
    message: message,
    backgroundColor: AppTheme.success,
    textColor: Colors.white,
    icon: Icons.check_circle_outline,
  );

  static void primary(
    BuildContext context,
    String message, {
    IconData icon = Icons.favorite,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message: message,
        backgroundColor: AppTheme.primary,
        textColor: Colors.white,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        context,
        message: message,
        backgroundColor: AppColors.of(context).surface,
        textColor: AppColors.of(context).textDark,
        icon: Icons.info_outline,
        iconColor: AppTheme.primary,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

// ── Internal toast widget ────────────────────────────────────────────────────

class _Toast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _Toast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              color: widget.iconColor, size: 19),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              widget.onAction?.call();
                              _dismiss();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
