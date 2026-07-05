import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/services/notifications_repository.dart';

class NotificationBell extends StatelessWidget {
  final String userId;
  final Color iconColor;
  const NotificationBell({super.key, required this.userId, this.iconColor = AppColors.textOnDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: context.read<NotificationsRepository>().userNotifications(userId),
      builder: (context, snap) {
        final notifications = snap.data ?? const <AppNotification>[];
        final unreadCount = notifications.where((n) => !n.read).length;

        return InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showNotifications(context, notifications),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, size: 22, color: iconColor),
                if (unreadCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotifications(BuildContext context, List<AppNotification> notifications) {
    final repo = context.read<NotificationsRepository>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: notifications.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No notifications yet', textAlign: TextAlign.center),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = notifications[i];
                  return ListTile(
                    leading: Icon(
                      n.read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      color: n.read ? AppColors.textHint : AppColors.primary,
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700)),
                    subtitle: Text(n.message),
                    trailing: Text(
                      DateFormat('MMM d').format(n.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                    onTap: () {
                      if (!n.read) repo.markRead(n.id);
                      Navigator.pop(context);
                      if (n.bookingId != null) context.go('/bookings');
                    },
                  );
                },
              ),
      ),
    );
  }
}
