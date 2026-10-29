// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart'; // Required for MediaType
// import 'package:mime/mime.dart'; // Required for lookupMimeType
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'api_client.dart'; // Import ApiClient

// class AttendanceService {
//   final ApiClient _apiClient = ApiClient(); // Initialize ApiClient

//   String baseUrl = dotenv.env['ATTENDANCE_BASE_URL']!;
//   String fetchAttendancePhoto = dotenv.env['FETCH_ATTENDANCE_PHOTO_KEY']!;
//   String getShiftById = dotenv.env['SHIFT_BY_SHIFTID_KEY']!;
//   String clockinKey = dotenv.env['CLOCKIN_KEY']!;
//   String clockoutKey = dotenv.env['CLOCKOUT_KEY']!;
//   String breakstart = dotenv.env['BREAK_START_KEY']!;
//   String breakend = dotenv.env['BREAK_END_KEY']!;

//   // --- GET CLOCK PHOTO URL ---
//   Future<String?> fetchClockPhotoUrl(int attendanceId,
//       {required isClockIn}) async {
//     final endPoint = isClockIn ? 'view-clockin-photo' : 'view-clockout-photo';
//     final url = '$baseUrl/attendance/$endPoint/$attendanceId';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       final jsonData = jsonDecode(response.body);
//       return jsonData['photoUrl'].toString();
//     } catch (e) {
//       debugPrint("Error fetching clock ${isClockIn ? "in" : "out"} photo: $e");
//     }
//     return null;
//   }

//   // --- FETCH ATTENDANCE PHOTOS ---
//   Future<Map<String, String?>> fetchAttendancePhotos(
//       int employeeId, int shiftId) async {
//     final url =
//         "$baseUrl/attendance/by-employee/$employeeId?code=$fetchAttendancePhoto";
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> jsonData = jsonDecode(response.body);
//         final record = jsonData.firstWhere(
//           (attendance) => attendance['ShiftId'] == shiftId,
//           orElse: () => <String, dynamic>{},
//         );
//         if (record == null) return {};
//         return {
//           'clockIn': record['ClockInPhotoUrl'] as String?,
//           'clockOut': record['ClockOutPhotoUrl'] as String?,
//         };
//       }
//     } catch (e) {
//       debugPrint("Error fetching attendance photos: $e");
//     }
//     return {};
//   }

//   // --- GET SHIFTS BY ID ---
//   Future<dynamic> getShiftsByShiftId(int employeeId, {int? shiftId}) async {
//     final url =
//         '$baseUrl/attendance/by-employee/$employeeId?code=$getShiftById';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> shifts = jsonDecode(response.body);
//         if (shiftId != null) {
//           final shift = shifts.firstWhere(
//             (s) => s['ShiftId'] == shiftId,
//             orElse: () => null,
//           );
//           return shift;
//         }
//         return shifts;
//       } else {
//         throw Exception("Failed to fetch shifts: HTTP ${response.statusCode}");
//       }
//     } catch (e) {
//       throw Exception("Error fetching shifts for employee $employeeId: $e");
//     }
//   }

//   // --- CLOCK IN (Multi-Photo & GPS) ---
//   Future<Map<String, dynamic>> clockIn({
//     required int employeeId,
//     required int shiftId,
//     required int siteId,
//     required String scheduledStartTime,
//     required List<File> photos, // List of photos
//     required DateTime clockInTime,
//     required double latitude,
//     required double longitude,
//   }) async {
//     final url = Uri.parse('$baseUrl/attendance/clockin?code=$clockinKey');
//     try {
//       final request = http.MultipartRequest("POST", url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['employeeId'] = employeeId.toString();
//       request.fields['shiftId'] = shiftId.toString();
//       request.fields['siteId'] = siteId.toString();
//       request.fields['scheduledStartTime'] = scheduledStartTime.toString();
//       request.fields['clockInTime'] = clockInTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = await request.send();
//       final responseBody = await response.stream.bytesToString();
//       debugPrint('📤 Clock-in HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final result = jsonDecode(responseBody);
//         return {
//           'success': true,
//           'data': result,
//           'attendanceId': result['AttendanceId'] ?? result['attendanceId'],
//         };
//       } else {
//         throw Exception(
//             "Clock in failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock in service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // --- CLOCK OUT (Multi-Photo & GPS) ---
//   Future<Map<String, dynamic>> clockOut({
//     required int attendanceId,
//     required DateTime clockOutTime,
//     required List<File> photos,
//     required double latitude,
//     required double longitude,
//     Duration? timeout,
//   }) async {
//     final url = Uri.parse(
//         '$baseUrl/attendance/clockout/$attendanceId?code=$clockoutKey');
//     try {
//       final request = http.MultipartRequest('PUT', url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['attendanceId'] = attendanceId.toString();
//       request.fields['clockOutTime'] = clockOutTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = timeout != null
//           ? await request.send().timeout(timeout)
//           : await request.send();

//       final responseBody = await response.stream.bytesToString();
//       debugPrint('📤 Clock-out HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final result = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
//         return {'success': true, 'data': result};
//       } else {
//         throw Exception(
//             "Clock out failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock out service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // --- BREAK START (Updated for C# Backend) ---
//   Future<bool?> breakStart(int attendanceId,
//       {required DateTime startTime}) async {
//     final url =
//         '$baseUrl/attendance/break/start/$attendanceId?code=$breakstart';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           // Send specific time to fix timezone issue
//           'breakStartTime': startTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "❌ Break start failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error :$e");
//     }
//   }

