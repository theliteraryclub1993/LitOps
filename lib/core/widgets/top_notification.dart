import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common_widgets.dart';

enum NotificationType { success, error, warning, info }

class NotificationData {
  final String id;
  final String message;
  final NotificationType type;
  final Duration duration;

  NotificationData({
    required this.id,
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 3),
  });
}

// Provider to manage notifications
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationData>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<List<NotificationData>> {
  NotificationsNotifier() : super([]);

  void showNotification({
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      duration: duration,
    );
    state = [...state, notification];
  }

  void hideNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

// Helper function to show notifications easily
void showTopNotification(
  BuildContext context,
  String message, {
  NotificationType type = NotificationType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(notificationsProvider.notifier).showNotification(
        message: message,
        type: type,
        duration: duration,
      );
}

class TopNotificationWidget extends ConsumerWidget {
  const TopNotificationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          children: notifications.map((notification) {
            return NotificationItem(
              key: Key(notification.id),
              notification: notification,
              onDismiss: () => ref.read(notificationsProvider.notifier).hideNotification(notification.id),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class NotificationItem extends StatefulWidget {
  final NotificationData notification;
  final VoidCallback onDismiss;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    if (widget.notification.duration.inMilliseconds > 0) {
      _timer = Timer(widget.notification.duration, () {
        if (mounted) _dismiss();
      });
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return LitColors.moss.withValues(alpha: 0.95);
      case NotificationType.error:
        return LitColors.coral.withValues(alpha: 0.95);
      case NotificationType.warning:
        return LitColors.amber.withValues(alpha: 0.95);
      case NotificationType.info:
        return LitColors.clay3.withValues(alpha: 0.95);
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_outline_rounded;
      case NotificationType.error:
        return Icons.error_outline_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(widget.notification.type),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _getIcon(widget.notification.type),
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.notification.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismiss,
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
