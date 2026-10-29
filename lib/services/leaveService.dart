import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http; // Removed: We use ApiClient now
import 'package:shiftsmart/models/LeaveRequest.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class LeaveService {
  // 1. Initialize the ApiClient
  final ApiClient _apiClient = ApiClient();

  final String baseUrl = dotenv.env['LEAVE_BASE_URL']!;
  final String addLeaveKey = dotenv.env['ADD_LEAVE_KEY']!;
  final String deleteLeaveKey = dotenv.env['DELETE_LEAVE_KEY']!;
  final String fetchLeaveKey = dotenv.env['FETCH_LEAVE_KEY']!;
  final String fetchLeaveBalanceKey = dotenv.env['FETCH_LEAVE_BALANCE_KEY']!;
  final String updateLeaveKey = dotenv.env['UPDATE_LEAVE_KEY']!;

  // --- ADD LEAVE REQUEST ---
  Future<bool> addLeaveRequest(Map<String, dynamic> leaveData) async {
    final String url = '$baseUrl/leave/request?code=$addLeaveKey';

    try {
      final response = await _apiClient.post(
        url,
        body: leaveData,
        useAuth: true, // Sends Bearer Token + Key
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to add leave request: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error adding leave request: $e");
      return false;
    }
  }

  // --- DELETE LEAVE REQUEST ---
  Future<bool?> deleteLeaveRequest(int leaveId) async {
    final String url = '$baseUrl/leave/delete/$leaveId?code=$deleteLeaveKey';

    try {
      final response = await _apiClient.delete(
        url,
        useAuth: true, // Sends Bearer Token + Key
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Failed to delete leave: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error deleting the leave request: $e");
      return null;
    }
  }

  // --- FETCH ALL LEAVE REQUESTS ---
  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final String url = '$baseUrl/leave/all?code=$fetchLeaveKey';

    try {
      final response = await _apiClient.get(
        url,
        useAuth: true, // Sends Bearer Token + Key
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => LeaveRequest.fromJson(item)).toList();
      } else {
        // IMPORTANT: This prints the exact server error (e.g. "Invalid column name")
        debugPrint("Failed to load leaves. Status: ${response.statusCode}");
        debugPrint("Server Response: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching leave requests: $e");
      // Return empty list instead of throwing to prevent app crash
      return [];
    }
  }

  // --- FETCH LEAVE BALANCE ---
  Future<int?> fetchLeaveBalance(int employeeId) async {
    final String url =
        '$baseUrl/leave/balance/$employeeId?code=$fetchLeaveBalanceKey';

    try {
      final response = await _apiClient.get(
        url,
        useAuth: true, // Sends Bearer Token + Key
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['RemainingLeaveDays'];
      } else {
        debugPrint("Failed to fetch balance: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching leave balance: $e");
      return null;
    }
  }

  // --- UPDATE LEAVE STATUS (Approve/Reject) ---
  Future<void> updateLeaveStatus(String id, String newStatus) async {
    final String url = '$baseUrl/leave/approve/$id?code=$updateLeaveKey';
    final body = {
      "status": newStatus
    }; // ApiClient handles jsonEncode automatically usually

    try {
      final response = await _apiClient.post(
        url,
        body: body,
        useAuth: true, // Sends Bearer Token + Key
      );

      if (response.statusCode == 200) {
        debugPrint("Leave status updated to: $newStatus");
      } else {
        debugPrint("Failed to update status: ${response.body}");
        throw Exception("Failed to update leave status");
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      rethrow;
    }
  }
}
