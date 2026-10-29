// import 'dart:convert';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:intl/intl.dart';
// import 'package:shiftsmart/models/notification.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'api_client.dart';

// class NotificationService {
//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   final ApiClient _apiClient = ApiClient();

//   // Safely get Base URL
//   String get baseUrl => dotenv.env['NOTIFI_BASE_URL'] ?? '';

//   // --- SAFE KEYS (Use getters so app doesn't crash on load) ---
//   String get mainKey => dotenv.env['NOTIFI_MAIN_KEY'] ?? '';
//   String get registerKey => dotenv.env['NOTIFI_REGISTER_KEY'] ?? '';
//   String get markReadKey => dotenv.env['NOTIFI_MARK_READ_KEY'] ?? '';

//   // Note: We use separate keys for Request vs Approval
//   String get leaveApprovalKey => dotenv.env['NOTIFI_LEAVE_APPROVAL_KEY'] ?? '';
//   String get leaveRequestKey => dotenv.env['NOTIFI_LEAVE_REQUEST_KEY'] ?? '';

//   String get shiftKey => dotenv.env['NOTIFI_SHIFT_KEY'] ?? '';
//   String get shiftCompleteKey => dotenv.env['NOTIFI_SHIFT_COMPLETE_KEY'] ?? '';

//   // ---------------- Initialize FCM ------------------
//   Future<void> initializeFCM({
//     required int employeeId,
//     required String userTag,
//     void Function(RemoteMessage)? onForegroundMessage,
//     void Function(RemoteMessage)? onNotificationOpenedApp,
//   }) async {
//     try {
//       await _firebaseMessaging.requestPermission();
//       final token = await _firebaseMessaging.getToken();

//       if (token != null) {
//         await registerDeviceTokenToBackend(
//           token: token,
//           employeeId: employeeId,
//           tag: userTag,
//         );
//       }

//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         debugPrint("🚨 Foreground message: ${message.notification?.title}");
//         if (onForegroundMessage != null) onForegroundMessage(message);
//       });

//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         debugPrint("📲 Notification tapped");
//         if (onNotificationOpenedApp != null) onNotificationOpenedApp(message);
//       });

//       FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
//     } catch (e) {
//       debugPrint("❌ FCM Initialization error: $e");
//     }
//   }

//   // ---------------- Register Device ------------------
//   Future<void> registerDeviceTokenToBackend({
//     required String token,
//     required int employeeId,
//     required String tag,
//   }) async {
//     if (registerKey.isEmpty) {
//       debugPrint("❌ Missing NOTIFI_REGISTER_KEY");
//       return;
//     }

//     String url = '$baseUrl/RegisterDevice?code=$registerKey';
//     final body = {
//       "EmployeeId": employeeId,
//       "DeviceToken": token,
//       "Tag": tag,
//     };

//     try {
//       final response = await _apiClient.post(url, body: body, useAuth: true);
//       if (response.statusCode == 200) {
//         debugPrint("✅ Device registered");
//       } else {
//         debugPrint("❌ Register failed: ${response.statusCode}");
//       }
//     } catch (e) {
//       debugPrint("❌ Device registration error: $e");
//     }
//   }

//   // ---------------- Fetch Read Notifications ------------------
//   Future<List<NotificationItem>> fetchNotificationsread(int employeeId) async {
//     if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

//     final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
//       'code': mainKey,
//       'employeeId': employeeId.toString(),
//       'status': 'read',
//     });

//     final response = await _apiClient.get(uri.toString(), useAuth: true);

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final notifications = data['notifications'];
//       List<NotificationItem> items = [];
//       for (var n in notifications) {
//         items.add(NotificationItem.fromJson(n));
//       }
//       return items;
//     } else {
//       throw Exception('Failed to fetch notifications: ${response.statusCode}');
//     }
//   }

//   // ---------------- Fetch Unread Notifications ------------------
//   Future<List<NotificationItem>> fetchNotificationsUnread(
//       int employeeId) async {
//     if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

//     final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
//       'code': mainKey,
//       'employeeId': employeeId.toString(),
//       'status': 'unread',
//     });

