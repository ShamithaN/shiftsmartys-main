import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  //  Removed '!' and added '?? ""' to prevent App Crash
  final String updateProfileKey = dotenv.env['UPDATE_PROFILE_KEY'] ?? '';
  final String updatePassKey = dotenv.env['UPDATE_PASS_KEY'] ?? '';

  // --- UPDATE PROFILE ---
  Future<String?> updateProfile({
    required int employeeId,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> nextOfKins,
    File? profilePicture,
  }) async {
    // Check if key exists
    if (updateProfileKey.isEmpty) {
      return "Error: Missing UPDATE_PROFILE_KEY in .env";
    }

    final url = Uri.parse(
        '$baseUrl/employee/update/$employeeId?code=$updateProfileKey');
    final request = http.MultipartRequest('PUT', url);

    final token = await _apiClient.getAppToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['profile'] = jsonEncode(profile);
    request.fields['nextOfKins'] = jsonEncode(nextOfKins);

    if (profilePicture != null && profilePicture.existsSync()) {
      final mimeType = MediaType('image', 'jpeg');
      request.files.add(await http.MultipartFile.fromPath(
          'profilePicture', profilePicture.path,
          contentType: mimeType));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return 'Failed : ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // --- UPDATE PASSWORD ---
  Future<bool?> updatePassword(
      String userEmail, String currentPassword, String newPassword) async {
    // Check if key exists
    if (updatePassKey.isEmpty) {
      debugPrint("❌ Error: Missing UPDATE_PASS_KEY in .env");
      return false;
    }

    final url = '$baseUrl/employee/change-password?code=$updatePassKey';

    try {
      final response = await _apiClient.post(
        url,
        body: {
          "email": userEmail,
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        },
        useAuth: true,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Failed to update password: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("Error updating password: $e");
      return null;
    }
  }
}