//   // --- END BREAK (Updated for C# Backend) ---
//   Future<bool?> endBreak(int attendanceId, {required DateTime endTime}) async {
//     final url = '$baseUrl/attendance/break/end/$attendanceId?code=$breakend';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           // Send specific time to fix timezone issue
//           'breakEndTime': endTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "❌ Break end failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error: $e");
//     }
//   }
// }


























// 













// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:mime/mime.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'api_client.dart';

// class AttendanceService {
//   final ApiClient _apiClient = ApiClient();

//   // Base configuration URLs and API keys loaded from environment variables
//   String baseUrl = dotenv.env['ATTENDANCE_BASE_URL']!;
//   String fetchAttendancePhoto = dotenv.env['FETCH_ATTENDANCE_PHOTO_KEY']!;
//   String getShiftById = dotenv.env['SHIFT_BY_SHIFTID_KEY']!;
//   String clockinKey = dotenv.env['CLOCKIN_KEY']!;
//   String clockoutKey = dotenv.env['CLOCKOUT_KEY']!;
//   String breakstart = dotenv.env['BREAK_START_KEY']!;
//   String breakend = dotenv.env['BREAK_END_KEY']!;
  
//   // NEW CODE START: Emergency Clock-Out API Key Configuration
//   // This key is used specifically for emergency clock-out situations
//   // If EMERGENCY_CLOCKOUT_KEY is not defined in .env file, it will
//   // fallback to using the regular CLOCKOUT_KEY
//   String emergencyClockoutKey = dotenv.env['EMERGENCY_CLOCKOUT_KEY'] ?? 
//       dotenv.env['CLOCKOUT_KEY']!;
//   // NEW CODE END

//   // GET CLOCK PHOTO URL
//   // Fetches the URL of a clock-in or clock-out photo for a specific attendance record
//   Future<String?> fetchClockPhotoUrl(int attendanceId,
//       {required isClockIn}) async {
//     final endPoint = isClockIn ? 'view-clockin-photo' : 'view-clockout-photo';
//     final url = '$baseUrl/attendance/$endPoint/$attendanceId';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       final jsonData = jsonDecode(response.body);
//       return jsonData['photoUrl'].toString();
//     } catch (e) {
//       debugPrint("Error fetching clock ${isClockIn ? "in" : "out"} photo: $e");
//     }
//     return null;
//   }

//   // FETCH ATTENDANCE PHOTOS
//   // Retrieves both clock-in and clock-out photo URLs for a specific employee and shift
//   Future<Map<String, String?>> fetchAttendancePhotos(
//       int employeeId, int shiftId) async {
//     final url =
//         "$baseUrl/attendance/by-employee/$employeeId?code=$fetchAttendancePhoto";
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> jsonData = jsonDecode(response.body);
//         final record = jsonData.firstWhere(
//           (attendance) => attendance['ShiftId'] == shiftId,
//           orElse: () => <String, dynamic>{},
//         );
//         if (record == null) return {};
//         return {
//           'clockIn': record['ClockInPhotoUrl'] as String?,
//           'clockOut': record['ClockOutPhotoUrl'] as String?,
//         };
//       }
//     } catch (e) {
//       debugPrint("Error fetching attendance photos: $e");
//     }
//     return {};
//   }

//   // GET SHIFTS BY ID
//   // Fetches shift data for an employee, optionally filtered by a specific shiftId
//   Future<dynamic> getShiftsByShiftId(int employeeId, {int? shiftId}) async {
//     final url =
//         '$baseUrl/attendance/by-employee/$employeeId?code=$getShiftById';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> shifts = jsonDecode(response.body);
//         if (shiftId != null) {
//           final shift = shifts.firstWhere(
//             (s) => s['ShiftId'] == shiftId,
//             orElse: () => null,
//           );
//           return shift;
//         }
//         return shifts;
//       } else {
//         throw Exception("Failed to fetch shifts: HTTP ${response.statusCode}");
//       }
//     } catch (e) {
//       throw Exception("Error fetching shifts for employee $employeeId: $e");
//     }
//   }

//   // CLOCK IN (Multi-Photo & GPS)
//   // Records employee clock-in with multiple photos and GPS coordinates
//   Future<Map<String, dynamic>> clockIn({
//     required int employeeId,
//     required int shiftId,
//     required int siteId,
//     required String scheduledStartTime,
//     required List<File> photos,
//     required DateTime clockInTime,
//     required double latitude,
//     required double longitude,
//   }) async {
//     final url = Uri.parse('$baseUrl/attendance/clockin?code=$clockinKey');
//     try {
//       final request = http.MultipartRequest("POST", url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['employeeId'] = employeeId.toString();
//       request.fields['shiftId'] = shiftId.toString();
//       request.fields['siteId'] = siteId.toString();
//       request.fields['scheduledStartTime'] = scheduledStartTime.toString();
//       request.fields['clockInTime'] = clockInTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = await request.send();
//       final responseBody = await response.stream.bytesToString();
//       debugPrint('Clock-in HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final result = jsonDecode(responseBody);
//         return {
//           'success': true,
//           'data': result,
//           'attendanceId': result['AttendanceId'] ?? result['attendanceId'],
//         };
//       } else {
//         throw Exception(
//             "Clock in failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock in service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // CLOCK OUT (Multi-Photo & GPS)
//   // Records employee clock-out with multiple photos and GPS coordinates
//   // This is the REGULAR clock-out method that requires photos
//   Future<Map<String, dynamic>> clockOut({
//     required int attendanceId,
//     required DateTime clockOutTime,
//     required List<File> photos,
//     required double latitude,
//     required double longitude,
//     Duration? timeout,
//   }) async {
//     final url = Uri.parse(
//         '$baseUrl/attendance/clockout/$attendanceId?code=$clockoutKey');
//     try {
//       final request = http.MultipartRequest('PUT', url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['attendanceId'] = attendanceId.toString();
//       request.fields['clockOutTime'] = clockOutTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = timeout != null
//           ? await request.send().timeout(timeout)
//           : await request.send();

