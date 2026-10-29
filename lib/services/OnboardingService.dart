import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  final String fetchInviteKey = dotenv.env['FETCH_INVITE_KEY'] ?? '';
  final String onboardingKey = dotenv.env['SUBMIT_ONBOARD_KEY'] ?? '';
  final String resubmitDocKey = dotenv.env['RESUBMIT_DOC_KEY'] ?? '';

  // Step A: Fetch Invitation
  Future<Map<String, dynamic>?> fetchInvitation(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final url =
        '$baseUrl/employee/invitation/$encodedEmail?code=$fetchInviteKey';

    try {
      print("🔹 Fetching Invitation: $url");
      final response = await http.get(Uri.parse(url));

      print("🔹 Fetch Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("🔴 Fetch Error: $e");
      return null;
    }
  }

  // Step B: Submit Form
  Future<http.Response> submitOnboardingForm({
    required File profilePicture,
    required Map<String, File> uploadedCertificates,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> nextOfKins,
    required String password,
    bool isResubmission = false,
  }) async {
    String url;

    // 1. DETERMINE URL
    if (isResubmission) {
      url =
          'https://shiftsmart-employee-func-uat.azurewebsites.net/api/document/resubmit?code=$resubmitDocKey';
    } else {
      url = '$baseUrl/employee/onboarding-complete?code=$onboardingKey';
    }

    print("🔹 Submitting Multipart Request to: $url");
    print(
        "🔹 Mode: ${isResubmission ? 'RESUBMISSION (Partial)' : 'NEW ONBOARDING (Full)'}");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // 2. AUTH TOKEN (Optional now, but good to keep if they re-enable it)
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('appToken') ?? prefs.getString('token');

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        print(
            "⚠️ Warning: No Auth Token found. Proceeding without it (as allowed by backend).");
      }

      // 3. ADD DATA FIELDS
      request.fields['profile'] = jsonEncode(profile);

      //  CRITICAL FIX: Add 'employeeId' as a standalone field
      // The backend likely needs this to identify the user before parsing the JSON
      var empId = profile['EmployeeId'] ?? profile['employeeId'];
      if (empId != null) {
        request.fields['employeeId'] = empId.toString();
        print("🆔 Added Root Field: employeeId = $empId");
      } else {
        print("⚠️ Warning: Could not find EmployeeId in profile map.");
      }

      if (!isResubmission) {
        request.fields['nextOfKins'] = jsonEncode(nextOfKins);
        request.fields['password'] = password;
      }

      // 4. ADD PROFILE PICTURE
      if (profilePicture.existsSync()) {
        final mimeType = lookupMimeType(profilePicture.path) ?? 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'profilePicture',
          profilePicture.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // 5. ADD DOCUMENTS
      for (var entry in uploadedCertificates.entries) {
        if (entry.value.existsSync()) {
          final mimeType =
              lookupMimeType(entry.value.path) ?? 'application/pdf';

          print("📎 Attaching File: ${entry.key}");

          request.files.add(await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      // 6. SEND REQUEST
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Submit Status: ${response.statusCode}");
      print("📥 Submit Body: ${response.body}");

      return response;
    } catch (e) {
      print("❌ Submit Error: $e");
      return http.Response('Error: $e', 500);
    }
  }
}
