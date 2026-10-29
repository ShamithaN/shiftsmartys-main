import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http; // Removed: We use ApiClient now
import 'package:shiftsmart/models/company.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart'; // Import ApiClient

class CompanyService {
  final ApiClient _apiClient = ApiClient(); // 1. Initialize ApiClient

  final String baseUrl = dotenv.env['COM_BASE_URL']!;
  String addCompanyKey = dotenv.env['ADD_COM_KEY']!;
  String updateCompanyKey = dotenv.env['UPDATE_COM_KEY']!;
  String fetchCompanyKey = dotenv.env['FETCH_COM_KEY']!;

  // --- ADD COMPANY ---
  Future<bool> addCompany(Map<String, dynamic> companyData) async {
    final String url = '$baseUrl/company/create?code=$addCompanyKey';

    try {
      // FIX: Use ApiClient with useAuth: true to send the Token
      final response = await _apiClient.post(
        url,
        body: companyData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to add company: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error adding company: $e");
      return false;
    }
  }

  // --- UPDATE COMPANY ---
  Future<bool> updateCompany(int id, Map<String, dynamic> companyData) async {
    final String updateUrl =
        '$baseUrl/company/update/$id?code=$updateCompanyKey';

    // Ensure ID is in the body if required by backend
    companyData['CompanyId'] = id;

    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.put(
        updateUrl,
        body: companyData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to update company: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating company: $e');
      return false;
    }
  }

  // --- FETCH COMPANIES ---
  Future<List<Company>> fetchCompanies() async {
    final String url = '$baseUrl/company/all?code=$fetchCompanyKey';

    try {
      // FIX: Use ApiClient with useAuth: true
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((e) => Company.fromJson(e)).toList();
      } else {
        // Log the actual error from the server
        debugPrint(
            "Failed to fetch companies: ${response.statusCode} - ${response.body}");
        throw Exception("Failed to fetch companies");
      }
    } catch (e) {
      debugPrint("Error fetching company data: $e");
      // Return empty list instead of crashing app
      return [];
    }
  }
}
