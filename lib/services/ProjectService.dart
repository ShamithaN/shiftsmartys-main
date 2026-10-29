import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shiftsmart/models/Project.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class ProjectService {
  final ApiClient _apiClient = ApiClient();

  final String baseUrl = dotenv.env['COM_BASE_URL']!;
  final String addKey = dotenv.env['ADD_PROJECT_KEY']!;
  final String updateKey = dotenv.env['UPDATE_PROJECT_KEY']!;
  final String fetchKey = dotenv.env['FETCH_PROJECT_KEY']!;

  // --- ADD PROJECT ---
  Future<bool> addProject(Map<String, dynamic> projectData) async {
    final String createUrl = '$baseUrl/project/create?code=$addKey';

    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.post(
        createUrl,
        body: projectData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to add project: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error adding project: $e");
      return false;
    }
  }

  // --- UPDATE PROJECT ---
  Future<bool> updateProject(int id, Map<String, dynamic> projectData) async {
    final updateUrl = '$baseUrl/project/update/$id?code=$updateKey';

    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.put(
        updateUrl,
        body: projectData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to update project: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error updating project: $e");
      return false;
    }
  }

  // --- FETCH ALL PROJECTS ---
  Future<List<Project>> fetchAllProjects() async {
    final geturl = '$baseUrl/project/all?code=$fetchKey';

    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.get(geturl, useAuth: true);

      debugPrint("Project response: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData is List && jsonData.isNotEmpty) {
          return jsonData
              .map<Project>((data) => Project.fromJson(data))
              .toList();
        } else {
          debugPrint("Unexpected data format.");
          return [];
        }
      } else {
        debugPrint(
            "Failed to load projects. Status code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error in fetchAllProjects: $e");
      return [];
    }
  }
}
