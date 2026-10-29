import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Kept only for image upload
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/models/JobRole.dart';
import 'package:shiftsmart/models/JobRoleType.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class JobService {
  // 1. Initialize ApiClient
  final ApiClient _apiClient = ApiClient();

  final String baseUrl = dotenv.env['JOB_BASE_URL']!;
  String fetchJobKey = dotenv.env['FETCH_JOB_KEY']!;
  String addJobKey = dotenv.env['ADD_JOB_KEY']!;
  String imageJobKey = dotenv.env['JOB_IMAGE_KEY']!;
  String updateJobKey = dotenv.env['UPDATE_JOB_KEY']!;
  String jobRoleKey = dotenv.env['JOBROLE_KEY']!;
  String jobRoleTypeKey = dotenv.env['JOBROLE_TYPE_KEY']!;

  // --- FETCH ALL JOBS ---
  Future<List<Job>> fetchAllJobs() async {
    final geturl = '$baseUrl/job/list?code=$fetchJobKey';
    try {
      // FIX: Use ApiClient with useAuth: true
      // This adds the "Authorization: Bearer <token>" header automatically
      final response = await _apiClient.get(geturl, useAuth: true);

      debugPrint("Job response: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is List && jsonData.isNotEmpty) {
          return jsonData.map<Job>((data) => Job.fromJson(data)).toList();
        } else {
          debugPrint("Unexpected data format.");
          return [];
        }
      } else {
        debugPrint("Failed to load jobs. Status code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error in fetchAllJobs: $e");
      return [];
    }
  }

  // --- ADD JOB (Data Only) ---
  Future<int?> addJob(Map<String, dynamic> jobData) async {
    final url = '$baseUrl/job/create?code=$addJobKey';
    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.post(
        url,
        body: jobData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return 1;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("Error adding job data: $e");
      rethrow;
    }
  }

  // --- ADD JOB WITH IMAGE (Multipart Request) ---
  // Note: Multipart requests are special, so we manually add the token here.
  Future<bool> createJobWithImage(
      Map<String, dynamic> jobData, File image) async {
    final url = Uri.parse('$baseUrl/job/upload-with-image?code=$imageJobKey');
    try {
      final request = http.MultipartRequest("POST", url);

      // FIX: Manually get token and add header
      final token = await _apiClient.getAppToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['job'] = jsonEncode(jobData);
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint("Failed to add job with image ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("Error occured while adding job with image $e");
      rethrow;
    }
  }

  // --- UPDATE JOB ---
  Future<bool> updateJob(int jobId, Map<String, dynamic> jobData) async {
    final url = '$baseUrl/job/update/$jobId?code=$updateJobKey';
    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.put(
        url,
        body: jobData,
        useAuth: true,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint("Error updating job: $e");
      rethrow;
    }
  }

  // --- FETCH JOB ROLES ---
  Future<List<JobRole>> fetchJobRole(int jobId) async {
    final url = '$baseUrl/job/roles/$jobId?code=$jobRoleKey';
    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((e) => JobRole.fromJson(e)).toList();
      } else {
        throw Exception("Failed to fetch job roles");
      }
    } catch (e) {
      debugPrint("Error fetching job roles");
      rethrow;
    }
  }

  // --- FETCH JOB ROLE TYPES ---
  Future<List<JobRoleType>> fetchJobRoleType() async {
    final url = '$baseUrl/jobroletype/list?code=$jobRoleTypeKey';
    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((e) => JobRoleType.fromJson(e)).toList();
      } else {
        throw Exception("Failed to fetch job roles");
      }
    } catch (e) {
      debugPrint("Error fetching data");
      rethrow;
    }
  }
}