//     final response = await _apiClient.get(uri.toString(), useAuth: true);

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final notifications = data['notifications'];
//       List<NotificationItem> items = [];
//       for (var n in notifications) {
//         items.add(NotificationItem.fromJson(n));
//       }
//       return items;
//     } else {
//       throw Exception('Failed to fetch notifications: ${response.statusCode}');
//     }
//   }

//   // ---------------- Mark as Read ------------------
//   Future<void> markAsRead(List<int> notificationIds) async {
//     if (markReadKey.isEmpty) throw Exception("Missing NOTIFI_MARK_READ_KEY");

//     final url = '$baseUrl/notifications/mark-read?code=$markReadKey';

//     final response = await _apiClient.post(
//       url,
//       body: {"NotificationIds": notificationIds},
//       useAuth: true,
//     );

//     if (response.statusCode != 200) {
//       throw Exception('Failed to mark notifications as read');
//     }
//   }

//   // ---------------- Send Shift Notification ------------------
//   Future<void> sendShiftNotification(
//       int employeeId, String shiftDetails) async {
//     if (shiftKey.isEmpty) {
//       debugPrint("❌ Missing NOTIFI_SHIFT_KEY");
//       return;
//     }

//     String url = '$baseUrl/SendShiftNotification?code=$shiftKey';

//     final payload = {
//       "userTag": "user_$employeeId",
//       "shiftDetails": shiftDetails,
//     };

//     try {
//       final response = await _apiClient.post(url, body: payload, useAuth: true);
//       if (response.statusCode == 200) {
//         debugPrint("✅ Notification sent to user_$employeeId");
//       } else {
//         debugPrint("❌ Failed to send notification: ${response.body}");
//       }
//     } catch (e) {
//       debugPrint("❌ Notification sending error: $e");
//     }
//   }

//   // ---------------- Send Leave Request (Employee -> Manager) ------------------
//   Future<void> sendLeaveRequeststoManager(int employeeId, String? leaveType,
//       String startDate, String endDate, String reason) async {
//     if (leaveRequestKey.isEmpty) {
//       debugPrint("❌ Missing NOTIFI_LEAVE_REQUEST_KEY");
//       return;
//     }

//     final url = '$baseUrl/SendLeaveRequestNotification?code=$leaveRequestKey';

//     final body = {
//       "EmployeeId": employeeId,
//       "LeaveType": leaveType,
//       "StartDate": startDate,
//       "EndDate": endDate,
//       "Reason": reason,
//     };

//     try {
//       final response = await _apiClient.post(url, body: body, useAuth: true);
//       if (response.statusCode == 200) {
//         debugPrint("✅ Leave request notification sent");
//       } else {
//         debugPrint("❌ Failed to send leave request: ${response.body}");
//       }
//     } catch (e) {
//       debugPrint("Error sending leave request: $e");
//     }
//   }

//   // ---------------- Leave Approval (Manager -> Employee) ------------------
//   Future<void> leaveNotification(int id, String newStatus) async {
//     if (leaveApprovalKey.isEmpty) {
//       debugPrint("❌ Missing NOTIFI_LEAVE_APPROVAL_KEY");
//       return;
//     }

//     final url =
//         '$baseUrl/SendLeaveApprovalNotificationFunction?code=$leaveApprovalKey';
//     final body = {"EmployeeId": id, "Status": newStatus};

//     try {
//       final response = await _apiClient.post(url, body: body, useAuth: true);
//       if (response.statusCode == 200) {
//         debugPrint("Leave $newStatus notification sent");
//       } else {
//         throw Exception("Failed to send notification: ${response.statusCode}");
//       }
//     } catch (e) {
//       debugPrint("Error: $e");
//       rethrow;
//     }
//   }

//   // ---------------- Shift Completion ------------------
//   Future<void> sendShiftCompletionNotification(
//     String? employeeName,
//     int shiftId,
//     DateTime clockOutTime,
//   ) async {
//     if (shiftCompleteKey.isEmpty) {
//       debugPrint("❌ Missing NOTIFI_SHIFT_COMPLETE_KEY");
//       return;
//     }

//     final url =
//         '$baseUrl/SendShiftCompletedNotification?code=$shiftCompleteKey';

//     final formattedTime =
//         DateFormat('h:mma').format(clockOutTime).toLowerCase();
//     final message = "$employeeName completed shift #$shiftId at $formattedTime";
//     final body = {"CompletionDetails": message};

