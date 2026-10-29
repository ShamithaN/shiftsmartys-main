//lib/screens/Notifications.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/notification.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<NotificationItem> allNotifications = [];
  List<int> unreadNotificationIds = [];
  bool isLoading = true;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    print('🔍 loadNotifications STARTED');
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('employeeId');

      if (employeeId == null) {
        throw Exception("Employee ID not found in SharedPreferences");
      }

      // Fetch read and unread notifications separately
      final readNotifications =
          await _notificationService.fetchNotificationsread(employeeId);
      final unreadNotifications =
          await _notificationService.fetchNotificationsUnread(employeeId);

      // Store unread IDs for marking later
      unreadNotificationIds = unreadNotifications.map((n) => n.id).toList();

      final result = [...readNotifications, ...unreadNotifications];

      debugPrint('🔔 Notifications fetched: ${result.length}');

      setState(() {
        allNotifications = result;
        isLoading = false;
      });
    } catch (e, stack) {
      debugPrint("❌ Error loading notifications: $e");
      debugPrint(stack.toString());
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAllUnreadAsRead() async {
    try {
      if (unreadNotificationIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No unread notifications.")),
        );
        return;
      }

      await _notificationService.markAsRead(unreadNotificationIds);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked unread notifications as read.")),
      );

      // Refresh after marking
      loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as read: $e")),
      );
    }
  }

  Map<String, List<NotificationItem>> groupNotifications(
      List<NotificationItem> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<NotificationItem>>{
      'New': [],
      'Earlier Today': [],
      'Yesterday': [],
      'Older': [],
    };

    for (var notif in all) {
      final notifDate = notif.createdAt;
      final difference = now.difference(notifDate);

      if (difference.inMinutes < 60) {
        grouped['New']!.add(notif);
      } else if (notifDate.isAfter(today)) {
        grouped['Earlier Today']!.add(notif);
      } else if (notifDate.isAfter(yesterday)) {
        grouped['Yesterday']!.add(notif);
      } else {
        grouped['Older']!.add(notif);
      }
    }

    return grouped;
  }

  List<Widget> buildGroupedNotifications(
      Map<String, List<NotificationItem>> grouped) {
    final widgets = <Widget>[];

    grouped.forEach((section, notifications) {
      if (notifications.isEmpty) return;

      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Text(
          section,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));

      for (var notif in notifications) {
        final isUnread =
            unreadNotificationIds.contains(notif.id); // 💡 check if unread

        widgets.add(Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          color: Colors.transparent,
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUnread
                    ? [
                        const Color.fromARGB(
                            200, 60, 70, 90), // Lighter for unread
                        const Color.fromARGB(200, 40, 50, 70),
                      ]
                    : [
                        const Color.fromARGB(180, 42, 50, 67),
                        const Color.fromARGB(180, 34, 40, 52),
                      ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.white),
              title: Text(
                notif.subject,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                notif.message,
                style: TextStyle(
                  color: isUnread ? Colors.white70 : Colors.grey,
                ),
              ),
            ),
          ),
        ));
      }
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupNotifications(allNotifications);

    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(showBackButton: false),
      body: Stack(
        children: [
          Background(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : allNotifications.isEmpty
                  ? const Center(
                      child: Text(
                        "No notifications to display.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18, // Larger font size
                            fontWeight: FontWeight.w600, // Optional: medium bold
                          ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🟦 Title + Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Notifications",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: _markAllUnreadAsRead,
                                child: const Text(
                                  "Mark all as read",
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...buildGroupedNotifications(grouped),
                        ],
                      ),
                    ),
        ],
      ),
    );
  }
}
