import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/models/SiteEmployee.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart'; // Import ApiClient

class SiteService {
  final ApiClient _apiClient = ApiClient();

  final String baseUrl = dotenv.env['COM_BASE_URL']!;
  final String addSiteKey = dotenv.env['ADD_SITE_KEY']!;
  final String updateSiteKey = dotenv.env['UPDATE_SITE_KEY']!;
  final String fetchSiteKey = dotenv.env['FETCH_SITE_KEY']!;
  final String fetchAllSitesKey = dotenv.env['FETCH_ALL_SITES_KEY']!;
  final String fetchActiveLocationsKey =
      dotenv.env['FETCH_ACTIVE_LOCATIONS_KEY'] ?? '';
  final String attendanceBaseUrl = dotenv.env['ATTENDANCE_BASE_URL'] ?? '';

  // --- ADD SITE ---
  // inside SiteService.dart

  Future<bool> addSite(Map<String, dynamic> siteData) async {
    final String url = '$baseUrl/site/create?code=$addSiteKey';

    try {
      debugPrint("POST Request to: $url");
      debugPrint("Body: $siteData");

      final response = await _apiClient.post(
        url,
        body: siteData, // ApiClient handles jsonEncode
        useAuth: true,
      );

      debugPrint("Response Status: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        // Logic to show error message
        return false;
      }
    } catch (e) {
      debugPrint("Error adding site: $e");
      return false;
    }
  }

  // --- UPDATE SITE ---
  Future<bool> updateSite(int id, Map<String, dynamic> siteData) async {
    final updateUrl = '$baseUrl/site/update/$id?code=$updateSiteKey';
    siteData['siteId'] = id;

    try {
      final response = await _apiClient.put(
        updateUrl,
        body: siteData,
        useAuth: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Failed to update site: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint("Error updating site: $e");
      return false;
    }
  }

  // --- FETCH SITE BY ID (THE FIX) ---
  // Updated to return a Site object directly
  Future<Site?> fetchSiteById(int siteId) async {
    try {
      final url = '$baseUrl/site/$siteId?code=$fetchSiteKey';

      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // Convert JSON directly to Site object
        return Site.fromJson(jsonData);
      } else {
        debugPrint("Failed to fetch site: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching site: $e");
      return null;
    }
  }

  // --- FETCH ALL SITES (Restricted to Managers) ---
  Future<List<Site>> fetchAllSites() async {
    final url = '$baseUrl/site/all?code=$fetchAllSitesKey';

    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData.map((e) => Site.fromJson(e)).toList();
      } else {
        debugPrint("Failed to load sites: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching sites: $e");
      return [];
    }
  }

  // --- FETCH EMPLOYEES IN SITE ---
  Future<List<SiteEmployee>> fetchEmployeesInSite(int siteId, Site site) async {
    // 1. Use ATTENDANCE_BASE_URL
    // 2. Use the endpoint "/active/locations" (matches Web Portal)
    final url =
        '$attendanceBaseUrl/site/$siteId/active/locations?code=$fetchActiveLocationsKey';

    debugPrint("🔍 Fetching Active Locations: $url");

    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        debugPrint("✅ Active Employees Data: $jsonData");

        return jsonData
            .map((e) => SiteEmployee.fromJson(e, site))
            .where((e) => e.clockInLat != null && e.clockInLng != null)
            .toList();
      } else {
        debugPrint(
            "⚠️ Failed to load employees: ${response.statusCode} | Body: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ Error fetching employees: $e");
      return [];
    }
  }
}