//     try {
//       final response = await _apiClient.post(url, body: body, useAuth: true);
//       if (response.statusCode == 200) {
//         debugPrint("✅ Notification sent: $message");
//       } else {
//         throw Exception("Failed to send notification: ${response.statusCode}");
//       }
//     } catch (e) {
//       debugPrint("Error sending shift completion notification: $e");
//     }
//   }

//   static Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
//     debugPrint("📦 Background message: ${message.messageId}");
//   }
// }

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/notification.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();

  // Initialize Local Notifications Plugin to show alerts when app is open
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Safely get Base URL
  String get baseUrl => dotenv.env['NOTIFI_BASE_URL'] ?? '';

  // Safe Keys
  String get mainKey => dotenv.env['NOTIFI_MAIN_KEY'] ?? '';
  String get registerKey => dotenv.env['NOTIFI_REGISTER_KEY'] ?? '';
  String get markReadKey => dotenv.env['NOTIFI_MARK_READ_KEY'] ?? '';
  String get leaveApprovalKey => dotenv.env['NOTIFI_LEAVE_APPROVAL_KEY'] ?? '';
  String get leaveRequestKey => dotenv.env['NOTIFI_LEAVE_REQUEST_KEY'] ?? '';
  String get shiftKey => dotenv.env['NOTIFI_SHIFT_KEY'] ?? '';
  String get shiftCompleteKey => dotenv.env['NOTIFI_SHIFT_COMPLETE_KEY'] ?? '';

  // Initialize FCM
  Future<void> initializeFCM({
    required int employeeId,
    required String userTag,
    void Function(RemoteMessage)? onForegroundMessage,
    void Function(RemoteMessage)? onNotificationOpenedApp,
  }) async {
    try {
      // Request Permission
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      final token = await _firebaseMessaging.getToken();

      // Only register device if logged in (employeeId is not 0)
      // This prevents the 403 Forbidden error at app startup
      if (token != null && employeeId != 0) {
        debugPrint("FCM TOKEN: $token");
        await registerDeviceTokenToBackend(
          token: token,
          employeeId: employeeId,
          tag: userTag,
        );
      }

      // Foreground Listener (App is Open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Foreground Message Received: ${message.data}");

        // Manual Parsing Logic for Backend Data Messages
        String? title;
        String? body;

        // Check for specific keys from your backend
        if (message.data.containsKey('shiftDetails')) {
          title = "New Shift Assigned";
          body = message.data['shiftDetails'];
        } else if (message.data.containsKey('completionDetails')) {
          title = "Shift Completed";
          body = message.data['completionDetails'];
        } else if (message.data.containsKey('Status')) {
          title = "Leave Update";
          body = "Your leave request is ${message.data['Status']}";
        } else if (message.notification != null) {
          // Fallback: Standard notification
          title = message.notification?.title;
          body = message.notification?.body;
        }

        // Trigger Visual Notification
        if (title != null && body != null) {
          _localNotifications.show(
            message.hashCode,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel', // Must match ID in main.dart
                'High Importance Notifications',
                channelDescription: 'Used for important notifications',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }

        if (onForegroundMessage != null) onForegroundMessage(message);
      });

      // Background Listener (User Taps Notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("Notification tapped (Opened from Background)");
        if (onNotificationOpenedApp != null) onNotificationOpenedApp(message);
      });

      // Background Handler (App Terminated)
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      debugPrint("FCM Initialization error: $e");
    }
  }

  // Register Device Token
  Future<void> registerDeviceTokenToBackend({
    required String token,
    required int employeeId,
    required String tag,
  }) async {
    if (registerKey.isEmpty) {
      debugPrint("Missing NOTIFI_REGISTER_KEY");
      return;
    }

    String url = '$baseUrl/RegisterDevice?code=$registerKey';
    final body = {
      "EmployeeId": employeeId,
      "DeviceToken": token,
      "Tag": tag,
    };

    try {
      // Use ApiClient which attaches the Bearer Token from SharedPreferences
      final response = await _apiClient.post(url, body: body, useAuth: true);

      if (response.statusCode == 200) {
        debugPrint("Device registered successfully");
      } else {
        debugPrint(
            "Register failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Device registration error: $e");
    }
  }

  // Fetch Read Notifications
  Future<List<NotificationItem>> fetchNotificationsread(int employeeId) async {
    if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

    final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
      'code': mainKey,
      'employeeId': employeeId.toString(),
      'status': 'read',
    });

    final response = await _apiClient.get(uri.toString(), useAuth: true);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final notifications = data['notifications'];
      List<NotificationItem> items = [];
      for (var n in notifications) {
        items.add(NotificationItem.fromJson(n));
      }
      return items;
    } else {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }
  }

  // Fetch Unread Notifications
  Future<List<NotificationItem>> fetchNotificationsUnread(
      int employeeId) async {
    if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

    final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
      'code': mainKey,
      'employeeId': employeeId.toString(),
      'status': 'unread',
    });

    final response = await _apiClient.get(uri.toString(), useAuth: true);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final notifications = data['notifications'];
      List<NotificationItem> items = [];
      for (var n in notifications) {
        items.add(NotificationItem.fromJson(n));
      }
      return items;
    } else {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }
  }

  // Mark as Read
  Future<void> markAsRead(List<int> notificationIds) async {
    if (markReadKey.isEmpty) throw Exception("Missing NOTIFI_MARK_READ_KEY");

    final url = '$baseUrl/notifications/mark-read?code=$markReadKey';

    final response = await _apiClient.post(
      url,
      body: {"NotificationIds": notificationIds},
      useAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notifications as read');
    }
  }

  // Send Shift Notification
  Future<void> sendShiftNotification(
      int employeeId, String shiftDetails) async {
    if (shiftKey.isEmpty) {
      debugPrint("Missing NOTIFI_SHIFT_KEY");
      return;
    }

    String url = '$baseUrl/SendShiftNotification?code=$shiftKey';

    final payload = {
      "userTag": "user_$employeeId",
      "shiftDetails": shiftDetails,
    };

    try {
      final response = await _apiClient.post(url, body: payload, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Notification sent to user_$employeeId");
      } else {
        debugPrint("Failed to send notification: ${response.body}");
      }
    } catch (e) {
      debugPrint("Notification sending error: $e");
    }
  }

  // Send Leave Request
  Future<void> sendLeaveRequeststoManager(int employeeId, String? leaveType,
      String startDate, String endDate, String reason) async {
    if (leaveRequestKey.isEmpty) {
      debugPrint("Missing NOTIFI_LEAVE_REQUEST_KEY");
      return;
    }

    final url = '$baseUrl/SendLeaveRequestNotification?code=$leaveRequestKey';

    final body = {
      "EmployeeId": employeeId,
      "LeaveType": leaveType,
      "StartDate": startDate,
      "EndDate": endDate,
      "Reason": reason,
    };

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Leave request notification sent");
      } else {
        debugPrint("Failed to send leave request: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending leave request: $e");
    }
  }

  // Leave Approval
  Future<void> leaveNotification(int id, String newStatus) async {
    if (leaveApprovalKey.isEmpty) {
      debugPrint("Missing NOTIFI_LEAVE_APPROVAL_KEY");
      return;
    }

    final url =
        '$baseUrl/SendLeaveApprovalNotificationFunction?code=$leaveApprovalKey';
    final body = {"EmployeeId": id, "Status": newStatus};

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Leave $newStatus notification sent");
      } else {
        throw Exception("Failed to send notification: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error: $e");
      rethrow;
    }
  }

  // Shift Completion
  Future<void> sendShiftCompletionNotification(
    String? employeeName,
    int shiftId,
    DateTime clockOutTime,
  ) async {
    if (shiftCompleteKey.isEmpty) {
      debugPrint("Missing NOTIFI_SHIFT_COMPLETE_KEY");
      return;
    }

    final url =
        '$baseUrl/SendShiftCompletedNotification?code=$shiftCompleteKey';

    final formattedTime =
        DateFormat('h:mma').format(clockOutTime).toLowerCase();
    final message = "$employeeName completed shift #$shiftId at $formattedTime";
    final body = {"CompletionDetails": message};

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Notification sent: $message");
      } else {
        throw Exception("Failed to send notification: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error sending shift completion notification: $e");
    }
  }

  // Background Handler Stub
  @pragma('vm:entry-point')
  static Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
    debugPrint("Background message stub: ${message.messageId}");
  }
}