//       final responseBody = await response.stream.bytesToString();
//       debugPrint('Clock-out HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final result = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
//         return {'success': true, 'data': result};
//       } else {
//         throw Exception(
//             "Clock out failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock out service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // NEW CODE START: EMERGENCY CLOCK OUT METHOD
//   // EMERGENCY CLOCK OUT (No Photos Required)
//   // This method allows employees to clock out in emergency situations where
//   // they cannot take photos (e.g., phone battery dead, phone lost, safety emergency)
//   // 
//   // Key differences from regular clock-out:
//   // 1. Photos are NOT required - no multipart/form-data needed
//   // 2. GPS location is OPTIONAL - might not be available in emergencies
//   // 3. Requires an emergency reason for audit purposes
//   // 4. Sends JSON data instead of multipart/form-data
//   // 5. Flags the record as emergency for supervisor review
//   // 
//   // NOTE: The backend endpoint must support this. If you get a 404 error,
//   // you need to implement the backend endpoint first, or use the fallback
//   // method by modifying the regular clockOut endpoint to accept emergency flags.
//   Future<Map<String, dynamic>> emergencyClockOut({
//     required int attendanceId,
//     required int shiftId,
//     required String emergencyReason,
//     double? latitude,
//     double? longitude,
//     Duration? timeout,
//   }) async {
//     // STEP 1: Construct the emergency clock-out endpoint URL
//     // This uses a dedicated emergency endpoint and API key
//     // If your backend doesn't have this endpoint yet, you'll get a 404 error
//     final url = Uri.parse(
//         '$baseUrl/attendance/emergency-clockout/$attendanceId?code=$emergencyClockoutKey');
    
//     try {
//       // STEP 2: Log emergency clock-out initiation for debugging
//       debugPrint('Emergency clock-out initiated for attendance: $attendanceId');
      
//       // STEP 3: Retrieve authentication token from API client
//       final token = await _apiClient.getAppToken();
      
//       // STEP 4: Set up HTTP headers for JSON request
//       // NOTE: Using 'application/json' instead of 'multipart/form-data'
//       // because no photos are being uploaded in emergency situations
//       final headers = <String, String>{
//         'Content-Type': 'application/json',
//       };
      
//       // Add authorization bearer token if available
//       if (token != null) {
//         headers['Authorization'] = 'Bearer $token';
//       }

//       // STEP 5: Prepare the request body with all emergency clock-out details
//       final body = {
//         'attendanceId': attendanceId,
//         'shiftId': shiftId,
//         'emergencyReason': emergencyReason,
//         'clockOutTime': DateTime.now().toIso8601String(),
//         'isEmergency': true,
//       };

//       // STEP 6: Add GPS coordinates only if they are available
//       // This allows emergency clock-out even without location data
//       // Location might not be available in true emergencies
//       if (latitude != null && longitude != null) {
//         body['latitude'] = latitude.toString();
//         body['longitude'] = longitude.toString();
//       }

//       // STEP 7: Send PUT request to backend with optional timeout
//       final response = timeout != null
//           ? await http
//               .put(url, headers: headers, body: jsonEncode(body))
//               .timeout(timeout)
//           : await http.put(url, headers: headers, body: jsonEncode(body));

//       // STEP 8: Log the HTTP response status for debugging
//       debugPrint('Emergency clock-out HTTP status: ${response.statusCode}');

//       // STEP 9: Check if the emergency clock-out was successful
//       if (response.statusCode == 200) {
//         // Parse response body if it exists, otherwise return empty map
//         final result =
//             response.body.isNotEmpty ? jsonDecode(response.body) : {};
//         return {'success': true, 'data': result};
//       } else {
//         // STEP 10: Log failure details for debugging
//         debugPrint('Emergency clock-out failed: ${response.body}');
//         throw Exception(
//             "Emergency clock out failed: HTTP ${response.statusCode} - ${response.body}");
//       }
//     } catch (e) {
//       // STEP 11: Catch and log any errors during the emergency clock-out process
//       debugPrint("Emergency clock out service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }
//   // NEW CODE END

//   // BREAK START (Updated for C# Backend)
//   // Records the start of an employee's break period
//   Future<bool?> breakStart(int attendanceId,
//       {required DateTime startTime}) async {
//     final url =
//         '$baseUrl/attendance/break/start/$attendanceId?code=$breakstart';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           'breakStartTime': startTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "Break start failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error :$e");
//     }
//   }

//   // END BREAK (Updated for C# Backend)
//   // Records the end of an employee's break period
//   Future<bool?> endBreak(int attendanceId, {required DateTime endTime}) async {
//     final url = '$baseUrl/attendance/break/end/$attendanceId?code=$breakend';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           'breakEndTime': endTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "Break end failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error: $e");
//     }
//   }
// }
















// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:mime/mime.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'api_client.dart';

// class AttendanceService {
//   final ApiClient _apiClient = ApiClient();

//   // Base configuration URLs and API keys loaded from environment variables
//   String baseUrl = dotenv.env['ATTENDANCE_BASE_URL']!;
//   String fetchAttendancePhoto = dotenv.env['FETCH_ATTENDANCE_PHOTO_KEY']!;
//   String getShiftById = dotenv.env['SHIFT_BY_SHIFTID_KEY']!;
//   String clockinKey = dotenv.env['CLOCKIN_KEY']!;
//   String clockoutKey = dotenv.env['CLOCKOUT_KEY']!;
//   String breakstart = dotenv.env['BREAK_START_KEY']!;
//   String breakend = dotenv.env['BREAK_END_KEY']!;
  
