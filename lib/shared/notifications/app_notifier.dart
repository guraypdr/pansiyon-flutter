import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

enum AppNotificationTone { error, success }

class AppNotifier {
  AppNotifier._();

  static final AppNotifier instance = AppNotifier._();

  final List<_PendingNotification> _pending = [];
  OverlayEntry? _entry;
  Timer? _timer;

  void show(
    BuildContext context, {
    required String message,
    required AppNotificationTone tone,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final notification = _PendingNotification(
      message: message,
      tone: tone,
      duration: duration,
      overlay: overlay,
      topPadding: topPadding,
    );

    if (_entry != null) {
      _pending.add(notification);
      return;
    }
    _display(notification);
  }

  void _display(_PendingNotification notification) {
    if (!notification.overlay.mounted) {
      _showNext();
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: notification.topPadding + 20,
          right: 20,
          width: 360,
          child: Material(
            color: AppColors.transparent,
            child: Semantics(
              liveRegion: true,
              label: notification.message,
              child: _AppNotificationCard(
                message: notification.message,
                tone: notification.tone,
                onClose: _completeCurrent,
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    notification.overlay.insert(entry);
    _timer = Timer(notification.duration, _completeCurrent);
  }

  void _completeCurrent() {
    _removeCurrent();
    _showNext();
  }

  void _showNext() {
    while (_pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      if (!next.overlay.mounted) {
        continue;
      }
      _display(next);
      return;
    }
  }

  void _removeCurrent() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  void hide() {
    _removeCurrent();
    _pending.clear();
  }
}

class _PendingNotification {
  const _PendingNotification({
    required this.message,
    required this.tone,
    required this.duration,
    required this.overlay,
    required this.topPadding,
  });

  final String message;
  final AppNotificationTone tone;
  final Duration duration;
  final OverlayState overlay;
  final double topPadding;
}

class _AppNotificationCard extends StatelessWidget {
  const _AppNotificationCard({
    required this.message,
    required this.tone,
    required this.onClose,
  });

  final String message;
  final AppNotificationTone tone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = tone == AppNotificationTone.error
        ? AppColors.errorFeedback
        : AppColors.successFeedback;
    final icon = tone == AppNotificationTone.error
        ? Icons.error_outline
        : Icons.check_circle_outline;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(16 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        key: const Key('app_notification'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.surface, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              key: const Key('app_notification_close'),
              tooltip: 'Bildirimi kapat',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.surface, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
