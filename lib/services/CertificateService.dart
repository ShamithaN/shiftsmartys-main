import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http; // Kept for MultipartRequest
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/empcertModel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart'; // Import ApiClient

class CertificateService {
  final ApiClient _apiClient = ApiClient(); // Initialize ApiClient

  // Use keys from .env to prevent 401 errors
  final String baseUrl = dotenv.env['BASE_URL']!;
  final String certBaseUrl = dotenv.env['CERT_BASE_URL']!;

  // Safe getters for keys
  String get uploadKey => dotenv.env['CERT_UPLOAD_KEY'] ?? '';
  String get fetchKey => dotenv.env['CERT_FETCH_KEY'] ?? '';

  // --- UPLOAD CERTIFICATE (Multipart) ---
  Future<String?> uploadCertificate({
    required File file,
    required int employeeId,
    required String certificateType,
    required String dateIssued,
    required String expiryDate,
  }) async {
    // 1. Construct URL with the correct Key
    final Uri uploadUrl = Uri.parse(
      '$certBaseUrl/cert/upload?code=$uploadKey',
    );

    try {
      final request = http.MultipartRequest('POST', uploadUrl);

      // 2. FIX: Manually Add Authorization Header for Multipart
      final token = await _apiClient.getAppToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // 3. Add File
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType.parse(
            lookupMimeType(file.path) ?? 'application/octet-stream',
          ),
        ),
      );

      // 4. Add Fields
      request.fields['employeeId'] = employeeId.toString();
      request.fields['certificateType'] = certificateType;
      request.fields['dateIssued'] = dateIssued;
      request.fields['expiryDate'] = expiryDate;

      // 5. Send
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return "Upload failed: ${response.statusCode} - $responseBody";
      }
    } catch (e) {
      return "Upload error: $e";
    }
  }

  // --- FETCH CERTIFICATES ---
  Future<List<EmployeeCertificate>> fetchCertificates() async {
    // 1. Get Employee ID
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getInt('employeeId');

    if (employeeId == null) {
      throw Exception("Employee ID not found");
    }

    // 2. Construct URL (using fetchKey)
    // Note: Endpoint /employee/documents/{id} matches 'EmployeeDocuments_GetByEmployeeIdHandler'
    final url = '$baseUrl/employee/documents1/$employeeId?code=$fetchKey';

    try {
      // 3. FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((e) => EmployeeCertificate.fromJson(e)).toList();
      } else {
        throw Exception(
            "Error fetching certificates: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}