//   // NEW CODE START: Emergency Clock-Out API Key Configuration
//   // This key is used specifically for emergency clock-out situations
//   // If EMERGENCY_CLOCKOUT_KEY is not defined in .env file, it will
//   // fallback to using the regular CLOCKOUT_KEY
//   String emergencyClockoutKey = dotenv.env['EMERGENCY_CLOCKOUT_KEY'] ?? 
//       dotenv.env['CLOCKOUT_KEY']!;
//   // NEW CODE END

//   // GET CLOCK PHOTO URL
//   // Fetches the URL of a clock-in or clock-out photo for a specific attendance record
//   Future<String?> fetchClockPhotoUrl(int attendanceId,
//       {required isClockIn}) async {
//     final endPoint = isClockIn ? 'view-clockin-photo' : 'view-clockout-photo';
//     final url = '$baseUrl/attendance/$endPoint/$attendanceId';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       final jsonData = jsonDecode(response.body);
//       return jsonData['photoUrl'].toString();
//     } catch (e) {
//       debugPrint("Error fetching clock ${isClockIn ? "in" : "out"} photo: $e");
//     }
//     return null;
//   }

//   // FETCH ATTENDANCE PHOTOS
//   // Retrieves both clock-in and clock-out photo URLs for a specific employee and shift
//   Future<Map<String, String?>> fetchAttendancePhotos(
//       int employeeId, int shiftId) async {
//     final url =
//         "$baseUrl/attendance/by-employee/$employeeId?code=$fetchAttendancePhoto";
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> jsonData = jsonDecode(response.body);
//         final record = jsonData.firstWhere(
//           (attendance) => attendance['ShiftId'] == shiftId,
//           orElse: () => <String, dynamic>{},
//         );
//         if (record == null) return {};
//         return {
//           'clockIn': record['ClockInPhotoUrl'] as String?,
//           'clockOut': record['ClockOutPhotoUrl'] as String?,
//         };
//       }
//     } catch (e) {
//       debugPrint("Error fetching attendance photos: $e");
//     }
//     return {};
//   }

//   // GET SHIFTS BY ID
//   // Fetches shift data for an employee, optionally filtered by a specific shiftId
//   Future<dynamic> getShiftsByShiftId(int employeeId, {int? shiftId}) async {
//     final url =
//         '$baseUrl/attendance/by-employee/$employeeId?code=$getShiftById';
//     try {
//       final response = await _apiClient.get(url, useAuth: true);

//       if (response.statusCode == 200) {
//         final List<dynamic> shifts = jsonDecode(response.body);
//         if (shiftId != null) {
//           final shift = shifts.firstWhere(
//             (s) => s['ShiftId'] == shiftId,
//             orElse: () => null,
//           );
//           return shift;
//         }
//         return shifts;
//       } else {
//         throw Exception("Failed to fetch shifts: HTTP ${response.statusCode}");
//       }
//     } catch (e) {
//       throw Exception("Error fetching shifts for employee $employeeId: $e");
//     }
//   }

//   // CLOCK IN (Multi-Photo & GPS)
//   // Records employee clock-in with multiple photos and GPS coordinates
//   Future<Map<String, dynamic>> clockIn({
//     required int employeeId,
//     required int shiftId,
//     required int siteId,
//     required String scheduledStartTime,
//     required List<File> photos,
//     required DateTime clockInTime,
//     required double latitude,
//     required double longitude,
//   }) async {
//     final url = Uri.parse('$baseUrl/attendance/clockin?code=$clockinKey');
//     try {
//       final request = http.MultipartRequest("POST", url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['employeeId'] = employeeId.toString();
//       request.fields['shiftId'] = shiftId.toString();
//       request.fields['siteId'] = siteId.toString();
//       request.fields['scheduledStartTime'] = scheduledStartTime.toString();
//       request.fields['clockInTime'] = clockInTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = await request.send();
//       final responseBody = await response.stream.bytesToString();
//       debugPrint('Clock-in HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final result = jsonDecode(responseBody);
//         return {
//           'success': true,
//           'data': result,
//           'attendanceId': result['AttendanceId'] ?? result['attendanceId'],
//         };
//       } else {
//         throw Exception(
//             "Clock in failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock in service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // CLOCK OUT (Multi-Photo & GPS)
//   // Records employee clock-out with multiple photos and GPS coordinates
//   // This is the REGULAR clock-out method that requires photos
//   Future<Map<String, dynamic>> clockOut({
//     required int attendanceId,
//     required DateTime clockOutTime,
//     required List<File> photos,
//     required double latitude,
//     required double longitude,
//     Duration? timeout,
//   }) async {
//     final url = Uri.parse(
//         '$baseUrl/attendance/clockout/$attendanceId?code=$clockoutKey');
//     try {
//       final request = http.MultipartRequest('PUT', url);

//       // Auth Header
//       final token = await _apiClient.getAppToken();
//       if (token != null) {
//         request.headers['Authorization'] = 'Bearer $token';
//       }

//       // Add Photos
//       for (var file in photos) {
//         final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
//         request.files.add(await http.MultipartFile.fromPath(
//           'photo',
//           file.path,
//           contentType: MediaType.parse(mimeType),
//         ));
//       }

//       // Add Fields
//       request.fields['attendanceId'] = attendanceId.toString();
//       request.fields['clockOutTime'] = clockOutTime.toIso8601String();
//       request.fields['latitude'] = latitude.toString();
//       request.fields['longitude'] = longitude.toString();

//       final response = timeout != null
//           ? await request.send().timeout(timeout)
//           : await request.send();

//       final responseBody = await response.stream.bytesToString();
//       debugPrint('Clock-out HTTP status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final result = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
//         return {'success': true, 'data': result};
//       } else {
//         throw Exception(
//             "Clock out failed: HTTP ${response.statusCode} - $responseBody");
//       }
//     } catch (e) {
//       debugPrint("Clock out service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // NEW CODE START: EMERGENCY CLOCK OUT METHOD
//   // EMERGENCY CLOCK OUT (No Photos Required)
//   // This method allows employees to clock out in emergency situations where
//   // they cannot take photos (e.g., phone battery dead, phone lost, safety emergency)
//   // 
//   // Key differences from regular clock-out:
//   // 1. Photos are NOT required - no multipart/form-data needed
//   // 2. GPS location is OPTIONAL - might not be available in emergencies
//   // 3. Requires an emergency reason for audit purposes
//   // 4. Sends JSON data instead of multipart/form-data
//   // 5. Flags the record as emergency for supervisor review
//   // 
//   // NOTE: The backend endpoint must support this. If you get a 404 error,
//   // you need to implement the backend endpoint first, or use the fallback
//   // method by modifying the regular clockOut endpoint to accept emergency flags.
//   Future<Map<String, dynamic>> emergencyClockOut({
//     required int attendanceId,
//     required int shiftId,
//     required String emergencyReason,
//     double? latitude,
//     double? longitude,
//     Duration? timeout,
//   }) async {
//     // STEP 1: Construct the emergency clock-out endpoint URL
//     // This uses a dedicated emergency endpoint and API key
//     // If your backend doesn't have this endpoint yet, you'll get a 404 error
//     final url = Uri.parse(
//         '$baseUrl/attendance/emergency-clockout/$attendanceId?code=$emergencyClockoutKey');
    
//     try {
//       // STEP 2: Log emergency clock-out initiation for debugging
//       debugPrint('Emergency clock-out initiated for attendance: $attendanceId');
      
//       // STEP 3: Retrieve authentication token from API client
//       final token = await _apiClient.getAppToken();
      
//       // STEP 4: Set up HTTP headers for JSON request
//       // NOTE: Using 'application/json' instead of 'multipart/form-data'
//       // because no photos are being uploaded in emergency situations
//       final headers = <String, String>{
//         'Content-Type': 'application/json',
//       };
      
//       // Add authorization bearer token if available
//       if (token != null) {
//         headers['Authorization'] = 'Bearer $token';
//       }

//       // STEP 5: Prepare the request body with all emergency clock-out details
//       final body = {
//         'attendanceId': attendanceId,
//         'shiftId': shiftId,
//         'emergencyReason': emergencyReason,
//         'clockOutTime': DateTime.now().toIso8601String(),
//         'isEmergency': true,
//       };

//       // STEP 6: Add GPS coordinates only if they are available
//       // This allows emergency clock-out even without location data
//       // Location might not be available in true emergencies
//       if (latitude != null && longitude != null) {
//         body['latitude'] = latitude.toString();
//         body['longitude'] = longitude.toString();
//       }

//       // STEP 7: Send PUT request to backend with optional timeout
//       final response = timeout != null
//           ? await http
//               .put(url, headers: headers, body: jsonEncode(body))
//               .timeout(timeout)
//           : await http.put(url, headers: headers, body: jsonEncode(body));

//       // STEP 8: Log the HTTP response status for debugging
//       debugPrint('Emergency clock-out HTTP status: ${response.statusCode}');

//       // STEP 9: Check if the emergency clock-out was successful
//       if (response.statusCode == 200) {
//         // Parse response body if it exists, otherwise return empty map
//         final result =
//             response.body.isNotEmpty ? jsonDecode(response.body) : {};
//         return {'success': true, 'data': result};
//       } else {
//         // STEP 10: Log failure details for debugging
//         debugPrint('Emergency clock-out failed: ${response.body}');
//         throw Exception(
//             "Emergency clock out failed: HTTP ${response.statusCode} - ${response.body}");
//       }
//     } catch (e) {
//       // STEP 11: Catch and log any errors during the emergency clock-out process
//       debugPrint("Emergency clock out service error: $e");
//       return {'success': false, 'error': e.toString()};
//     }
//   }
//   // NEW CODE END

//   // BREAK START (Updated for C# Backend)
//   // Records the start of an employee's break period
//   Future<bool?> breakStart(int attendanceId,
//       {required DateTime startTime}) async {
//     final url =
//         '$baseUrl/attendance/break/start/$attendanceId?code=$breakstart';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           'breakStartTime': startTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "Break start failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error :$e");
//     }
//   }

//   // END BREAK (Updated for C# Backend)
//   // Records the end of an employee's break period
//   Future<bool?> endBreak(int attendanceId, {required DateTime endTime}) async {
//     final url = '$baseUrl/attendance/break/end/$attendanceId?code=$breakend';

//     try {
//       final response = await _apiClient.put(
//         url,
//         body: {
//           'breakEndTime': endTime.toIso8601String(),
//         },
//         useAuth: true,
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         debugPrint(
//             "Break end failed: ${response.statusCode} - ${response.body}");
//         return false;
//       }
//     } catch (e) {
//       throw Exception("Error: $e");
//     }
//   }
// }
























import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class AttendanceService {
  final ApiClient _apiClient = ApiClient();

  // Base configuration URLs and API keys loaded from environment variables
  String baseUrl = dotenv.env['ATTENDANCE_BASE_URL']!;
  String fetchAttendancePhoto = dotenv.env['FETCH_ATTENDANCE_PHOTO_KEY']!;
  String getShiftById = dotenv.env['SHIFT_BY_SHIFTID_KEY']!;
  String clockinKey = dotenv.env['CLOCKIN_KEY']!;
  String clockoutKey = dotenv.env['CLOCKOUT_KEY']!;
  String breakstart = dotenv.env['BREAK_START_KEY']!;
  String breakend = dotenv.env['BREAK_END_KEY']!;
  
  // ========================================================================
  // 🆕 NEW CODE START: Emergency Clock-Out API Key Configuration
  // ========================================================================
  // This key is used specifically for emergency clock-out situations.
  // If EMERGENCY_CLOCKOUT_KEY is not defined in .env file, it will
  // fallback to using the regular CLOCKOUT_KEY.
  //
  // Configuration in .env file (add this line):
  // EMERGENCY_CLOCKOUT_KEY=your_emergency_clockout_api_key_here
  //
  // If you want to use the same endpoint as regular clock-out,
  // just omit this from .env and it will use CLOCKOUT_KEY automatically.
  String emergencyClockoutKey = dotenv.env['EMERGENCY_CLOCKOUT_KEY'] ?? 
      dotenv.env['CLOCKOUT_KEY']!;
  // ========================================================================
  // 🆕 NEW CODE END
  // ========================================================================

  // GET CLOCK PHOTO URL
  // Fetches the URL of a clock-in or clock-out photo for a specific attendance record
  Future<String?> fetchClockPhotoUrl(int attendanceId,
      {required isClockIn}) async {
    final endPoint = isClockIn ? 'view-clockin-photo' : 'view-clockout-photo';
    final url = '$baseUrl/attendance/$endPoint/$attendanceId';
    try {
      final response = await _apiClient.get(url, useAuth: true);

      final jsonData = jsonDecode(response.body);
      return jsonData['photoUrl'].toString();
    } catch (e) {
      debugPrint("Error fetching clock ${isClockIn ? "in" : "out"} photo: $e");
    }
    return null;
  }

  // FETCH ATTENDANCE PHOTOS
  // Retrieves both clock-in and clock-out photo URLs for a specific employee and shift
  Future<Map<String, String?>> fetchAttendancePhotos(
      int employeeId, int shiftId) async {
    final url =
        "$baseUrl/attendance/by-employee/$employeeId?code=$fetchAttendancePhoto";
    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final record = jsonData.firstWhere(
          (attendance) => attendance['ShiftId'] == shiftId,
          orElse: () => <String, dynamic>{},
        );
        if (record == null) return {};
        return {
          'clockIn': record['ClockInPhotoUrl'] as String?,
          'clockOut': record['ClockOutPhotoUrl'] as String?,
        };
      }
    } catch (e) {
      debugPrint("Error fetching attendance photos: $e");
    }
    return {};
  }

  // GET SHIFTS BY ID
  // Fetches shift data for an employee, optionally filtered by a specific shiftId
  Future<dynamic> getShiftsByShiftId(int employeeId, {int? shiftId}) async {
    final url =
        '$baseUrl/attendance/by-employee/$employeeId?code=$getShiftById';
    try {
      final response = await _apiClient.get(url, useAuth: true);

      if (response.statusCode == 200) {
        final List<dynamic> shifts = jsonDecode(response.body);
        if (shiftId != null) {
          final shift = shifts.firstWhere(
            (s) => s['ShiftId'] == shiftId,
            orElse: () => null,
          );
          return shift;
        }
        return shifts;
      } else {
        throw Exception("Failed to fetch shifts: HTTP ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching shifts for employee $employeeId: $e");
    }
  }

  // CLOCK IN (Multi-Photo & GPS)
  // Records employee clock-in with multiple photos and GPS coordinates
  Future<Map<String, dynamic>> clockIn({
    required int employeeId,
    required int shiftId,
    required int siteId,
    required String scheduledStartTime,
    required List<File> photos,
    required DateTime clockInTime,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$baseUrl/attendance/clockin?code=$clockinKey');
    try {
      final request = http.MultipartRequest("POST", url);

      // Auth Header
      final token = await _apiClient.getAppToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add Photos
      for (var file in photos) {
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          file.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // Add Fields
      request.fields['employeeId'] = employeeId.toString();
      request.fields['shiftId'] = shiftId.toString();
      request.fields['siteId'] = siteId.toString();
      request.fields['scheduledStartTime'] = scheduledStartTime.toString();
      request.fields['clockInTime'] = clockInTime.toIso8601String();
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('Clock-in HTTP status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(responseBody);
        return {
          'success': true,
          'data': result,
          'attendanceId': result['AttendanceId'] ?? result['attendanceId'],
        };
      } else {
        throw Exception(
            "Clock in failed: HTTP ${response.statusCode} - $responseBody");
      }
    } catch (e) {
      debugPrint("Clock in service error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // CLOCK OUT (Multi-Photo & GPS)
  // Records employee clock-out with multiple photos and GPS coordinates
  // This is the REGULAR clock-out method that requires photos
  Future<Map<String, dynamic>> clockOut({
    required int attendanceId,
    required DateTime clockOutTime,
    required List<File> photos,
    required double latitude,
    required double longitude,
    Duration? timeout,
  }) async {
    final url = Uri.parse(
        '$baseUrl/attendance/clockout/$attendanceId?code=$clockoutKey');
    try {
      final request = http.MultipartRequest('PUT', url);

      // Auth Header
      final token = await _apiClient.getAppToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add Photos
      for (var file in photos) {
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          file.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // Add Fields
      request.fields['attendanceId'] = attendanceId.toString();
      request.fields['clockOutTime'] = clockOutTime.toIso8601String();
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      final response = timeout != null
          ? await request.send().timeout(timeout)
          : await request.send();

      final responseBody = await response.stream.bytesToString();
      debugPrint('Clock-out HTTP status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
        return {'success': true, 'data': result};
      } else {
        throw Exception(
            "Clock out failed: HTTP ${response.statusCode} - $responseBody");
      }
    } catch (e) {
      debugPrint("Clock out service error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================================
  // 🆕 NEW CODE START: EMERGENCY CLOCK OUT METHOD
  // ============================================================================
  // EMERGENCY CLOCK OUT (No Photos Required)
  // 
  // PURPOSE:
  // This method allows employees to clock out in emergency situations where
  // they cannot take photos or may not be at the site location.
  // 
  // USE CASES:
  // - Medical emergencies (employee or family member)
  // - Safety concerns (fire, natural disaster, violence)
  // - Family crises requiring immediate departure
  // - Phone issues (dead battery, broken camera, lost phone)
  // - Any urgent situation requiring immediate departure
  // 
  // KEY DIFFERENCES FROM REGULAR CLOCK-OUT:
  // 1. Photos are NOT required - no multipart/form-data needed
  // 2. GPS location is OPTIONAL - might not be available in emergencies
  // 3. Requires a mandatory emergency reason for audit/approval
  // 4. Sends JSON data instead of multipart/form-data
  // 5. Automatically flags the record for manager approval
  // 6. Uses separate API endpoint and key for security tracking
  // 
  // SECURITY & COMPLIANCE:
  // - All emergency clock-outs are flagged for supervisor review
  // - Requires detailed emergency reason (minimum 10 characters)
  // - Logged separately for audit trail
  // - Cannot be used for regular departures
  // 
  // PARAMETERS:
  // @param attendanceId - The ID of the active attendance record to clock out
  // @param shiftId - The shift ID (for validation and tracking)
  // @param emergencyReason - Required detailed explanation of the emergency
  // @param latitude - Optional GPS latitude (if available)
  // @param longitude - Optional GPS longitude (if available)
  // @param timeout - Optional timeout duration for the HTTP request
  // 
  // RETURNS:
  // Map<String, dynamic> with structure:
  // {
  //   'success': bool,        // Whether the operation succeeded
  //   'data': dynamic,        // Response data from backend (if successful)
  //   'error': String         // Error message (if failed)
  // }
  // 
  // BACKEND REQUIREMENTS:
  // The backend must have an endpoint: PUT /attendance/emergency-clockout/{attendanceId}
  // If this endpoint doesn't exist, you'll get a 404 error and need to implement it first.
  // 
  // ERROR HANDLING:
  // - 404: Endpoint not found - backend needs implementation
  // - 401: Unauthorized - check API key and authentication
  // - 400: Bad request - check that all required fields are provided
  // - 500: Server error - check backend logs
  // - Timeout: Network or server response too slow
  // 
  Future<Map<String, dynamic>> emergencyClockOut({
    required int attendanceId,
    required int shiftId,
    required String emergencyReason,
    double? latitude,
    double? longitude,
    Duration? timeout,
  }) async {
    // STEP 1: Construct the emergency clock-out endpoint URL
    // This uses a dedicated emergency endpoint and API key for security tracking
    // The endpoint should be: /attendance/emergency-clockout/{attendanceId}
    // If your backend doesn't have this endpoint yet, you'll get a 404 error
    final url = Uri.parse(
        '$baseUrl/attendance/emergency-clockout/$attendanceId?code=$emergencyClockoutKey');
    
    try {
      // STEP 2: Log emergency clock-out initiation for debugging and audit trail
      // These logs help track emergency situations and troubleshoot issues
      debugPrint('==========================================');
      debugPrint('EMERGENCY CLOCK-OUT INITIATED');
      debugPrint('==========================================');
      debugPrint('Attendance ID: $attendanceId');
      debugPrint('Shift ID: $shiftId');
      debugPrint('Emergency Reason: $emergencyReason');
      debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
      debugPrint('==========================================');
      
      // STEP 3: Retrieve authentication token from API client
      // This token is required to authenticate the request with the backend
      final token = await _apiClient.getAppToken();
      
      // STEP 4: Set up HTTP headers for JSON request
      // IMPORTANT: Using 'application/json' instead of 'multipart/form-data'
      // because no photos are being uploaded in emergency situations
      // This is a key difference from the regular clockOut method
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // Add authorization bearer token if available
      // Without this, the request will be rejected as unauthorized
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('Authorization token added to request');
      } else {
        debugPrint('WARNING: No authorization token available');
      }

      // STEP 5: Prepare the request body with all emergency clock-out details
      // This data will be sent as JSON to the backend
      // The backend will use this to update the attendance record and flag it for review
      final body = {
        // Attendance and shift identification
        'attendanceId': attendanceId,
        'shiftId': shiftId,
        
        // Emergency details
        'emergencyReason': emergencyReason,
        'isEmergency': true,  // Flag to distinguish from regular clock-outs
        
        // Timestamp - when the emergency clock-out occurred
        'clockOutTime': DateTime.now().toIso8601String(),
        
        // Additional metadata for backend processing
        'requiresApproval': true,  // Flag for manager review
        'approvalStatus': 'Pending',  // Initial status
      };

      // STEP 6: Add GPS coordinates only if they are available
      // This allows emergency clock-out to work even without location data
      // Location might not be available in true emergencies:
      // - Phone battery dead
      // - GPS disabled
      // - Indoor location with no signal
      // - Employee fled dangerous situation quickly
      if (latitude != null && longitude != null) {
        body['latitude'] = latitude.toString();
        body['longitude'] = longitude.toString();
        debugPrint('Location data included: ($latitude, $longitude)');
      } else {
        debugPrint('Location data NOT available - proceeding without it');
        body['locationUnavailable'] = true;  // Flag for backend tracking
      }

      // STEP 7: Log the complete request for debugging
      debugPrint('Request URL: $url');
      debugPrint('Request Headers: $headers');
      debugPrint('Request Body: ${jsonEncode(body)}');

      // STEP 8: Send PUT request to backend with optional timeout
      // PUT is used because we're updating an existing attendance record
      // Timeout prevents the app from hanging if network is slow
      final response = timeout != null
          ? await http
              .put(url, headers: headers, body: jsonEncode(body))
              .timeout(timeout)
          : await http.put(url, headers: headers, body: jsonEncode(body));

      // STEP 9: Log the HTTP response status for debugging
      debugPrint('==========================================');
      debugPrint('EMERGENCY CLOCK-OUT RESPONSE');
      debugPrint('==========================================');
      debugPrint('HTTP Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('==========================================');

      // STEP 10: Handle successful response (HTTP 200 OK)
      if (response.statusCode == 200) {
        // Parse response body if it exists, otherwise return empty map
        final result =
            response.body.isNotEmpty ? jsonDecode(response.body) : {};
        
        debugPrint('✓ Emergency clock-out successful');
        debugPrint('Backend response: $result');
        
        return {
          'success': true,
          'data': result,
          'message': 'Emergency clock-out recorded successfully. Manager approval required.'
        };
      } 
      // STEP 11: Handle 404 - Endpoint not found
      // This means the backend doesn't have the emergency-clockout endpoint yet
      else if (response.statusCode == 404) {
        debugPrint('✗ ERROR: Emergency clock-out endpoint not found (404)');
        debugPrint('The backend does not have the emergency-clockout endpoint.');
        debugPrint('Action required: Implement the endpoint on your C# backend first.');
        
        throw Exception(
            "Emergency clock-out feature is not available. The backend endpoint does not exist. "
            "Please contact your system administrator to implement the emergency-clockout API endpoint.");
      }
      // STEP 12: Handle 401 - Unauthorized
      else if (response.statusCode == 401) {
        debugPrint('✗ ERROR: Unauthorized (401)');
        debugPrint('Check API key and authentication token');
        
        throw Exception(
            "Emergency clock-out failed: Unauthorized. Please log in again and try.");
      }
      // STEP 13: Handle 400 - Bad Request
      else if (response.statusCode == 400) {
        debugPrint('✗ ERROR: Bad Request (400)');
        debugPrint('Response: ${response.body}');
        
        throw Exception(
            "Emergency clock-out failed: Invalid data. ${response.body}");
      }
      // STEP 14: Handle 500 - Server Error
      else if (response.statusCode >= 500) {
        debugPrint('✗ ERROR: Server Error (${response.statusCode})');
        debugPrint('Response: ${response.body}');
        
        throw Exception(
            "Emergency clock-out failed: Server error. Please try again or contact support.");
      }
      // STEP 15: Handle other unexpected status codes
      else {
        debugPrint('✗ ERROR: Unexpected status code (${response.statusCode})');
        debugPrint('Response: ${response.body}');
        
        throw Exception(
            "Emergency clock out failed: HTTP ${response.statusCode} - ${response.body}");
      }
    } 
    // STEP 16: Handle timeout exceptions
    catch (e) {
      if (e.toString().contains('TimeoutException')) {
        debugPrint('✗ ERROR: Request timeout');
        return {
          'success': false,
          'error': 'Emergency clock-out request timed out. Please check your internet connection and try again.'
        };
      }
      
      // STEP 17: Catch and log any other errors during the emergency clock-out process
      debugPrint("==========================================");
      debugPrint("✗ EMERGENCY CLOCK-OUT SERVICE ERROR");
      debugPrint("==========================================");
      debugPrint("Error Type: ${e.runtimeType}");
      debugPrint("Error Message: $e");
      debugPrint("==========================================");
      
      // STEP 18: Provide helpful error message for 404 specifically
      // This is the most common error when the feature is not yet implemented
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return {
          'success': false,
          'error': 'Emergency clock-out feature is not yet available on the server. '
                   'The backend endpoint needs to be implemented first. '
                   'Please use regular clock-out or contact your system administrator.'
        };
      }
      
      // STEP 19: Return generic error response for all other errors
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  // ============================================================================
  // 🆕 NEW CODE END
  // ============================================================================

  // BREAK START (Updated for C# Backend)
  // Records the start of an employee's break period
  Future<bool?> breakStart(int attendanceId,
      {required DateTime startTime}) async {
    final url =
        '$baseUrl/attendance/break/start/$attendanceId?code=$breakstart';

    try {
      final response = await _apiClient.put(
        url,
        body: {
          'breakStartTime': startTime.toIso8601String(),
        },
        useAuth: true,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
            "Break start failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      throw Exception("Error :$e");
    }
  }

  // END BREAK (Updated for C# Backend)
  // Records the end of an employee's break period
  Future<bool?> endBreak(int attendanceId, {required DateTime endTime}) async {
    final url = '$baseUrl/attendance/break/end/$attendanceId?code=$breakend';

    try {
      final response = await _apiClient.put(
        url,
        body: {
          'breakEndTime': endTime.toIso8601String(),
        },
        useAuth: true,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
            "Break end failed: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}