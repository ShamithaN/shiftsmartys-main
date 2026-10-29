// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shiftsmart/models/Job.dart';
// import 'package:shiftsmart/models/Site.dart';
// import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
// import 'package:shiftsmart/services/AttendanceService.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/ImagePickerService.dart';
// import 'package:shiftsmart/services/LocationService.dart';
// import 'package:shiftsmart/services/ShiftService.dart';
// import 'package:shiftsmart/services/SiteService.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';

// class Employeeshiftview extends StatefulWidget {
//   final Job job;
//   final int shiftId;
//   final int employeeId;
//   final String scheduledStartTime;
//   final String scheduledEndTime;
//   final LocationService locationService;
//   final ImagePickerService imagePickerService;

//   const Employeeshiftview({
//     super.key,
//     required this.job,
//     required this.shiftId,
//     required this.employeeId,
//     required this.scheduledStartTime,
//     required this.scheduledEndTime,
//     required this.locationService,
//     required this.imagePickerService,
//   });

//   @override
//   State<Employeeshiftview> createState() => _EmployeeshiftviewState();
// }

// class _EmployeeshiftviewState extends State<Employeeshiftview> {
//   List<Map<String, DateTime>> breaks = [];
//   Map<String, dynamic>? shiftDetails;
//   StreamSubscription<Position>? _positionStreamSubscription;
//   DateTime? currentBreakStart;
//   DateTime? clockInTime;
//   DateTime? clockOutTime;
//   bool isClockedIn = false;
//   File? clockInPhoto;
//   File? clockOutPhoto;
//   int? attendanceId;
//   Site? currentSite;
//   bool isLoading = false;

//   // New Variables
//   String myStatus = "Pending";
//   String? myRejectionReason;
//   bool isActionLoading = false;
//   List<File> _capturedPhotos = [];

//   final SiteService _siteService = SiteService();
//   final AttendanceService _attendanceService = AttendanceService();
//   final ShiftService _shiftService = ShiftService();
//   final LocationService _locationService = RealLocationService();

//   final Color green = const Color.fromARGB(255, 1, 126, 42);
//   static const Duration networkTimeout = Duration(seconds: 30);

//   // --- Helpers ---

//   String formatTime(String timeString) {
//     try {
//       final time = TimeOfDay(
//         hour: int.parse(timeString.split(':')[0]),
//         minute: int.parse(timeString.split(':')[1]),
//       );
//       return time.format(context);
//     } catch (e) {
//       return timeString;
//     }
//   }

//   DateTime _getScheduledEndDateTime() {
//     final now = DateTime.now();
//     try {
//       String timeStr = widget.scheduledEndTime.trim();
//       int hour = 0;
//       int minute = 0;

//       if (timeStr.toLowerCase().contains("pm") ||
//           timeStr.toLowerCase().contains("am")) {
//         if (timeStr.split(':').length > 2) {
//           timeStr =
//               "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
//         }
//         final dt = DateFormat("h:mm a").parse(timeStr);
//         hour = dt.hour;
//         minute = dt.minute;
//       } else {
//         final parts = timeStr.split(':');
//         hour = int.parse(parts[0]);
//         minute = int.parse(parts[1]);
//       }
//       return DateTime(now.year, now.month, now.day, hour, minute);
//     } catch (e) {
//       debugPrint("⚠️ Date Parsing Error: $e");
//       return DateTime.now();
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadSiteData();
//     _loadShiftDetailsAndStatus();
//     _loadShiftProgress();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     if (mounted) _disposePhotos();
//     super.dispose();
//   }

//   void _disposePhotos() {
//     clockInPhoto = null;
//     clockOutPhoto = null;
//   }

//   Future<void> _loadShiftDetailsAndStatus() async {
//     try {
//       final myShifts =
//           await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
//       final shift = myShifts.firstWhere(
//         (s) => s['ShiftId'] == widget.shiftId,
//         orElse: () => {},
//       );

//       if (shift.isNotEmpty && mounted) {
//         setState(() {
//           shiftDetails = shift;
//           myStatus = shift['MyStatus'] ?? "Pending";
//           myRejectionReason = shift['MyRejectionReason'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading shift details & status: $e');
//     }
//   }

//   // --- Actions ---

//   Future<void> _handleAccept() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success =
//           await _shiftService.respondToShift(widget.shiftId, "Accept");
//       if (success) {
//         setState(() => myStatus = "Accepted");
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
//       }
//     } catch (e) {
//       debugPrint("Error accepting shift: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _handleDecline() async {
//     TextEditingController reasonCtrl = TextEditingController();
//     showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Decline Shift",
//                   style: TextStyle(color: Colors.white)),
//               content: TextField(
//                 controller: reasonCtrl,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Reason (Required)",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: Colors.white54)),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel")),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () async {
//                     if (reasonCtrl.text.isEmpty) return;
//                     Navigator.pop(ctx);
//                     setState(() => isActionLoading = true);
//                     bool success = await _shiftService.respondToShift(
//                         widget.shiftId, "Decline",
//                         reason: reasonCtrl.text);
//                     if (success) setState(() => myStatus = "Declined");
//                     setState(() => isActionLoading = false);
//                   },
//                   child: const Text("Decline"),
//                 )
//               ],
//             ));
//   }

//   Future<void> _handleSwapRequest() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success = await _shiftService.requestSwap(widget.shiftId);
//       if (success) {
//         setState(() => myStatus = "Swap Requested");
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Swap Requested Successfully")));
//       }
//     } catch (e) {
//       debugPrint("Error requesting swap: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _loadSiteData() async {
//     setState(() => isLoading = true);
//     try {
//       if (widget.job.siteId == 0 || widget.job.siteId == null) return;
//       final site = await _siteService.fetchSiteById(widget.job.siteId!);
//       if (site != null) currentSite = site;
//     } catch (e) {
//       debugPrint('Error loading site data: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // --- UPDATED: Properly syncs Break Status from Server ---
//   Future<void> _loadShiftProgress() async {
//     // 1. Load Local Data (Prevents flickering)
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = prefs.getString(key);

//     if (progressData != null) {
//       final progress = jsonDecode(progressData);
//       if (mounted) {
//         setState(() {
//           clockInTime = progress['clockInTime'] != null
//               ? DateTime.parse(progress['clockInTime'])
//               : null;
//           clockOutTime = progress['clockOutTime'] != null
//               ? DateTime.parse(progress['clockOutTime'])
//               : null;
//           if (progress['breaks'] != null) {
//             breaks = (progress['breaks'] as List<dynamic>).map((b) {
//               return {
//                 'start': DateTime.parse(b['start']),
//                 'end': DateTime.parse(b['end']),
//               };
//             }).toList();
//           }
//           if (progress['currentBreakStart'] != null) {
//             currentBreakStart =
//                 DateTime.tryParse(progress['currentBreakStart']);
//           }
//           attendanceId = progress['attendanceId'];
//         });
//       }
//     }

//     try {
//       // 2. Fetch Latest Status from Server
//       final shift = await _attendanceService.getShiftsByShiftId(
//           widget.employeeId,
//           shiftId: widget.shiftId) as Map<String, dynamic>?;

//       if (shift != null && mounted) {
//         // --- Parse Backend Times ---
//         final backendClockInTime = shift['ClockInTime'] != null
//             ? DateTime.tryParse(shift['ClockInTime'])
//             : null;
//         final backendClockOutTime = shift['ClockOutTime'] != null
//             ? DateTime.tryParse(shift['ClockOutTime'])
//             : null;

//         // --- NEW: Parse Backend Break Times ---
//         final backendBreakStart = shift['BreakStart'] != null
//             ? DateTime.tryParse(shift['BreakStart'])
//             : null;
//         final backendBreakEnd = shift['BreakEnd'] != null
//             ? DateTime.tryParse(shift['BreakEnd'])
//             : null;

//         if (mounted) {
//           setState(() {
//             // Sync Clock In
//             if (backendClockInTime != null) {
//               if (attendanceId == null || clockInTime == null) {
//                 clockInTime = backendClockInTime;
//                 attendanceId = shift['AttendanceId'];
//               }
//             }

//             // Sync Clock Out
//             if (backendClockOutTime != null &&
//                 backendClockOutTime.year > 1900) {
//               clockOutTime = backendClockOutTime;
//             }

//             // --- Sync Break Status ---
//             if (backendBreakStart != null) {
//               // Active Break
//               if (backendBreakEnd == null) {
//                 currentBreakStart = backendBreakStart;
//               }
//               // Finished Break
//               else {
//                 currentBreakStart = null;
//                 // Add to history if unique
//                 bool exists = breaks.any((b) =>
//                     b['start']!.isAtSameMomentAs(backendBreakStart) &&
//                     b['end']!.isAtSameMomentAs(backendBreakEnd!));

//                 if (!exists) {
//                   breaks.add({
//                     'start': backendBreakStart,
//                     'end': backendBreakEnd,
//                   });
//                 }
//               }
//             }
//           });

//           _saveShiftProgress();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching shift status: $e');
//     }
//   }

//   Future<void> _saveShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = {
//       'clockInTime': clockInTime?.toIso8601String(),
//       'clockOutTime': clockOutTime?.toIso8601String(),
//       'breaks': breaks
//           .map((b) => {
//                 'start': b['start']!.toIso8601String(),
//                 'end': b['end']!.toIso8601String()
//               })
//           .toList(),
//       'currentBreakStart': currentBreakStart?.toIso8601String(),
//       'attendanceId': attendanceId,
//     };
//     await prefs.setString(key, jsonEncode(progressData));
//   }

//   Future<bool> _checkLocationPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission != LocationPermission.denied &&
//         permission != LocationPermission.deniedForever;
//   }

//   Future<bool> _validateGeofence() async {
//     if (currentSite == null) return false;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 5),
//       );
//       final siteLat = double.tryParse(currentSite!.latitude ?? '');
//       final siteLng = double.tryParse(currentSite!.longitude ?? '');

//       if (siteLat == null || siteLng == null) return false;

//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         siteLat,
//         siteLng,
//       );
//       return distance <= (currentSite!.radius ?? 150);
//     } catch (e) {
//       debugPrint("Geofence Check Failed: $e");
//       return false;
//     }
//   }

//   Future<bool> _capturePhotos() async {
//     _capturedPhotos.clear();
//     bool done = false;

//     while (!done && _capturedPhotos.length < 5) {
//       final shouldAdd = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: Text("Add Photo (${_capturedPhotos.length}/5)",
//               style: const TextStyle(color: Colors.white)),
//           content: const Text("You must take at least one photo.",
//               style: TextStyle(color: Colors.white70)),
//           actions: [
//             if (_capturedPhotos.isNotEmpty)
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false), // Done
//                 child: const Text("Done", style: TextStyle(color: Colors.blue)),
//               ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.pop(ctx, true), // Add Photo
//               child: const Text("Take Photo"),
//             ),
//           ],
//         ),
//       );

//       if (shouldAdd == true) {
//         final File? photo = await widget.imagePickerService.pickImage();
//         if (photo != null) {
//           setState(() {
//             _capturedPhotos.add(File(photo.path));
//           });
//         }
//       } else {
//         done = true;
//       }
//     }
//     return _capturedPhotos.isNotEmpty;
//   }

//   Future<void> _clearOldShiftData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     await prefs.remove(key);
//     _capturedPhotos.clear();
//     if (mounted) {
//       setState(() {
//         clockInTime = null;
//         clockOutTime = null;
//         breaks.clear();
//         currentBreakStart = null;
//         attendanceId = null;
//       });
//     }
//   }

//   // --- CLOCK IN (Strict Geofence + GPS + Multi-Photo) ---
//   Future<void> _handleClockIn() async {
//     if (mounted) setState(() => isLoading = true);
//     try {
//       if (!await _checkLocationPermission()) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Location permission is required.')));
//           setState(() => isLoading = false);
//         }
//         return;
//       }

//       // 🛑 STRICT CHECK: Validate Geofence BEFORE anything else
//       bool inRange = await _validateGeofence();
//       if (!inRange) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           // Show strict warning dialog
//           showDialog(
//             context: context,
//             builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Out of Range",
//                   style: TextStyle(color: Colors.redAccent)),
//               content: const Text(
//                 "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
//                 style: TextStyle(color: Colors.white70),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text("OK"),
//                 ),
//               ],
//             ),
//           );
//         }
//         return;
//       }

//       // 1. Capture Photos (Only if in range)
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final now = DateTime.now();

//       final result = await _attendanceService.clockIn(
//         employeeId: widget.employeeId,
//         shiftId: widget.shiftId,
//         siteId: widget.job.siteId ?? 0,
//         scheduledStartTime: widget.scheduledStartTime,
//         photos: _capturedPhotos,
//         clockInTime: now,
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );

//       if (result['success']) {
//         final attendanceIdFromResponse = result['attendanceId'];
//         if (mounted) {
//           setState(() {
//             clockInTime = now;
//             attendanceId = attendanceIdFromResponse;
//             clockInPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         await _saveShiftProgress();
//         await _sendEmployeeLocation(position);
//         _startLocationTracking();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Clock-in successful!')));
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-in error');
//       }
//     } catch (e) {
//       debugPrint('Clock-in error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   void _startLocationTracking() async {
//     final locationSettings =
//         LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
//     _positionStreamSubscription =
//         Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((Position position) async {
//       await _sendEmployeeLocation(position);
//     });
//   }

//   Future<void> _sendEmployeeLocation(Position position) async {
//     try {
//       await _locationService.sendLocation(position, widget.employeeId);
//     } catch (e) {
//       debugPrint(" Error sending employee location: $e");
//     }
//   }

//   Widget _buildDebugButton() {
//     return ElevatedButton(
//       onPressed: _clearOldShiftData,
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//       child: const Text('Clear Old Data'),
//     );
//   }

//   // --- CLOCK OUT (Early Warning & Multi-Photo) ---
//   Future<void> _handleClockOut() async {
//     if (attendanceId == null) return;

//     final now = DateTime.now();
//     final scheduledEnd = _getScheduledEndDateTime();

//     // 🛑 CHECK: Is it Early Departure?
//     bool isEarly =
//         now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

//     if (isEarly) {
//       bool? confirmEarly = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: const Text("Early Departure Warning",
//               style: TextStyle(color: Colors.orangeAccent)),
//           content: const Text(
//             "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false), // No
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               onPressed: () => Navigator.pop(ctx, true), // Yes
//               child: const Text("Yes, Clock Out Early"),
//             ),
//           ],
//         ),
//       );

//       if (confirmEarly != true) return; // User cancelled
//     }

//     if (mounted) setState(() => isLoading = true);

//     try {
//       // 1. Capture Photos
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       // 2. Call Service
//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: _capturedPhotos,
//         latitude: position.latitude,
//         longitude: position.longitude,
//         timeout: networkTimeout,
//       );

//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
//         await NotificationService()
//             .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
//         await _saveShiftProgress();

//         if (mounted) {
//           if (isEarly) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               backgroundColor: Colors.orange[800],
//               content: const Text(
//                   '⚠ Early Departure Recorded. You clocked out early.'),
//             ));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('✅ Clock-out successful!')));
//           }
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // --- UPDATED: Fix for Timezone Issue (Break Start) ---
//   Future<void> _handleBreakStart() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       // 1. Capture Local Time
//       final now = DateTime.now();

//       // 2. Send 'now' to the service
//       final result =
//           await _attendanceService.breakStart(attendanceId!, startTime: now);

//       if (result == true) {
//         if (mounted) setState(() => currentBreakStart = now);
//         await _saveShiftProgress();
//         if (mounted) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break started!')));
//         }
//       }
//     } catch (e) {
//       debugPrint('Break start error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // --- UPDATED: Fix for Timezone Issue (Break End) ---
//   Future<void> _handleBreakEnd() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       // 1. Capture Local Time
//       final now = DateTime.now();

//       // 2. Send 'now' to the service
//       final result =
//           await _attendanceService.endBreak(attendanceId!, endTime: now);

//       if (result == true) {
//         if (mounted) {
//           setState(() {
//             if (currentBreakStart != null) {
//               breaks.add({'start': currentBreakStart!, 'end': now});
//               currentBreakStart = null;
//             }
//           });
//         }
//         await _saveShiftProgress();
//         if (mounted)
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break ended!')));
//       }
//     } catch (e) {
//       debugPrint('Break end error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const Sidenav(),
//       appBar: Uppernavbar(showBackButton: true),
//       body: Stack(
//         children: [
//           Background(),
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Gradienthorizontal(
//                     width: MediaQuery.of(context).size.width,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           _buildShiftInfoCard(),
//                           const SizedBox(height: 24),
//                           if (isActionLoading)
//                             const CircularProgressIndicator()
//                           else if (myStatus == "Pending")
//                             _buildAcknowledgementCard()
//                           else if (myStatus == "Declined")
//                             _buildStatusMessage(
//                                 "⛔ You have declined this shift.", Colors.red)
//                           else if (myStatus == "Swap Requested")
//                             _buildStatusMessage(
//                                 "🔄 Swap Requested. Waiting for approval.",
//                                 Colors.orange)
//                           else if (myStatus == "Accepted")
//                             _buildTimeTrackingCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTrackingButton() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 16),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           if (currentSite != null) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EmployeeTrackingScreen(
//                   currentSite: currentSite!,
//                   employeeId: widget.employeeId,
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Site location not available.")),
//             );
//           }
//         },
//         icon: const Icon(Icons.map, color: Colors.white),
//         label: const Text("View Live Location Map",
//             style: TextStyle(color: Colors.white)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blueAccent,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   Widget _buildAcknowledgementCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
//       ),
//       child: Column(
//         children: [
//           const Text(
//             "Shift Acknowledgment",
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Please accept this shift to start tracking time.",
//             style: TextStyle(color: Colors.white70),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleDecline,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent),
//                   child: const Text("Decline"),
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleAccept,
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Accept"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           TextButton.icon(
//             onPressed: _handleSwapRequest,
//             icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
//             label: const Text("Request Swap",
//                 style: TextStyle(color: Colors.orangeAccent)),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusMessage(String msg, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         msg,
//         style:
//             TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   Widget _buildShiftInfoCard() {
//     final date = shiftDetails?['Date'];
//     final formattedDate = date != null
//         ? DateFormat.yMMMMd().format(DateTime.parse(date))
//         : 'Loading...';
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.job.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           shiftDetails?['TaskName'] ?? 'Loading...',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Icon(Icons.calendar_month_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Date: $formattedDate',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Start: ${formatTime(widget.scheduledStartTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'End: ${formatTime(widget.scheduledEndTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         if (currentSite != null) ...[
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on,
//                   color: Colors.white.withOpacity(0.9), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   currentSite!.siteName,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.9), fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildTimeTrackingCard() {
//     if (attendanceId == null && clockInTime != null) {
//       _buildDebugButton();
//     }

//     final isBreakEnabled = clockInTime != null && clockOutTime == null;

//     bool isEarlyDeparture = false;
//     if (clockOutTime != null) {
//       final scheduledEnd = _getScheduledEndDateTime();
//       isEarlyDeparture = clockOutTime!
//           .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
//     }

//     return Container(
//       child: Column(
//         children: [
//           Container(width: double.infinity),
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 if (clockOutTime != null) ...[
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: isEarlyDeparture
//                           ? Colors.orange.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isEarlyDeparture
//                             ? Colors.orange.withOpacity(0.5)
//                             : Colors.green.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           isEarlyDeparture
//                               ? Icons.warning_amber_rounded
//                               : Icons.check_circle,
//                           color:
//                               isEarlyDeparture ? Colors.orange : Colors.green,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'Early Departure'
//                                     : 'Shift Completed!',
//                                 style: TextStyle(
//                                   color: isEarlyDeparture
//                                       ? Colors.orange
//                                       : Colors.green,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
//                                     : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//                 if (clockOutTime == null) ...[
//                   _buildTimeTrackingItem(
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime,
//                     clockInTime == null ? Icons.login : Icons.logout,
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime == null
//                         ? () => _handleClockIn()
//                         : () => _handleClockOut(),
//                     isEnabled: clockOutTime == null,
//                     photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
//                   ),
//                 ] else
//                   _buildTimeTrackingItem(
//                     "Clock Out",
//                     clockOutTime,
//                     Icons.logout,
//                     "Shift Completed",
//                     () {},
//                     isEnabled: false,
//                     photo: clockOutPhoto,
//                   ),
//                 const SizedBox(height: 16),
//                 if (clockInTime != null && clockOutTime == null) ...[
//                   if (currentBreakStart == null)
//                     _buildTimeTrackingItem(
//                       "Start Break",
//                       null,
//                       Icons.free_breakfast,
//                       "Start Break",
//                       _handleBreakStart,
//                       isEnabled: isBreakEnabled,
//                     )
//                   else
//                     // 🔴 UPDATED: End Break Button with Distinct Color
//                     _buildTimeTrackingItem(
//                       "End Break",
//                       currentBreakStart,
//                       Icons.task_alt,
//                       "End Break",
//                       _handleBreakEnd,
//                       isEnabled: isBreakEnabled,
//                       customButtonColor: Colors.orangeAccent, // Changed color
//                       customTextColor: Colors.black,
//                     ),
//                   const SizedBox(height: 16),
//                   _buildLiveTrackingButton(),
//                   const SizedBox(height: 16),
//                 ],
//                 if (breaks.isNotEmpty) ...[
//                   _buildBreakHistory(),
//                   const SizedBox(height: 16),
//                 ],
//                 if (clockOutTime != null) ...[
//                   _buildShiftSummary(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildShiftSummary() {
//     if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

//     final duration = clockOutTime!.difference(clockInTime!);
//     if (duration.isNegative) {
//       return const Text(
//         '⚠ Shift times are invalid (Clock-out before Clock-in)',
//         style: TextStyle(color: Colors.redAccent, fontSize: 14),
//       );
//     }

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.access_time, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Shift Summary',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.login, color: Colors.green, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.logout, color: Colors.red, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.schedule, color: Colors.blue, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Total Time: ${hours}h ${minutes}m',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           if (breaks.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Breaks Taken: ${breaks.length}',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeTrackingItem(
//     String label,
//     DateTime? time,
//     IconData icon,
//     String buttonText,
//     VoidCallback onPressed, {
//     bool? isEnabled,
//     File? photo,
//     Color? customButtonColor,
//     Color? customTextColor,
//   }) {
//     final isRecorded = time != null;
//     final buttonEnabled = isEnabled ?? !isRecorded;

//     // Use custom color if provided, else logic
//     final isRedButton = buttonText.toLowerCase().contains("out") ||
//         buttonText.toLowerCase().contains("end");

//     final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
//     final textColor = customTextColor ?? Colors.white;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500),
//               ),
//               const Spacer(),
//               Text(
//                 time != null
//                     ? DateFormat('hh:mm:ss a').format(time)
//                     : "Time: 00:00:00",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               onPressed: buttonEnabled ? onPressed : null,
//               icon: Icon(
//                 buttonText == "Completed" ? Icons.check_circle : icon,
//                 size: 20,
//                 color: buttonEnabled ? textColor : null,
//               ),
//               label: Text(
//                 buttonText,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: buttonEnabled ? textColor : null,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
//                 foregroundColor: textColor,
//                 disabledForegroundColor: Colors.white.withOpacity(0.6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBreakHistory() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Break History',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...breaks.map((breakItem) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Icon(Icons.circle, color: Colors.white70, size: 8),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }












// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shiftsmart/models/Job.dart';
// import 'package:shiftsmart/models/Site.dart';
// import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
// import 'package:shiftsmart/services/AttendanceService.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/ImagePickerService.dart';
// import 'package:shiftsmart/services/LocationService.dart';
// import 'package:shiftsmart/services/ShiftService.dart';
// import 'package:shiftsmart/services/SiteService.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';

// class Employeeshiftview extends StatefulWidget {
//   final Job job;
//   final int shiftId;
//   final int employeeId;
//   final String scheduledStartTime;
//   final String scheduledEndTime;
//   final LocationService locationService;
//   final ImagePickerService imagePickerService;

//   const Employeeshiftview({
//     super.key,
//     required this.job,
//     required this.shiftId,
//     required this.employeeId,
//     required this.scheduledStartTime,
//     required this.scheduledEndTime,
//     required this.locationService,
//     required this.imagePickerService,
//   });

//   @override
//   State<Employeeshiftview> createState() => _EmployeeshiftviewState();
// }

// class _EmployeeshiftviewState extends State<Employeeshiftview> {
//   List<Map<String, DateTime>> breaks = [];
//   Map<String, dynamic>? shiftDetails;
//   StreamSubscription<Position>? _positionStreamSubscription;
//   DateTime? currentBreakStart;
//   DateTime? clockInTime;
//   DateTime? clockOutTime;
//   bool isClockedIn = false;
//   File? clockInPhoto;
//   File? clockOutPhoto;
//   int? attendanceId;
//   Site? currentSite;
//   bool isLoading = false;

//   // New Variables
//   String myStatus = "Pending";
//   String? myRejectionReason;
//   bool isActionLoading = false;
//   List<File> _capturedPhotos = [];

//   final SiteService _siteService = SiteService();
//   final AttendanceService _attendanceService = AttendanceService();
//   final ShiftService _shiftService = ShiftService();
//   final LocationService _locationService = RealLocationService();

//   final Color green = const Color.fromARGB(255, 1, 126, 42);
//   static const Duration networkTimeout = Duration(seconds: 30);

//   // --- Helpers ---

//   String formatTime(String timeString) {
//     try {
//       final time = TimeOfDay(
//         hour: int.parse(timeString.split(':')[0]),
//         minute: int.parse(timeString.split(':')[1]),
//       );
//       return time.format(context);
//     } catch (e) {
//       return timeString;
//     }
//   }

//   DateTime _getScheduledEndDateTime() {
//     final now = DateTime.now();
//     try {
//       String timeStr = widget.scheduledEndTime.trim();
//       int hour = 0;
//       int minute = 0;

//       if (timeStr.toLowerCase().contains("pm") ||
//           timeStr.toLowerCase().contains("am")) {
//         if (timeStr.split(':').length > 2) {
//           timeStr =
//               "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
//         }
//         final dt = DateFormat("h:mm a").parse(timeStr);
//         hour = dt.hour;
//         minute = dt.minute;
//       } else {
//         final parts = timeStr.split(':');
//         hour = int.parse(parts[0]);
//         minute = int.parse(parts[1]);
//       }
//       return DateTime(now.year, now.month, now.day, hour, minute);
//     } catch (e) {
//       debugPrint("⚠️ Date Parsing Error: $e");
//       return DateTime.now();
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadSiteData();
//     _loadShiftDetailsAndStatus();
//     _loadShiftProgress();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     if (mounted) _disposePhotos();
//     super.dispose();
//   }

//   void _disposePhotos() {
//     clockInPhoto = null;
//     clockOutPhoto = null;
//   }

//   Future<void> _loadShiftDetailsAndStatus() async {
//     try {
//       final myShifts =
//           await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
//       final shift = myShifts.firstWhere(
//         (s) => s['ShiftId'] == widget.shiftId,
//         orElse: () => {},
//       );

//       if (shift.isNotEmpty && mounted) {
//         setState(() {
//           shiftDetails = shift;
//           myStatus = shift['MyStatus'] ?? "Pending";
//           myRejectionReason = shift['MyRejectionReason'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading shift details & status: $e');
//     }
//   }

//   // --- Actions ---

//   Future<void> _handleAccept() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success =
//           await _shiftService.respondToShift(widget.shiftId, "Accept");
//       if (success) {
//         setState(() => myStatus = "Accepted");
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
//       }
//     } catch (e) {
//       debugPrint("Error accepting shift: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _handleDecline() async {
//     TextEditingController reasonCtrl = TextEditingController();
//     showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Decline Shift",
//                   style: TextStyle(color: Colors.white)),
//               content: TextField(
//                 controller: reasonCtrl,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Reason (Required)",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: Colors.white54)),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel")),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () async {
//                     if (reasonCtrl.text.isEmpty) return;
//                     Navigator.pop(ctx);
//                     setState(() => isActionLoading = true);
//                     bool success = await _shiftService.respondToShift(
//                         widget.shiftId, "Decline",
//                         reason: reasonCtrl.text);
//                     if (success) setState(() => myStatus = "Declined");
//                     setState(() => isActionLoading = false);
//                   },
//                   child: const Text("Decline"),
//                 )
//               ],
//             ));
//   }

//   Future<void> _handleSwapRequest() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success = await _shiftService.requestSwap(widget.shiftId);
//       if (success) {
//         setState(() => myStatus = "Swap Requested");
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Swap Requested Successfully")));
//       }
//     } catch (e) {
//       debugPrint("Error requesting swap: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _loadSiteData() async {
//     setState(() => isLoading = true);
//     try {
//       if (widget.job.siteId == 0 || widget.job.siteId == null) return;
//       final site = await _siteService.fetchSiteById(widget.job.siteId!);
//       if (site != null) currentSite = site;
//     } catch (e) {
//       debugPrint('Error loading site data: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // --- UPDATED: Properly syncs Break Status from Server ---
//   Future<void> _loadShiftProgress() async {
//     // 1. Load Local Data (Prevents flickering)
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = prefs.getString(key);

//     if (progressData != null) {
//       final progress = jsonDecode(progressData);
//       if (mounted) {
//         setState(() {
//           clockInTime = progress['clockInTime'] != null
//               ? DateTime.parse(progress['clockInTime'])
//               : null;
//           clockOutTime = progress['clockOutTime'] != null
//               ? DateTime.parse(progress['clockOutTime'])
//               : null;
//           if (progress['breaks'] != null) {
//             breaks = (progress['breaks'] as List<dynamic>).map((b) {
//               return {
//                 'start': DateTime.parse(b['start']),
//                 'end': DateTime.parse(b['end']),
//               };
//             }).toList();
//           }
//           if (progress['currentBreakStart'] != null) {
//             currentBreakStart =
//                 DateTime.tryParse(progress['currentBreakStart']);
//           }
//           attendanceId = progress['attendanceId'];
//         });
//       }
//     }

//     try {
//       // 2. Fetch Latest Status from Server
//       final shift = await _attendanceService.getShiftsByShiftId(
//           widget.employeeId,
//           shiftId: widget.shiftId) as Map<String, dynamic>?;

//       if (shift != null && mounted) {
//         // --- Parse Backend Times ---
//         final backendClockInTime = shift['ClockInTime'] != null
//             ? DateTime.tryParse(shift['ClockInTime'])
//             : null;
//         final backendClockOutTime = shift['ClockOutTime'] != null
//             ? DateTime.tryParse(shift['ClockOutTime'])
//             : null;

//         // --- NEW: Parse Backend Break Times ---
//         final backendBreakStart = shift['BreakStart'] != null
//             ? DateTime.tryParse(shift['BreakStart'])
//             : null;
//         final backendBreakEnd = shift['BreakEnd'] != null
//             ? DateTime.tryParse(shift['BreakEnd'])
//             : null;

//         if (mounted) {
//           setState(() {
//             // Sync Clock In
//             if (backendClockInTime != null) {
//               if (attendanceId == null || clockInTime == null) {
//                 clockInTime = backendClockInTime;
//                 attendanceId = shift['AttendanceId'];
//               }
//             }

//             // Sync Clock Out
//             if (backendClockOutTime != null &&
//                 backendClockOutTime.year > 1900) {
//               clockOutTime = backendClockOutTime;
//             }

//             // --- Sync Break Status ---
//             if (backendBreakStart != null) {
//               // Active Break
//               if (backendBreakEnd == null) {
//                 currentBreakStart = backendBreakStart;
//               }
//               // Finished Break
//               else {
//                 currentBreakStart = null;
//                 // Add to history if unique
//                 bool exists = breaks.any((b) =>
//                     b['start']!.isAtSameMomentAs(backendBreakStart) &&
//                     b['end']!.isAtSameMomentAs(backendBreakEnd!));

//                 if (!exists) {
//                   breaks.add({
//                     'start': backendBreakStart,
//                     'end': backendBreakEnd,
//                   });
//                 }
//               }
//             }
//           });

//           _saveShiftProgress();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching shift status: $e');
//     }
//   }

//   Future<void> _saveShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = {
//       'clockInTime': clockInTime?.toIso8601String(),
//       'clockOutTime': clockOutTime?.toIso8601String(),
//       'breaks': breaks
//           .map((b) => {
//                 'start': b['start']!.toIso8601String(),
//                 'end': b['end']!.toIso8601String()
//               })
//           .toList(),
//       'currentBreakStart': currentBreakStart?.toIso8601String(),
//       'attendanceId': attendanceId,
//     };
//     await prefs.setString(key, jsonEncode(progressData));
//   }

//   Future<bool> _checkLocationPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission != LocationPermission.denied &&
//         permission != LocationPermission.deniedForever;
//   }

//   Future<bool> _validateGeofence() async {
//     if (currentSite == null) return false;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 5),
//       );
//       final siteLat = double.tryParse(currentSite!.latitude ?? '');
//       final siteLng = double.tryParse(currentSite!.longitude ?? '');

//       if (siteLat == null || siteLng == null) return false;

//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         siteLat,
//         siteLng,
//       );
//       return distance <= (currentSite!.radius ?? 150);
//     } catch (e) {
//       debugPrint("Geofence Check Failed: $e");
//       return false;
//     }
//   }

//   Future<bool> _capturePhotos() async {
//     _capturedPhotos.clear();
//     bool done = false;

//     while (!done && _capturedPhotos.length < 5) {
//       final shouldAdd = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: Text("Add Photo (${_capturedPhotos.length}/5)",
//               style: const TextStyle(color: Colors.white)),
//           content: const Text("You must take at least one photo.",
//               style: TextStyle(color: Colors.white70)),
//           actions: [
//             if (_capturedPhotos.isNotEmpty)
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false), // Done
//                 child: const Text("Done", style: TextStyle(color: Colors.blue)),
//               ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.pop(ctx, true), // Add Photo
//               child: const Text("Take Photo"),
//             ),
//           ],
//         ),
//       );

//       if (shouldAdd == true) {
//         final File? photo = await widget.imagePickerService.pickImage();
//         if (photo != null) {
//           setState(() {
//             _capturedPhotos.add(File(photo.path));
//           });
//         }
//       } else {
//         done = true;
//       }
//     }
//     return _capturedPhotos.isNotEmpty;
//   }

//   Future<void> _clearOldShiftData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     await prefs.remove(key);
//     _capturedPhotos.clear();
//     if (mounted) {
//       setState(() {
//         clockInTime = null;
//         clockOutTime = null;
//         breaks.clear();
//         currentBreakStart = null;
//         attendanceId = null;
//       });
//     }
//   }

//   // --- CLOCK IN (Strict Geofence + GPS + Multi-Photo) ---
//   Future<void> _handleClockIn() async {
//     if (mounted) setState(() => isLoading = true);
//     try {
//       if (!await _checkLocationPermission()) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Location permission is required.')));
//           setState(() => isLoading = false);
//         }
//         return;
//       }

//       // 🛑 STRICT CHECK: Validate Geofence BEFORE anything else
//       bool inRange = await _validateGeofence();
//       if (!inRange) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           // Show strict warning dialog
//           showDialog(
//             context: context,
//             builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Out of Range",
//                   style: TextStyle(color: Colors.redAccent)),
//               content: const Text(
//                 "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
//                 style: TextStyle(color: Colors.white70),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text("OK"),
//                 ),
//               ],
//             ),
//           );
//         }
//         return;
//       }

//       // 1. Capture Photos (Only if in range)
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final now = DateTime.now();

//       final result = await _attendanceService.clockIn(
//         employeeId: widget.employeeId,
//         shiftId: widget.shiftId,
//         siteId: widget.job.siteId ?? 0,
//         scheduledStartTime: widget.scheduledStartTime,
//         photos: _capturedPhotos,
//         clockInTime: now,
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );

//       if (result['success']) {
//         final attendanceIdFromResponse = result['attendanceId'];
//         if (mounted) {
//           setState(() {
//             clockInTime = now;
//             attendanceId = attendanceIdFromResponse;
//             clockInPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         await _saveShiftProgress();
//         await _sendEmployeeLocation(position);
//         _startLocationTracking();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Clock-in successful!')));
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-in error');
//       }
//     } catch (e) {
//       debugPrint('Clock-in error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   void _startLocationTracking() async {
//     final locationSettings =
//         LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
//     _positionStreamSubscription =
//         Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((Position position) async {
//       await _sendEmployeeLocation(position);
//     });
//   }

//   Future<void> _sendEmployeeLocation(Position position) async {
//     try {
//       await _locationService.sendLocation(position, widget.employeeId);
//     } catch (e) {
//       debugPrint(" Error sending employee location: $e");
//     }
//   }

//   Widget _buildDebugButton() {
//     return ElevatedButton(
//       onPressed: _clearOldShiftData,
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//       child: const Text('Clear Old Data'),
//     );
//   }

//   // --- CLOCK OUT (Early Warning & Multi-Photo) ---
//   Future<void> _handleClockOut() async {
//     if (attendanceId == null) return;

//     final now = DateTime.now();
//     final scheduledEnd = _getScheduledEndDateTime();

//     // CHECK: Is it Early Departure?
//     bool isEarly =
//         now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

//     if (isEarly) {
//       bool? confirmEarly = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: const Text("Early Departure Warning",
//               style: TextStyle(color: Colors.orangeAccent)),
//           content: const Text(
//             "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false), // No
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               onPressed: () => Navigator.pop(ctx, true), // Yes
//               child: const Text("Yes, Clock Out Early"),
//             ),
//           ],
//         ),
//       );

//       if (confirmEarly != true) return; // User cancelled
//     }

//     if (mounted) setState(() => isLoading = true);

//     try {
//       // 1. Capture Photos
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       // 2. Call Service
//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: _capturedPhotos,
//         latitude: position.latitude,
//         longitude: position.longitude,
//         timeout: networkTimeout,
//       );

//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
//         await NotificationService()
//             .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
//         await _saveShiftProgress();

//         if (mounted) {
//           if (isEarly) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               backgroundColor: Colors.orange[800],
//               content: const Text(
//                   '⚠ Early Departure Recorded. You clocked out early.'),
//             ));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('✅ Clock-out successful!')));
//           }
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // ========================================================================
//   // 🆕 NEW FEATURE: EMERGENCY CLOCK OUT
//   // ========================================================================
//   // This function handles emergency clock-out situations where the employee
//   // needs to leave immediately due to unforeseen circumstances.
//   // It bypasses the normal geofence validation and photo requirements,
//   // but REQUIRES a mandatory reason to be provided by the employee.
//   // ========================================================================
//   Future<void> _handleEmergencyClockOut() async {
//     // Validate that employee is clocked in and has an attendance record
//     if (attendanceId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No active shift to clock out from.')),
//       );
//       return;
//     }

//     // Controller for capturing the emergency reason
//     TextEditingController emergencyReasonController = TextEditingController();

//     // 📋 STEP 1: Show dialog to collect emergency reason
//     // This is MANDATORY - employee must provide a reason for emergency clock-out
//     bool? confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false, // User must make a choice
//       builder: (ctx) => AlertDialog(
//         backgroundColor: const Color(0xFF1C2230),
//         title: Row(
//           children: const [
//             Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
//             SizedBox(width: 8),
//             Text(
//               "Emergency Clock Out",
//               style: TextStyle(
//                 color: Colors.redAccent,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "You are about to perform an emergency clock-out. This should only be used in urgent situations.",
//               style: TextStyle(color: Colors.white70, fontSize: 14),
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               "⚠ Note: Photos and location checks will be bypassed.",
//               style: TextStyle(color: Colors.orange, fontSize: 13),
//             ),
//             const SizedBox(height: 20),
//             // 📝 TEXT FIELD: Reason input (Required)
//             TextField(
//               controller: emergencyReasonController,
//               style: const TextStyle(color: Colors.white),
//               maxLines: 3,
//               decoration: const InputDecoration(
//                 labelText: "Emergency Reason (Required)",
//                 labelStyle: TextStyle(color: Colors.white70),
//                 hintText: "e.g., Family emergency, Medical issue, etc.",
//                 hintStyle: TextStyle(color: Colors.white38),
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.white54),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.redAccent),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           // Cancel button
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("Cancel"),
//           ),
//           // Confirm emergency clock-out button
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//             ),
//             onPressed: () {
//               // Validate that reason is not empty
//               if (emergencyReasonController.text.trim().isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a reason for emergency clock-out.'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//                 return;
//               }
//               Navigator.pop(ctx, true); // Confirm and close dialog
//             },
//             child: const Text("Confirm Emergency Clock Out"),
//           ),
//         ],
//       ),
//     );

//     // User cancelled the operation
//     if (confirmed != true) return;

//     // 📋 STEP 2: Process emergency clock-out
//     if (mounted) setState(() => isLoading = true);

//     try {
//       final now = DateTime.now();
//       Position? position;

//       // Try to get location, but don't block if it fails (emergency situation)
//       try {
//         position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         ).timeout(const Duration(seconds: 5));
//       } catch (e) {
//         debugPrint('⚠ Location unavailable during emergency clock-out: $e');
//         // Continue without location - this is an emergency
//       }

//       // 📋 STEP 3: Call backend service with emergency flag
//       // Note: You'll need to update your AttendanceService.clockOut method
//       // to accept an optional 'emergencyReason' parameter
//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: [], // No photos required for emergency clock-out
//         latitude: position?.latitude ?? 0.0, // Use 0.0 if location unavailable
//         longitude: position?.longitude ?? 0.0,
//         timeout: networkTimeout,
//         isEmergency: true, // 🚨 Flag this as emergency clock-out
//         emergencyReason: emergencyReasonController.text.trim(), // 📝 Include reason
//       );

//       // 📋 STEP 4: Handle success response
//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             // No photo for emergency clock-out
//             clockOutPhoto = null;
//           });
//         }

//         // Send notification to management about emergency clock-out
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
        
//         // You may want to create a separate notification method for emergency clock-outs
//         await NotificationService().sendShiftCompletionNotification(
//           employeeName,
//           widget.shiftId,
//           now,
//         );

//         await _saveShiftProgress();

//         if (mounted) {
//           // Show distinct message for emergency clock-out
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.redAccent,
//               duration: const Duration(seconds: 5),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     '🚨 Emergency Clock-Out Recorded',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Reason: ${emergencyReasonController.text.trim()}',
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown emergency clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Emergency clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Emergency clock-out failed: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }
//   // ========================================================================
//   // 🔚 END OF EMERGENCY CLOCK OUT FEATURE
//   // ========================================================================

//   // --- UPDATED: Fix for Timezone Issue (Break Start) ---
//   Future<void> _handleBreakStart() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       // 1. Capture Local Time
//       final now = DateTime.now();

//       // 2. Send 'now' to the service
//       final result =
//           await _attendanceService.breakStart(attendanceId!, startTime: now);

//       if (result == true) {
//         if (mounted) setState(() => currentBreakStart = now);
//         await _saveShiftProgress();
//         if (mounted) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break started!')));
//         }
//       }
//     } catch (e) {
//       debugPrint('Break start error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // --- UPDATED: Fix for Timezone Issue (Break End) ---
//   Future<void> _handleBreakEnd() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       // 1. Capture Local Time
//       final now = DateTime.now();

//       // 2. Send 'now' to the service
//       final result =
//           await _attendanceService.endBreak(attendanceId!, endTime: now);

//       if (result == true) {
//         if (mounted) {
//           setState(() {
//             if (currentBreakStart != null) {
//               breaks.add({'start': currentBreakStart!, 'end': now});
//               currentBreakStart = null;
//             }
//           });
//         }
//         await _saveShiftProgress();
//         if (mounted)
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break ended!')));
//       }
//     } catch (e) {
//       debugPrint('Break end error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const Sidenav(),
//       appBar: Uppernavbar(showBackButton: true),
//       body: Stack(
//         children: [
//           Background(),
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Gradienthorizontal(
//                     width: MediaQuery.of(context).size.width,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           _buildShiftInfoCard(),
//                           const SizedBox(height: 24),
//                           if (isActionLoading)
//                             const CircularProgressIndicator()
//                           else if (myStatus == "Pending")
//                             _buildAcknowledgementCard()
//                           else if (myStatus == "Declined")
//                             _buildStatusMessage(
//                                 "⛔ You have declined this shift.", Colors.red)
//                           else if (myStatus == "Swap Requested")
//                             _buildStatusMessage(
//                                 "🔄 Swap Requested. Waiting for approval.",
//                                 Colors.orange)
//                           else if (myStatus == "Accepted")
//                             _buildTimeTrackingCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTrackingButton() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 16),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           if (currentSite != null) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EmployeeTrackingScreen(
//                   currentSite: currentSite!,
//                   employeeId: widget.employeeId,
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Site location not available.")),
//             );
//           }
//         },
//         icon: const Icon(Icons.map, color: Colors.white),
//         label: const Text("View Live Location Map",
//             style: TextStyle(color: Colors.white)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blueAccent,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   Widget _buildAcknowledgementCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
//       ),
//       child: Column(
//         children: [
//           const Text(
//             "Shift Acknowledgment",
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Please accept this shift to start tracking time.",
//             style: TextStyle(color: Colors.white70),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleDecline,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent),
//                   child: const Text("Decline"),
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleAccept,
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Accept"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           TextButton.icon(
//             onPressed: _handleSwapRequest,
//             icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
//             label: const Text("Request Swap",
//                 style: TextStyle(color: Colors.orangeAccent)),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusMessage(String msg, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         msg,
//         style:
//             TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   Widget _buildShiftInfoCard() {
//     final date = shiftDetails?['Date'];
//     final formattedDate = date != null
//         ? DateFormat.yMMMMd().format(DateTime.parse(date))
//         : 'Loading...';
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.job.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           shiftDetails?['TaskName'] ?? 'Loading...',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Icon(Icons.calendar_month_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Date: $formattedDate',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Start: ${formatTime(widget.scheduledStartTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'End: ${formatTime(widget.scheduledEndTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         if (currentSite != null) ...[
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on,
//                   color: Colors.white.withOpacity(0.9), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   currentSite!.siteName,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.9), fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildTimeTrackingCard() {
//     if (attendanceId == null && clockInTime != null) {
//       _buildDebugButton();
//     }

//     final isBreakEnabled = clockInTime != null && clockOutTime == null;

//     bool isEarlyDeparture = false;
//     if (clockOutTime != null) {
//       final scheduledEnd = _getScheduledEndDateTime();
//       isEarlyDeparture = clockOutTime!
//           .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
//     }

//     return Container(
//       child: Column(
//         children: [
//           Container(width: double.infinity),
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 if (clockOutTime != null) ...[
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: isEarlyDeparture
//                           ? Colors.orange.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isEarlyDeparture
//                             ? Colors.orange.withOpacity(0.5)
//                             : Colors.green.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           isEarlyDeparture
//                               ? Icons.warning_amber_rounded
//                               : Icons.check_circle,
//                           color:
//                               isEarlyDeparture ? Colors.orange : Colors.green,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'Early Departure'
//                                     : 'Shift Completed!',
//                                 style: TextStyle(
//                                   color: isEarlyDeparture
//                                       ? Colors.orange
//                                       : Colors.green,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
//                                     : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
                
//                 // ========================================================================
//                 // 🆕 CLOCK IN/OUT BUTTONS SECTION
//                 // ========================================================================
//                 if (clockOutTime == null) ...[
//                   // Main Clock In/Out button
//                   _buildTimeTrackingItem(
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime,
//                     clockInTime == null ? Icons.login : Icons.logout,
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime == null
//                         ? () => _handleClockIn()
//                         : () => _handleClockOut(),
//                     isEnabled: clockOutTime == null,
//                     photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
//                   ),
                  
//                   // ========================================================================
//                   // 🚨 EMERGENCY CLOCK OUT BUTTON
//                   // ========================================================================
//                   // This button appears ONLY when:
//                   // 1. Employee is clocked in (clockInTime != null)
//                   // 2. Employee hasn't clocked out yet (clockOutTime == null)
//                   // It's positioned directly under the regular Clock Out button
//                   // ========================================================================
//                   if (clockInTime != null) ...[
//                     const SizedBox(height: 12), // Spacing between buttons
                    
//                     // Emergency Clock Out Button Container
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.redAccent.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: Colors.redAccent.withOpacity(0.3),
//                           width: 1.5,
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Info text explaining when to use this button
//                           Row(
//                             children: const [
//                               Icon(
//                                 Icons.info_outline,
//                                 color: Colors.orange,
//                                 size: 16,
//                               ),
//                               SizedBox(width: 6),
//                               Expanded(
//                                 child: Text(
//                                   "Use only in emergency situations",
//                                   style: TextStyle(
//                                     color: Colors.orange,
//                                     fontSize: 12,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
                          
//                           // The actual Emergency Clock Out button
//                           SizedBox(
//                             width: double.infinity,
//                             height: 48,
//                             child: ElevatedButton.icon(
//                               onPressed: _handleEmergencyClockOut,
//                               icon: const Icon(
//                                 Icons.warning_amber_rounded,
//                                 size: 20,
//                                 color: Colors.white,
//                               ),
//                               label: const Text(
//                                 "Emergency Clock Out",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.redAccent,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 elevation: 2,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                   // ========================================================================
//                   // 🔚 END OF EMERGENCY CLOCK OUT BUTTON SECTION
//                   // ========================================================================
                  
//                 ] else
//                   // Show completed status if clocked out
//                   _buildTimeTrackingItem(
//                     "Clock Out",
//                     clockOutTime,
//                     Icons.logout,
//                     "Shift Completed",
//                     () {},
//                     isEnabled: false,
//                     photo: clockOutPhoto,
//                   ),
                
//                 const SizedBox(height: 16),
                
//                 // Break buttons section (only shown when clocked in and not clocked out)
//                 if (clockInTime != null && clockOutTime == null) ...[
//                   if (currentBreakStart == null)
//                     _buildTimeTrackingItem(
//                       "Start Break",
//                       null,
//                       Icons.free_breakfast,
//                       "Start Break",
//                       _handleBreakStart,
//                       isEnabled: isBreakEnabled,
//                     )
//                   else
//                     _buildTimeTrackingItem(
//                       "End Break",
//                       currentBreakStart,
//                       Icons.task_alt,
//                       "End Break",
//                       _handleBreakEnd,
//                       isEnabled: isBreakEnabled,
//                       customButtonColor: Colors.orangeAccent,
//                       customTextColor: Colors.black,
//                     ),
//                   const SizedBox(height: 16),
//                   _buildLiveTrackingButton(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 // Break history
//                 if (breaks.isNotEmpty) ...[
//                   _buildBreakHistory(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 // Shift summary (shown after clock out)
//                 if (clockOutTime != null) ...[
//                   _buildShiftSummary(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildShiftSummary() {
//     if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

//     final duration = clockOutTime!.difference(clockInTime!);
//     if (duration.isNegative) {
//       return const Text(
//         '⚠ Shift times are invalid (Clock-out before Clock-in)',
//         style: TextStyle(color: Colors.redAccent, fontSize: 14),
//       );
//     }

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.access_time, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Shift Summary',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.login, color: Colors.green, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.logout, color: Colors.red, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.schedule, color: Colors.blue, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Total Time: ${hours}h ${minutes}m',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           if (breaks.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Breaks Taken: ${breaks.length}',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeTrackingItem(
//     String label,
//     DateTime? time,
//     IconData icon,
//     String buttonText,
//     VoidCallback onPressed, {
//     bool? isEnabled,
//     File? photo,
//     Color? customButtonColor,
//     Color? customTextColor,
//   }) {
//     final isRecorded = time != null;
//     final buttonEnabled = isEnabled ?? !isRecorded;

//     // Use custom color if provided, else logic
//     final isRedButton = buttonText.toLowerCase().contains("out") ||
//         buttonText.toLowerCase().contains("end");

//     final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
//     final textColor = customTextColor ?? Colors.white;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500),
//               ),
//               const Spacer(),
//               Text(
//                 time != null
//                     ? DateFormat('hh:mm:ss a').format(time)
//                     : "Time: 00:00:00",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               onPressed: buttonEnabled ? onPressed : null,
//               icon: Icon(
//                 buttonText == "Completed" ? Icons.check_circle : icon,
//                 size: 20,
//                 color: buttonEnabled ? textColor : null,
//               ),
//               label: Text(
//                 buttonText,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: buttonEnabled ? textColor : null,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
//                 foregroundColor: textColor,
//                 disabledForegroundColor: Colors.white.withOpacity(0.6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBreakHistory() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Break History',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...breaks.map((breakItem) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Icon(Icons.circle, color: Colors.white70, size: 8),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }











import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
import 'package:shiftsmart/services/AttendanceService.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/services/ImagePickerService.dart';
import 'package:shiftsmart/services/LocationService.dart';
import 'package:shiftsmart/services/ShiftService.dart';
import 'package:shiftsmart/services/SiteService.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Employeeshiftview extends StatefulWidget {
  final Job job;
  final int shiftId;
  final int employeeId;
  final String scheduledStartTime;
  final String scheduledEndTime;
  final LocationService locationService;
  final ImagePickerService imagePickerService;

  const Employeeshiftview({
    super.key,
    required this.job,
    required this.shiftId,
    required this.employeeId,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.locationService,
    required this.imagePickerService,
  });

  @override
  State<Employeeshiftview> createState() => _EmployeeshiftviewState();
}

class _EmployeeshiftviewState extends State<Employeeshiftview> {
  List<Map<String, DateTime>> breaks = [];
  Map<String, dynamic>? shiftDetails;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? currentBreakStart;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  bool isClockedIn = false;
  File? clockInPhoto;
  File? clockOutPhoto;
  int? attendanceId;
  Site? currentSite;
  bool isLoading = false;

  // New Variables
  String myStatus = "Pending";
  String? myRejectionReason;
  bool isActionLoading = false;
  final List<File> _capturedPhotos = [];

  final SiteService _siteService = SiteService();
  final AttendanceService _attendanceService = AttendanceService();
  final ShiftService _shiftService = ShiftService();
  final LocationService _locationService = RealLocationService();

  final Color green = const Color.fromARGB(255, 1, 126, 42);
  static const Duration networkTimeout = Duration(seconds: 30);

  // --- Helpers ---

  String formatTime(String timeString) {
    try {
      final time = TimeOfDay(
        hour: int.parse(timeString.split(':')[0]),
        minute: int.parse(timeString.split(':')[1]),
      );
      return time.format(context);
    } catch (e) {
      return timeString;
    }
  }

  DateTime _getScheduledEndDateTime() {
    final now = DateTime.now();
    try {
      String timeStr = widget.scheduledEndTime.trim();
      int hour = 0;
      int minute = 0;

      if (timeStr.toLowerCase().contains("pm") ||
          timeStr.toLowerCase().contains("am")) {
        if (timeStr.split(':').length > 2) {
          timeStr =
              "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
        }
        final dt = DateFormat("h:mm a").parse(timeStr);
        hour = dt.hour;
        minute = dt.minute;
      } else {
        final parts = timeStr.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      }
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      debugPrint("⚠️ Date Parsing Error: $e");
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSiteData();
    _loadShiftDetailsAndStatus();
    _loadShiftProgress();
    enableFullScreen();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    if (mounted) _disposePhotos();
    super.dispose();
  }

  void _disposePhotos() {
    clockInPhoto = null;
    clockOutPhoto = null;
  }

  Future<void> _loadShiftDetailsAndStatus() async {
    try {
      final myShifts =
          await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
      final shift = myShifts.firstWhere(
        (s) => s['ShiftId'] == widget.shiftId,
        orElse: () => {},
      );

      if (shift.isNotEmpty && mounted) {
        setState(() {
          shiftDetails = shift;
          myStatus = shift['MyStatus'] ?? "Pending";
          myRejectionReason = shift['MyRejectionReason'];
        });
      }
    } catch (e) {
      debugPrint('Error loading shift details & status: $e');
    }
  }

  // --- Actions ---

  Future<void> _handleAccept() async {
    setState(() => isActionLoading = true);
    try {
      bool success =
          await _shiftService.respondToShift(widget.shiftId, "Accept");
      if (success) {
        setState(() => myStatus = "Accepted");
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
      }
    } catch (e) {
      debugPrint("Error accepting shift: $e");
    } finally {
      setState(() => isActionLoading = false);
    }
  }

  Future<void> _handleDecline() async {
    TextEditingController reasonCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Decline Shift",
                  style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Reason (Required)",
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54)),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (reasonCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => isActionLoading = true);
                    bool success = await _shiftService.respondToShift(
                        widget.shiftId, "Decline",
                        reason: reasonCtrl.text);
                    if (success) setState(() => myStatus = "Declined");
                    setState(() => isActionLoading = false);
                  },
                  child: const Text("Decline"),
                )
              ],
            ));
  }

  Future<void> _handleSwapRequest() async {
    setState(() => isActionLoading = true);
    try {
      bool success = await _shiftService.requestSwap(widget.shiftId);
      if (success) {
        setState(() => myStatus = "Swap Requested");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Swap Requested Successfully")));
      }
    } catch (e) {
      debugPrint("Error requesting swap: $e");
    } finally {
      setState(() => isActionLoading = false);
    }
  }

  Future<void> _loadSiteData() async {
    setState(() => isLoading = true);
    try {
      if (widget.job.siteId == 0) return;
      final site = await _siteService.fetchSiteById(widget.job.siteId);
      if (site != null) currentSite = site;
    } catch (e) {
      debugPrint('Error loading site data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UPDATED: Properly syncs Break Status from Server ---
  Future<void> _loadShiftProgress() async {
    // 1. Load Local Data (Prevents flickering)
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    final progressData = prefs.getString(key);

    if (progressData != null) {
      final progress = jsonDecode(progressData);
      if (mounted) {
        setState(() {
          clockInTime = progress['clockInTime'] != null
              ? DateTime.parse(progress['clockInTime'])
              : null;
          clockOutTime = progress['clockOutTime'] != null
              ? DateTime.parse(progress['clockOutTime'])
              : null;
          if (progress['breaks'] != null) {
            breaks = (progress['breaks'] as List<dynamic>).map((b) {
              return {
                'start': DateTime.parse(b['start']),
                'end': DateTime.parse(b['end']),
              };
            }).toList();
          }
          if (progress['currentBreakStart'] != null) {
            currentBreakStart =
                DateTime.tryParse(progress['currentBreakStart']);
          }
          attendanceId = progress['attendanceId'];
        });
      }
    }

    try {
      // 2. Fetch Latest Status from Server
      final shift = await _attendanceService.getShiftsByShiftId(
          widget.employeeId,
          shiftId: widget.shiftId) as Map<String, dynamic>?;

      if (shift != null && mounted) {
        // --- Parse Backend Times ---
        final backendClockInTime = shift['ClockInTime'] != null
            ? DateTime.tryParse(shift['ClockInTime'])
            : null;
        final backendClockOutTime = shift['ClockOutTime'] != null
            ? DateTime.tryParse(shift['ClockOutTime'])
            : null;

        // --- NEW: Parse Backend Break Times ---
        final backendBreakStart = shift['BreakStart'] != null
            ? DateTime.tryParse(shift['BreakStart'])
            : null;
        final backendBreakEnd = shift['BreakEnd'] != null
            ? DateTime.tryParse(shift['BreakEnd'])
            : null;

        if (mounted) {
          setState(() {
            // Sync Clock In
            if (backendClockInTime != null) {
              if (attendanceId == null || clockInTime == null) {
                clockInTime = backendClockInTime;
                attendanceId = shift['AttendanceId'];
              }
            }

            // Sync Clock Out
            if (backendClockOutTime != null &&
                backendClockOutTime.year > 1900) {
              clockOutTime = backendClockOutTime;
            }

            // --- Sync Break Status ---
            if (backendBreakStart != null) {
              // Active Break
              if (backendBreakEnd == null) {
                currentBreakStart = backendBreakStart;
              }
              // Finished Break
              else {
                currentBreakStart = null;
                // Add to history if unique
                bool exists = breaks.any((b) =>
                    b['start']!.isAtSameMomentAs(backendBreakStart) &&
                    b['end']!.isAtSameMomentAs(backendBreakEnd));

                if (!exists) {
                  breaks.add({
                    'start': backendBreakStart,
                    'end': backendBreakEnd,
                  });
                }
              }
            }
          });

          _saveShiftProgress();
        }
      }
    } catch (e) {
      debugPrint('Error fetching shift status: $e');
    }
  }

  Future<void> _saveShiftProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    final progressData = {
      'clockInTime': clockInTime?.toIso8601String(),
      'clockOutTime': clockOutTime?.toIso8601String(),
      'breaks': breaks
          .map((b) => {
                'start': b['start']!.toIso8601String(),
                'end': b['end']!.toIso8601String()
              })
          .toList(),
      'currentBreakStart': currentBreakStart?.toIso8601String(),
      'attendanceId': attendanceId,
    };
    await prefs.setString(key, jsonEncode(progressData));
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<bool> _validateGeofence() async {
    if (currentSite == null) return false;
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final siteLat = double.tryParse(currentSite!.latitude ?? '');
      final siteLng = double.tryParse(currentSite!.longitude ?? '');

      if (siteLat == null || siteLng == null) return false;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        siteLat,
        siteLng,
      );
      return distance <= (currentSite!.radius ?? 150);
    } catch (e) {
      debugPrint("Geofence Check Failed: $e");
      return false;
    }
  }

  Future<bool> _capturePhotos() async {
    _capturedPhotos.clear();
    bool done = false;

    while (!done && _capturedPhotos.length < 5) {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C2230),
          title: Text("Add Photo (${_capturedPhotos.length}/5)",
              style: const TextStyle(color: Colors.white)),
          content: const Text("You must take at least one photo.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            if (_capturedPhotos.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Done
                child: const Text("Done", style: TextStyle(color: Colors.blue)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true), // Add Photo
              child: const Text("Take Photo"),
            ),
          ],
        ),
      );

      if (shouldAdd == true) {
        final File? photo = await widget.imagePickerService.pickImage();
        if (photo != null) {
          setState(() {
            _capturedPhotos.add(File(photo.path));
          });
        }
      } else {
        done = true;
      }
    }
    return _capturedPhotos.isNotEmpty;
  }

  Future<void> _clearOldShiftData() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    await prefs.remove(key);
    _capturedPhotos.clear();
    if (mounted) {
      setState(() {
        clockInTime = null;
        clockOutTime = null;
        breaks.clear();
        currentBreakStart = null;
        attendanceId = null;
      });
    }
  }

  // ========================================================================
  // 🆕 UPDATED: CLOCK IN - Sends clockInTime + Updates Shift Status to "Active"
  // ========================================================================
  Future<void> _handleClockIn() async {
    if (mounted) setState(() => isLoading = true);
    try {
      if (!await _checkLocationPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission is required.')));
          setState(() => isLoading = false);
        }
        return;
      }

      // 🛑 STRICT CHECK: Validate Geofence BEFORE anything else
      bool inRange = await _validateGeofence();
      if (!inRange) {
        if (mounted) {
          setState(() => isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Out of Range",
                  style: TextStyle(color: Colors.redAccent)),
              content: const Text(
                "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 1. Capture Photos (Only if in range)
      bool hasPhotos = await _capturePhotos();
      if (!hasPhotos) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('At least one photo is required.')));
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();

      // ✅ SEND clockInTime to backend
      final result = await _attendanceService.clockIn(
        employeeId: widget.employeeId,
        shiftId: widget.shiftId,
        siteId: widget.job.siteId ?? 0,
        scheduledStartTime: widget.scheduledStartTime,
        photos: _capturedPhotos,
        clockInTime: now, // ✅ Explicitly sending clock-in time
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (result['success']) {
        final attendanceIdFromResponse = result['attendanceId'];
        
        
        if (mounted) {
          setState(() {
            clockInTime = now;
            attendanceId = attendanceIdFromResponse;
            clockInPhoto =
                _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
          });
        }
        await _saveShiftProgress();
        await _sendEmployeeLocation(position);
        _startLocationTracking();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Clock-in successful! Shift is now Active.')));
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown clock-in error');
      }
    } catch (e) {
      debugPrint('Clock-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startLocationTracking() async {
    final locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
      await _sendEmployeeLocation(position);
    });
  }

  Future<void> _sendEmployeeLocation(Position position) async {
    try {
      await _locationService.sendLocation(position, widget.employeeId);
    } catch (e) {
      debugPrint(" Error sending employee location: $e");
    }
  }

  Widget _buildDebugButton() {
    return ElevatedButton(
      onPressed: _clearOldShiftData,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
      child: const Text('Clear Old Data'),
    );
  }

  // ========================================================================
  // 🆕 UPDATED: CLOCK OUT - Sends clockOutTime + Updates Shift Status
  // ========================================================================
  Future<void> _handleClockOut() async {
    if (attendanceId == null) return;

    final now = DateTime.now();
    final scheduledEnd = _getScheduledEndDateTime();

    // 🛑 CHECK: Is it Early Departure?
    bool isEarly =
        now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

    if (isEarly) {
      bool? confirmEarly = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C2230),
          title: const Text("Early Departure Warning",
              style: TextStyle(color: Colors.orangeAccent)),
          content: const Text(
            "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Clock Out Early"),
            ),
          ],
        ),
      );

      if (confirmEarly != true) return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      // 1. Capture Photos
      bool hasPhotos = await _capturePhotos();
      if (!hasPhotos) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('At least one photo is required.')));
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // ✅ SEND clockOutTime to backend
      final result = await _attendanceService.clockOut(
        attendanceId: attendanceId!,
        clockOutTime: now, // Required parameter
        photos: _capturedPhotos,
        latitude: position.latitude,
        longitude: position.longitude,
        timeout: networkTimeout,
      );

      if (result['success']) {
        
        
        if (mounted) {
          setState(() {
            clockOutTime = now;
            clockOutPhoto =
                _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
          });
        }
        final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
        final employeeName =
            employeeNameMap[widget.employeeId] ?? "An employee";
        await NotificationService()
            .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
        await _saveShiftProgress();

        if (mounted) {
          if (isEarly) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.orange[800],
              content: const Text(
                  '⚠ Early Departure Recorded. You clocked out early.'),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Clock-out successful!')));
          }
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown clock-out error');
      }
    } catch (e) {
      debugPrint('Clock-out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ========================================================================
  // 🆕 NEW METHOD: EMERGENCY CLOCK OUT - Sends emergencyReason + clockOutTime
  // ========================================================================
  // This is a COMPLETELY NEW method that allows employees to clock out in emergency situations
  // where they cannot take photos or may not be at the site location.
  //
  // USE CASES:
  // - Medical emergencies (employee or family member)
  // - Safety concerns (fire, natural disaster, violence)
  // - Family crises requiring immediate departure
  // - Phone issues (dead battery, broken camera, lost phone)
  //
  // KEY FEATURES:
  // 1. NO photos required (unlike regular clock-out)
  // 2. Location optional (may not be available in emergencies)
  // 3. Requires mandatory emergency reason for audit
  // 4. Automatically flags for manager approval
  // 5. Sends emergency notification to admins
  // 6. Updates shift status to "Emergency Completed"
  //
  // NOTE: This requires:
  // 1. AttendanceService.emergencyClockOut() method (already implemented in file 2)
  // 2. ShiftService.updateShiftStatus() method (needs to be implemented)
  // 3. NotificationService.sendEmergencyClockOutNotification() method (needs to be implemented)
  //
  // If any of these methods are missing, you'll get compilation errors and need to implement them.
  Future<void> _handleEmergencyClockOut() async {
    if (attendanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active shift to clock out from.')),
      );
      return;
    }

    TextEditingController emergencyReasonController = TextEditingController();

    // Show confirmation dialog with emergency reason input
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2230),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              "Emergency Clock Out",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You are about to perform an emergency clock-out. This should only be used in urgent situations.",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              "⚠ Note: Photos and location checks will be bypassed.",
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emergencyReasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Emergency Reason (Required)",
                labelStyle: TextStyle(color: Colors.white70),
                hintText: "e.g., Family emergency, Medical issue, etc.",
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              if (emergencyReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for emergency clock-out.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text("Confirm Emergency Clock Out"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      Position? position;

      // Try to get location, but don't fail if unavailable
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠ Location unavailable during emergency clock-out: $e');
      }

      // Call the emergency clock-out service method
      final result = await _attendanceService.emergencyClockOut(
        attendanceId: attendanceId!,
        shiftId: widget.shiftId,
        emergencyReason: emergencyReasonController.text.trim(),
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        timeout: networkTimeout,
      );

      if (result['success']) {
        
        
        if (mounted) {
          setState(() {
            clockOutTime = now;
            clockOutPhoto = null; // No photo for emergency clock-out
          });
        }

        final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
        final employeeName =
            employeeNameMap[widget.employeeId] ?? "An employee";
        
        
        await _saveShiftProgress();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 Emergency Clock-Out Recorded',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${emergencyReasonController.text.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown emergency clock-out error');
      }
    } catch (e) {
      debugPrint('Emergency clock-out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency clock-out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  // ========================================================================
  // 🆕 END OF NEW METHOD
  // ========================================================================

  // ========================================================================
  // 🆕 UPDATED: BREAK START - Sends breakStartTime to backend
  // ========================================================================
  Future<void> _handleBreakStart() async {
    if (attendanceId == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      final now = DateTime.now();

      // ✅ SEND breakStartTime to backend
      final result = await _attendanceService.breakStart(
        attendanceId!,
        startTime: now, // ✅ Explicitly sending break start time
      );

      if (result == true) {
        if (mounted) setState(() => currentBreakStart = now);
        await _saveShiftProgress();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Break started!')));
        }
      }
    } catch (e) {
      debugPrint('Break start error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ========================================================================
  // 🆕 UPDATED: BREAK END - Sends breakEndTime to backend
  // ========================================================================
  Future<void> _handleBreakEnd() async {
    if (attendanceId == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      final now = DateTime.now();

      // ✅ SEND breakEndTime to backend
      final result = await _attendanceService.endBreak(
        attendanceId!,
        endTime: now, // ✅ Explicitly sending break end time
      );

      if (result == true) {
        if (mounted) {
          setState(() {
            if (currentBreakStart != null) {
              breaks.add({'start': currentBreakStart!, 'end': now});
              currentBreakStart = null;
            }
          });
        }
        await _saveShiftProgress();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Break ended!')));
        }
      }
    } catch (e) {
      debugPrint('Break end error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      drawer: const Sidenav(),
      appBar: Uppernavbar(showBackButton: true),
      body: Stack(
        children: [
          Background(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Gradienthorizontal(
                    width: MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildShiftInfoCard(),
                          const SizedBox(height: 24),
                          if (isActionLoading)
                            const CircularProgressIndicator()
                          else if (myStatus == "Pending")
                            _buildAcknowledgementCard()
                          else if (myStatus == "Declined")
                            _buildStatusMessage(
                                "⛔ You have declined this shift.", Colors.red)
                          else if (myStatus == "Swap Requested")
                            _buildStatusMessage(
                                "🔄 Swap Requested. Waiting for approval.",
                                Colors.orange)
                          else if (myStatus == "Accepted")
                            _buildTimeTrackingCard(),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          if (currentSite != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeTrackingScreen(
                  currentSite: currentSite!,
                  employeeId: widget.employeeId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Site location not available.")),
            );
          }
        },
        icon: const Icon(Icons.map, color: Colors.white),
        label: const Text("View Live Location Map",
            style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildAcknowledgementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Text(
            "Shift Acknowledgment",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Please accept this shift to start tracking time.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleDecline,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleAccept,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Accept"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _handleSwapRequest,
            icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
            label: const Text("Request Swap",
                style: TextStyle(color: Colors.orangeAccent)),
          )
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        msg,
        style:
            TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildShiftInfoCard() {
    final date = shiftDetails?['Date'];
    final formattedDate = date != null
        ? DateFormat.yMMMMd().format(DateTime.parse(date))
        : 'Loading...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          shiftDetails?['TaskName'] ?? 'Loading...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: Colors.white.withOpacity(0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'Date: $formattedDate',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule,
                color: Colors.white.withOpacity(0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'Start: ${formatTime(widget.scheduledStartTime)}',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: Colors.white.withOpacity(0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'End: ${formatTime(widget.scheduledEndTime)}',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
            ),
          ],
        ),
        if (currentSite != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on,
                  color: Colors.white.withOpacity(0.9), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentSite!.siteName,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeTrackingCard() {
    if (attendanceId == null && clockInTime != null) {
      _buildDebugButton();
    }

    final isBreakEnabled = clockInTime != null && clockOutTime == null;

    bool isEarlyDeparture = false;
    if (clockOutTime != null) {
      final scheduledEnd = _getScheduledEndDateTime();
      isEarlyDeparture = clockOutTime!
          .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
    }

    return Container(
      child: Column(
        children: [
          Container(width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                if (clockOutTime != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isEarlyDeparture
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEarlyDeparture
                            ? Colors.orange.withOpacity(0.5)
                            : Colors.green.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isEarlyDeparture
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          color:
                              isEarlyDeparture ? Colors.orange : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEarlyDeparture
                                    ? 'Early Departure'
                                    : 'Shift Completed!',
                                style: TextStyle(
                                  color: isEarlyDeparture
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEarlyDeparture
                                    ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
                                    : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (clockOutTime == null) ...[
                  _buildTimeTrackingItem(
                    clockInTime == null ? "Clock In" : "Clock Out",
                    clockInTime,
                    clockInTime == null ? Icons.login : Icons.logout,
                    clockInTime == null ? "Clock In" : "Clock Out",
                    clockInTime == null
                        ? () => _handleClockIn()
                        : () => _handleClockOut(),
                    isEnabled: clockOutTime == null,
                    photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
                  ),
                  
                  // ========================================================================
                  // 🆕 NEW CODE: EMERGENCY CLOCK OUT BUTTON
                  // ========================================================================
                  // This section adds the Emergency Clock Out button to the UI.
                  // It only appears when the employee is currently clocked in.
                  // The button is styled in red to indicate it's for emergency use only.
                  //
                  // Features:
                  // - Only visible after clock-in (clockInTime != null)
                  // - Warning message about emergency use
                  // - Red styling to indicate severity
                  // - Calls _handleEmergencyClockOut() when pressed
                  if (clockInTime != null) ...[
                    const SizedBox(height: 12),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Use only in emergency situations",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _handleEmergencyClockOut,
                              icon: const Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Emergency Clock Out",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ========================================================================
                  // 🆕 END OF NEW CODE
                  // ========================================================================
                ] else ...[
                  _buildTimeTrackingItem(
                    "Clock Out",
                    clockOutTime,
                    Icons.logout,
                    "Shift Completed",
                    () {},
                    isEnabled: false,
                    photo: clockOutPhoto,
                  ),
                ],
                
                const SizedBox(height: 16),
                
                if (clockInTime != null && clockOutTime == null) ...[
                  if (currentBreakStart == null)
                    _buildTimeTrackingItem(
                      "Start Break",
                      null,
                      Icons.free_breakfast,
                      "Start Break",
                      _handleBreakStart,
                      isEnabled: isBreakEnabled,
                    )
                  else
                    _buildTimeTrackingItem(
                      "End Break",
                      currentBreakStart,
                      Icons.task_alt,
                      "End Break",
                      _handleBreakEnd,
                      isEnabled: isBreakEnabled,
                      customButtonColor: Colors.orangeAccent,
                      customTextColor: Colors.black,
                    ),
                  const SizedBox(height: 16),
                  _buildLiveTrackingButton(),
                  const SizedBox(height: 16),
                ],
                
                if (breaks.isNotEmpty) ...[
                  _buildBreakHistory(),
                  const SizedBox(height: 16),
                ],
                
                if (clockOutTime != null) ...[
                  _buildShiftSummary(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSummary() {
    if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

    final duration = clockOutTime!.difference(clockInTime!);
    if (duration.isNegative) {
      return const Text(
        '⚠ Shift times are invalid (Clock-out before Clock-in)',
        style: TextStyle(color: Colors.redAccent, fontSize: 14),
      );
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Shift Summary',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.login, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total Time: ${hours}h ${minutes}m',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (breaks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Breaks Taken: ${breaks.length}',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeTrackingItem(
    String label,
    DateTime? time,
    IconData icon,
    String buttonText,
    VoidCallback onPressed, {
    bool? isEnabled,
    File? photo,
    Color? customButtonColor,
    Color? customTextColor,
  }) {
    final isRecorded = time != null;
    final buttonEnabled = isEnabled ?? !isRecorded;

    final isRedButton = buttonText.toLowerCase().contains("out") ||
        buttonText.toLowerCase().contains("end");

    final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
    final textColor = customTextColor ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                time != null
                    ? DateFormat('hh:mm:ss a').format(time)
                    : "Time: 00:00:00",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: buttonEnabled ? onPressed : null,
              icon: Icon(
                buttonText == "Completed" ? Icons.check_circle : icon,
                size: 20,
                color: buttonEnabled ? textColor : null,
              ),
              label: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 16,
                  color: buttonEnabled ? textColor : null,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
                foregroundColor: textColor,
                disabledForegroundColor: Colors.white.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Break History',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...breaks.map((breakItem) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white70, size: 8),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}































// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shiftsmart/models/Job.dart';
// import 'package:shiftsmart/models/Site.dart';
// import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
// import 'package:shiftsmart/services/AttendanceService.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/ImagePickerService.dart';
// import 'package:shiftsmart/services/LocationService.dart';
// import 'package:shiftsmart/services/ShiftService.dart';
// import 'package:shiftsmart/services/SiteService.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';

// class Employeeshiftview extends StatefulWidget {
//   final Job job;
//   final int shiftId;
//   final int employeeId;
//   final String scheduledStartTime;
//   final String scheduledEndTime;
//   final LocationService locationService;
//   final ImagePickerService imagePickerService;

//   const Employeeshiftview({
//     super.key,
//     required this.job,
//     required this.shiftId,
//     required this.employeeId,
//     required this.scheduledStartTime,
//     required this.scheduledEndTime,
//     required this.locationService,
//     required this.imagePickerService,
//   });

//   @override
//   State<Employeeshiftview> createState() => _EmployeeshiftviewState();
// }

// class _EmployeeshiftviewState extends State<Employeeshiftview> {
//   List<Map<String, DateTime>> breaks = [];
//   Map<String, dynamic>? shiftDetails;
//   StreamSubscription<Position>? _positionStreamSubscription;
//   DateTime? currentBreakStart;
//   DateTime? clockInTime;
//   DateTime? clockOutTime;
//   bool isClockedIn = false;
//   File? clockInPhoto;
//   File? clockOutPhoto;
//   int? attendanceId;
//   Site? currentSite;
//   bool isLoading = false;

//   String myStatus = "Pending";
//   String? myRejectionReason;
//   bool isActionLoading = false;
//   List<File> _capturedPhotos = [];

//   final SiteService _siteService = SiteService();
//   final AttendanceService _attendanceService = AttendanceService();
//   final ShiftService _shiftService = ShiftService();
//   final LocationService _locationService = RealLocationService();

//   final Color green = const Color.fromARGB(255, 1, 126, 42);
//   static const Duration networkTimeout = Duration(seconds: 30);

//   // ALL EXISTING HELPER METHODS (NO CHANGES)
  
//   String formatTime(String timeString) {
//     try {
//       final time = TimeOfDay(
//         hour: int.parse(timeString.split(':')[0]),
//         minute: int.parse(timeString.split(':')[1]),
//       );
//       return time.format(context);
//     } catch (e) {
//       return timeString;
//     }
//   }

//   DateTime _getScheduledEndDateTime() {
//     final now = DateTime.now();
//     try {
//       String timeStr = widget.scheduledEndTime.trim();
//       int hour = 0;
//       int minute = 0;

//       if (timeStr.toLowerCase().contains("pm") ||
//           timeStr.toLowerCase().contains("am")) {
//         if (timeStr.split(':').length > 2) {
//           timeStr =
//               "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
//         }
//         final dt = DateFormat("h:mm a").parse(timeStr);
//         hour = dt.hour;
//         minute = dt.minute;
//       } else {
//         final parts = timeStr.split(':');
//         hour = int.parse(parts[0]);
//         minute = int.parse(parts[1]);
//       }
//       return DateTime(now.year, now.month, now.day, hour, minute);
//     } catch (e) {
//       debugPrint("Date Parsing Error: $e");
//       return DateTime.now();
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadSiteData();
//     _loadShiftDetailsAndStatus();
//     _loadShiftProgress();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     if (mounted) _disposePhotos();
//     super.dispose();
//   }

//   void _disposePhotos() {
//     clockInPhoto = null;
//     clockOutPhoto = null;
//   }

//   Future<void> _loadShiftDetailsAndStatus() async {
//     try {
//       final myShifts =
//           await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
//       final shift = myShifts.firstWhere(
//         (s) => s['ShiftId'] == widget.shiftId,
//         orElse: () => {},
//       );

//       if (shift.isNotEmpty && mounted) {
//         setState(() {
//           shiftDetails = shift;
//           myStatus = shift['MyStatus'] ?? "Pending";
//           myRejectionReason = shift['MyRejectionReason'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading shift details & status: $e');
//     }
//   }

//   Future<void> _handleAccept() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success =
//           await _shiftService.respondToShift(widget.shiftId, "Accept");
//       if (success) {
//         setState(() => myStatus = "Accepted");
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
//       }
//     } catch (e) {
//       debugPrint("Error accepting shift: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _handleDecline() async {
//     TextEditingController reasonCtrl = TextEditingController();
//     showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Decline Shift",
//                   style: TextStyle(color: Colors.white)),
//               content: TextField(
//                 controller: reasonCtrl,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Reason (Required)",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: Colors.white54)),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel")),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () async {
//                     if (reasonCtrl.text.isEmpty) return;
//                     Navigator.pop(ctx);
//                     setState(() => isActionLoading = true);
//                     bool success = await _shiftService.respondToShift(
//                         widget.shiftId, "Decline",
//                         reason: reasonCtrl.text);
//                     if (success) setState(() => myStatus = "Declined");
//                     setState(() => isActionLoading = false);
//                   },
//                   child: const Text("Decline"),
//                 )
//               ],
//             ));
//   }

//   Future<void> _handleSwapRequest() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success = await _shiftService.requestSwap(widget.shiftId);
//       if (success) {
//         setState(() => myStatus = "Swap Requested");
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Swap Requested Successfully")));
//       }
//     } catch (e) {
//       debugPrint("Error requesting swap: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _loadSiteData() async {
//     setState(() => isLoading = true);
//     try {
//       if (widget.job.siteId == 0 || widget.job.siteId == null) return;
//       final site = await _siteService.fetchSiteById(widget.job.siteId!);
//       if (site != null) currentSite = site;
//     } catch (e) {
//       debugPrint('Error loading site data: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _loadShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = prefs.getString(key);

//     if (progressData != null) {
//       final progress = jsonDecode(progressData);
//       if (mounted) {
//         setState(() {
//           clockInTime = progress['clockInTime'] != null
//               ? DateTime.parse(progress['clockInTime'])
//               : null;
//           clockOutTime = progress['clockOutTime'] != null
//               ? DateTime.parse(progress['clockOutTime'])
//               : null;
//           if (progress['breaks'] != null) {
//             breaks = (progress['breaks'] as List<dynamic>).map((b) {
//               return {
//                 'start': DateTime.parse(b['start']),
//                 'end': DateTime.parse(b['end']),
//               };
//             }).toList();
//           }
//           if (progress['currentBreakStart'] != null) {
//             currentBreakStart =
//                 DateTime.tryParse(progress['currentBreakStart']);
//           }
//           attendanceId = progress['attendanceId'];
//         });
//       }
//     }

//     try {
//       final shift = await _attendanceService.getShiftsByShiftId(
//           widget.employeeId,
//           shiftId: widget.shiftId) as Map<String, dynamic>?;

//       if (shift != null && mounted) {
//         final backendClockInTime = shift['ClockInTime'] != null
//             ? DateTime.tryParse(shift['ClockInTime'])
//             : null;
//         final backendClockOutTime = shift['ClockOutTime'] != null
//             ? DateTime.tryParse(shift['ClockOutTime'])
//             : null;

//         final backendBreakStart = shift['BreakStart'] != null
//             ? DateTime.tryParse(shift['BreakStart'])
//             : null;
//         final backendBreakEnd = shift['BreakEnd'] != null
//             ? DateTime.tryParse(shift['BreakEnd'])
//             : null;

//         if (mounted) {
//           setState(() {
//             if (backendClockInTime != null) {
//               if (attendanceId == null || clockInTime == null) {
//                 clockInTime = backendClockInTime;
//                 attendanceId = shift['AttendanceId'];
//               }
//             }

//             if (backendClockOutTime != null &&
//                 backendClockOutTime.year > 1900) {
//               clockOutTime = backendClockOutTime;
//             }

//             if (backendBreakStart != null) {
//               if (backendBreakEnd == null) {
//                 currentBreakStart = backendBreakStart;
//               } else {
//                 currentBreakStart = null;
//                 bool exists = breaks.any((b) =>
//                     b['start']!.isAtSameMomentAs(backendBreakStart) &&
//                     b['end']!.isAtSameMomentAs(backendBreakEnd!));

//                 if (!exists) {
//                   breaks.add({
//                     'start': backendBreakStart,
//                     'end': backendBreakEnd,
//                   });
//                 }
//               }
//             }
//           });

//           _saveShiftProgress();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching shift status: $e');
//     }
//   }

//   Future<void> _saveShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = {
//       'clockInTime': clockInTime?.toIso8601String(),
//       'clockOutTime': clockOutTime?.toIso8601String(),
//       'breaks': breaks
//           .map((b) => {
//                 'start': b['start']!.toIso8601String(),
//                 'end': b['end']!.toIso8601String()
//               })
//           .toList(),
//       'currentBreakStart': currentBreakStart?.toIso8601String(),
//       'attendanceId': attendanceId,
//     };
//     await prefs.setString(key, jsonEncode(progressData));
//   }

//   Future<bool> _checkLocationPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission != LocationPermission.denied &&
//         permission != LocationPermission.deniedForever;
//   }

//   Future<bool> _validateGeofence() async {
//     if (currentSite == null) return false;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 5),
//       );
//       final siteLat = double.tryParse(currentSite!.latitude ?? '');
//       final siteLng = double.tryParse(currentSite!.longitude ?? '');

//       if (siteLat == null || siteLng == null) return false;

//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         siteLat,
//         siteLng,
//       );
//       return distance <= (currentSite!.radius ?? 150);
//     } catch (e) {
//       debugPrint("Geofence Check Failed: $e");
//       return false;
//     }
//   }

//   Future<bool> _capturePhotos() async {
//     _capturedPhotos.clear();
//     bool done = false;

//     while (!done && _capturedPhotos.length < 5) {
//       final shouldAdd = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: Text("Add Photo (${_capturedPhotos.length}/5)",
//               style: const TextStyle(color: Colors.white)),
//           content: const Text("You must take at least one photo.",
//               style: TextStyle(color: Colors.white70)),
//           actions: [
//             if (_capturedPhotos.isNotEmpty)
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text("Done", style: TextStyle(color: Colors.blue)),
//               ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Take Photo"),
//             ),
//           ],
//         ),
//       );

//       if (shouldAdd == true) {
//         final File? photo = await widget.imagePickerService.pickImage();
//         if (photo != null) {
//           setState(() {
//             _capturedPhotos.add(File(photo.path));
//           });
//         }
//       } else {
//         done = true;
//       }
//     }
//     return _capturedPhotos.isNotEmpty;
//   }

//   Future<void> _clearOldShiftData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     await prefs.remove(key);
//     _capturedPhotos.clear();
//     if (mounted) {
//       setState(() {
//         clockInTime = null;
//         clockOutTime = null;
//         breaks.clear();
//         currentBreakStart = null;
//         attendanceId = null;
//       });
//     }
//   }

//   Future<void> _handleClockIn() async {
//     if (mounted) setState(() => isLoading = true);
//     try {
//       if (!await _checkLocationPermission()) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Location permission is required.')));
//           setState(() => isLoading = false);
//         }
//         return;
//       }

//       bool inRange = await _validateGeofence();
//       if (!inRange) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           showDialog(
//             context: context,
//             builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Out of Range",
//                   style: TextStyle(color: Colors.redAccent)),
//               content: const Text(
//                 "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
//                 style: TextStyle(color: Colors.white70),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text("OK"),
//                 ),
//               ],
//             ),
//           );
//         }
//         return;
//       }

//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final now = DateTime.now();

//       final result = await _attendanceService.clockIn(
//         employeeId: widget.employeeId,
//         shiftId: widget.shiftId,
//         siteId: widget.job.siteId ?? 0,
//         scheduledStartTime: widget.scheduledStartTime,
//         photos: _capturedPhotos,
//         clockInTime: now,
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );

//       if (result['success']) {
//         final attendanceIdFromResponse = result['attendanceId'];
//         if (mounted) {
//           setState(() {
//             clockInTime = now;
//             attendanceId = attendanceIdFromResponse;
//             clockInPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         await _saveShiftProgress();
//         await _sendEmployeeLocation(position);
//         _startLocationTracking();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Clock-in successful!')));
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-in error');
//       }
//     } catch (e) {
//       debugPrint('Clock-in error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   void _startLocationTracking() async {
//     final locationSettings =
//         LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
//     _positionStreamSubscription =
//         Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((Position position) async {
//       await _sendEmployeeLocation(position);
//     });
//   }

//   Future<void> _sendEmployeeLocation(Position position) async {
//     try {
//       await _locationService.sendLocation(position, widget.employeeId);
//     } catch (e) {
//       debugPrint(" Error sending employee location: $e");
//     }
//   }

//   Widget _buildDebugButton() {
//     return ElevatedButton(
//       onPressed: _clearOldShiftData,
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//       child: const Text('Clear Old Data'),
//     );
//   }

//   Future<void> _handleClockOut() async {
//     if (attendanceId == null) return;

//     final now = DateTime.now();
//     final scheduledEnd = _getScheduledEndDateTime();

//     bool isEarly =
//         now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

//     if (isEarly) {
//       bool? confirmEarly = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: const Text("Early Departure Warning",
//               style: TextStyle(color: Colors.orangeAccent)),
//           content: const Text(
//             "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Yes, Clock Out Early"),
//             ),
//           ],
//         ),
//       );

//       if (confirmEarly != true) return;
//     }

//     if (mounted) setState(() => isLoading = true);

//     try {
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: _capturedPhotos,
//         latitude: position.latitude,
//         longitude: position.longitude,
//         timeout: networkTimeout,
//       );

//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
//         await NotificationService()
//             .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
//         await _saveShiftProgress();

//         if (mounted) {
//           if (isEarly) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               backgroundColor: Colors.orange[800],
//               content: const Text(
//                   'Early Departure Recorded. You clocked out early.'),
//             ));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Clock-out successful!')));
//           }
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // NEW CODE START: EMERGENCY CLOCK OUT METHOD
//   // Handles emergency clock-out situations where employees need to leave
//   // immediately due to urgent circumstances (medical, family, safety issues).
//   // 
//   // KEY FEATURES:
//   // - Bypasses photo requirements (no photos needed)
//   // - Bypasses geofence validation (works anywhere)
//   // - Location is optional (recorded if available for audit)
//   // - REQUIRES mandatory emergency reason
//   // - ALWAYS requires manager approval
//   // 
//   // WORKFLOW:
//   // 1. Validate employee is clocked in
//   // 2. Show dialog to collect emergency reason
//   // 3. Attempt to get location (non-blocking)
//   // 4. Call backend emergency clock-out endpoint
//   // 5. Save state and show confirmation
//   // 
//   // WHEN TO USE:
//   // - Medical emergencies
//   // - Family crises
//   // - Safety concerns
//   // - Natural disasters
//   // - Any urgent situation requiring immediate departure
//   Future<void> _handleEmergencyClockOut() async {
//     // STEP 1: VALIDATION - Check if employee is clocked in
//     // Employee must have an active attendance record (clocked in)
//     // Cannot emergency clock-out if not clocked in or already clocked out
//     if (attendanceId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No active shift to clock out from.')),
//       );
//       return;
//     }

//     // STEP 2: COLLECT EMERGENCY REASON - Show dialog to employee
//     // Text controller to capture the emergency reason
//     // This will store the text entered by the employee
//     TextEditingController emergencyReasonController = TextEditingController();

//     // Show confirmation dialog with emergency reason input
//     // barrierDismissible: false means user MUST make a choice (can't tap outside)
//     bool? confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: const Color(0xFF1C2230),
        
//         // DIALOG TITLE - Red warning icon + Emergency Clock Out text
//         title: Row(
//           children: const [
//             Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
//             SizedBox(width: 8),
//             Text(
//               "Emergency Clock Out",
//               style: TextStyle(
//                 color: Colors.redAccent,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
        
//         // DIALOG CONTENT - Warning text + Reason input field
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Explanation text - What is emergency clock-out
//             const Text(
//               "You are about to perform an emergency clock-out. This should only be used in urgent situations.",
//               style: TextStyle(color: Colors.white70, fontSize: 14),
//             ),
//             const SizedBox(height: 16),
            
//             // Warning note - What gets bypassed
//             const Text(
//               "Note: Photos and location checks will be bypassed.",
//               style: TextStyle(color: Colors.orange, fontSize: 13),
//             ),
//             const SizedBox(height: 20),
            
//             // REASON INPUT FIELD - This is MANDATORY
//             // Multi-line text field for employee to explain the emergency
//             // maxLines: 3 allows employee to provide detailed explanation
//             TextField(
//               controller: emergencyReasonController,
//               style: const TextStyle(color: Colors.white),
//               maxLines: 3,
//               decoration: const InputDecoration(
//                 labelText: "Emergency Reason (Required)",
//                 labelStyle: TextStyle(color: Colors.white70),
//                 hintText: "e.g., Family emergency, Medical issue, etc.",
//                 hintStyle: TextStyle(color: Colors.white38),
//                 // Border styling when field is NOT focused
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.white54),
//                 ),
//                 // Border styling when field IS focused
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.redAccent),
//                 ),
//               ),
//             ),
//           ],
//         ),
        
//         // DIALOG ACTIONS - Cancel and Confirm buttons
//         actions: [
//           // Cancel button - Dismiss dialog without action
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text("Cancel"),
//           ),
          
//           // Confirm button - Proceed with emergency clock-out
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//             ),
//             onPressed: () {
//               // INLINE VALIDATION - Check if reason is empty
//               // Trim removes leading/trailing whitespace
//               // isEmpty checks if there's actual content
//               if (emergencyReasonController.text.trim().isEmpty) {
//                 // Show error snackbar if reason is missing
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a reason for emergency clock-out.'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//                 return;
//               }
//               // Reason provided, close dialog and proceed
//               Navigator.pop(ctx, true);
//             },
//             child: const Text("Confirm Emergency Clock Out"),
//           ),
//         ],
//       ),
//     );

//     // CHECK USER DECISION - Did they confirm or cancel?
//     // If user clicked Cancel or dismissed dialog, stop here
//     if (confirmed != true) return;

//     // STEP 3: PROCESS EMERGENCY CLOCK-OUT
//     // Show loading indicator while processing
//     if (mounted) setState(() => isLoading = true);

//     try {
//       // Current time for clock-out timestamp
//       final now = DateTime.now();
      
//       // Variable to store location if available
//       Position? position;

//       // ATTEMPT TO GET LOCATION (NON-BLOCKING)
//       // Try to get employee's current location, but don't fail if unavailable
//       // This is different from regular clock-out which REQUIRES location
//       try {
//         position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         ).timeout(const Duration(seconds: 5));
//       } catch (e) {
//         // Location failed (timeout, GPS off, permission denied, etc.)
//         // Log the error but continue - this is an emergency
//         debugPrint('Location unavailable during emergency clock-out: $e');
//         // position stays null - we'll handle this below
//       }

//       // STEP 4: CALL BACKEND SERVICE - Emergency clock-out API
//       // IMPORTANT: The backend must support the emergency clock-out endpoint
//       // If you get a 404 error, the endpoint doesn't exist yet
//       // You need to implement it on the backend first
//       final result = await _attendanceService.emergencyClockOut(
//         attendanceId: attendanceId!,
//         shiftId: widget.shiftId,
//         emergencyReason: emergencyReasonController.text.trim(),
//         // Location is optional - pass if available, null if not
//         latitude: position?.latitude,
//         longitude: position?.longitude,
//         timeout: networkTimeout,
//       );

//       // STEP 5: HANDLE SUCCESS RESPONSE
//       if (result['success']) {
//         // Update local state to reflect clock-out
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             // Note: No clockOutPhoto because photos are bypassed in emergency
//             clockOutPhoto = null;
//           });
//         }

//         // SEND NOTIFICATION TO MANAGEMENT
//         // Notify supervisors/managers about emergency clock-out
//         // This allows them to follow up immediately
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
        
//         // You may want to create a separate emergency notification method
//         // to distinguish from regular shift completion notifications
//         await NotificationService().sendShiftCompletionNotification(
//           employeeName,
//           widget.shiftId,
//           now,
//         );

//         // Save updated shift progress to local storage
//         await _saveShiftProgress();

//         // SHOW SUCCESS MESSAGE TO EMPLOYEE
//         if (mounted) {
//           // Display distinct emergency clock-out confirmation
//           // Different from regular clock-out to make it clear this was emergency
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.redAccent,
//               duration: const Duration(seconds: 5),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title - Emergency Clock-Out Recorded
//                   const Text(
//                     'Emergency Clock-Out Recorded',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   // Show the reason they entered
//                   Text(
//                     'Reason: ${emergencyReasonController.text.trim()}',
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                   const SizedBox(height: 4),
//                   // Reminder about manager approval
//                   const Text(
//                     'Manager approval required. Please follow up.',
//                     style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//       } else {
//         // Backend returned failure
//         throw Exception(result['error'] ?? 'Unknown emergency clock-out error');
//       }
//     } catch (e) {
//       // ERROR HANDLING
//       // Something went wrong during emergency clock-out
//       debugPrint('Emergency clock-out error: $e');
      
//       if (mounted) {
//         // Show error message to user
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Emergency clock-out failed: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 5),
//           ),
//         );
//       }
//     } finally {
//       // CLEANUP - Always remove loading indicator
//       if (mounted) setState(() => isLoading = false);
//     }
//   }
//   // NEW CODE END

//   Future<void> _handleBreakStart() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.breakStart(attendanceId!, startTime: now);

//       if (result == true) {
//         if (mounted) setState(() => currentBreakStart = now);
//         await _saveShiftProgress();
//         if (mounted) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break started!')));
//         }
//       }
//     } catch (e) {
//       debugPrint('Break start error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _handleBreakEnd() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.endBreak(attendanceId!, endTime: now);

//       if (result == true) {
//         if (mounted) {
//           setState(() {
//             if (currentBreakStart != null) {
//               breaks.add({'start': currentBreakStart!, 'end': now});
//               currentBreakStart = null;
//             }
//           });
//         }
//         await _saveShiftProgress();
//         if (mounted)
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break ended!')));
//       }
//     } catch (e) {
//       debugPrint('Break end error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const Sidenav(),
//       appBar: Uppernavbar(showBackButton: true),
//       body: Stack(
//         children: [
//           Background(),
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Gradienthorizontal(
//                     width: MediaQuery.of(context).size.width,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           _buildShiftInfoCard(),
//                           const SizedBox(height: 24),
//                           if (isActionLoading)
//                             const CircularProgressIndicator()
//                           else if (myStatus == "Pending")
//                             _buildAcknowledgementCard()
//                           else if (myStatus == "Declined")
//                             _buildStatusMessage(
//                                 "You have declined this shift.", Colors.red)
//                           else if (myStatus == "Swap Requested")
//                             _buildStatusMessage(
//                                 "Swap Requested. Waiting for approval.",
//                                 Colors.orange)
//                           else if (myStatus == "Accepted")
//                             _buildTimeTrackingCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTrackingButton() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 16),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           if (currentSite != null) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EmployeeTrackingScreen(
//                   currentSite: currentSite!,
//                   employeeId: widget.employeeId,
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Site location not available.")),
//             );
//           }
//         },
//         icon: const Icon(Icons.map, color: Colors.white),
//         label: const Text("View Live Location Map",
//             style: TextStyle(color: Colors.white)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blueAccent,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   Widget _buildAcknowledgementCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
//       ),
//       child: Column(
//         children: [
//           const Text(
//             "Shift Acknowledgment",
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Please accept this shift to start tracking time.",
//             style: TextStyle(color: Colors.white70),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleDecline,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent),
//                   child: const Text("Decline"),
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleAccept,
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Accept"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           TextButton.icon(
//             onPressed: _handleSwapRequest,
//             icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
//             label: const Text("Request Swap",
//                 style: TextStyle(color: Colors.orangeAccent)),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusMessage(String msg, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         msg,
//         style:
//             TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   Widget _buildShiftInfoCard() {
//     final date = shiftDetails?['Date'];
//     final formattedDate = date != null
//         ? DateFormat.yMMMMd().format(DateTime.parse(date))
//         : 'Loading...';
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.job.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           shiftDetails?['TaskName'] ?? 'Loading...',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Icon(Icons.calendar_month_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Date: $formattedDate',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Start: ${formatTime(widget.scheduledStartTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'End: ${formatTime(widget.scheduledEndTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         if (currentSite != null) ...[
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on,
//                   color: Colors.white.withOpacity(0.9), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   currentSite!.siteName,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.9), fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildTimeTrackingCard() {
//     if (attendanceId == null && clockInTime != null) {
//       _buildDebugButton();
//     }

//     final isBreakEnabled = clockInTime != null && clockOutTime == null;

//     bool isEarlyDeparture = false;
//     if (clockOutTime != null) {
//       final scheduledEnd = _getScheduledEndDateTime();
//       isEarlyDeparture = clockOutTime!
//           .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
//     }

//     return Container(
//       child: Column(
//         children: [
//           Container(width: double.infinity),
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 if (clockOutTime != null) ...[
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: isEarlyDeparture
//                           ? Colors.orange.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isEarlyDeparture
//                             ? Colors.orange.withOpacity(0.5)
//                             : Colors.green.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           isEarlyDeparture
//                               ? Icons.warning_amber_rounded
//                               : Icons.check_circle,
//                           color:
//                               isEarlyDeparture ? Colors.orange : Colors.green,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'Early Departure'
//                                     : 'Shift Completed!',
//                                 style: TextStyle(
//                                   color: isEarlyDeparture
//                                       ? Colors.orange
//                                       : Colors.green,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
//                                     : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
                
//                 // NEW CODE START: CLOCK IN/OUT BUTTONS SECTION WITH EMERGENCY OPTION
//                 if (clockOutTime == null) ...[
//                   // Regular Clock In/Out button (NO CHANGES)
//                   _buildTimeTrackingItem(
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime,
//                     clockInTime == null ? Icons.login : Icons.logout,
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime == null
//                         ? () => _handleClockIn()
//                         : () => _handleClockOut(),
//                     isEnabled: clockOutTime == null,
//                     photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
//                   ),
                  
//                   // NEW CODE: EMERGENCY CLOCK OUT BUTTON UI
//                   // This entire section is NEW - it adds the emergency clock-out button
//                   // 
//                   // VISIBILITY CONDITIONS:
//                   // - Only shown when employee IS clocked in (clockInTime != null)
//                   // - Only shown when employee has NOT clocked out (clockOutTime == null)
//                   // - Hidden in all other states
//                   // 
//                   // POSITIONING:
//                   // - Appears directly below the regular Clock Out button
//                   // - Has 12px spacing above it for visual separation
//                   // 
//                   // STYLING:
//                   // - Red accent color scheme to indicate urgency/emergency
//                   // - Contained in its own bordered box for emphasis
//                   // - Info icon with explanatory text
//                   if (clockInTime != null) ...[
//                     const SizedBox(height: 12),
                    
//                     // Container for Emergency Button - Styled box with red theme
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         // Light red background (10% opacity)
//                         color: Colors.redAccent.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                         // Red border (30% opacity)
//                         border: Border.all(
//                           color: Colors.redAccent.withOpacity(0.3),
//                           width: 1.5,
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // INFO ROW - Explains when to use this button
//                           // Orange info icon + italic text
//                           // Helps users understand this is for emergencies only
//                           Row(
//                             children: const [
//                               Icon(
//                                 Icons.info_outline,
//                                 color: Colors.orange,
//                                 size: 16,
//                               ),
//                               SizedBox(width: 6),
//                               Expanded(
//                                 child: Text(
//                                   "Use only in emergency situations",
//                                   style: TextStyle(
//                                     color: Colors.orange,
//                                     fontSize: 12,
//                                     fontStyle: FontStyle.italic,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
                          
//                           // EMERGENCY CLOCK OUT BUTTON
//                           // The actual button that triggers _handleEmergencyClockOut()
//                           // Full width, fixed height, red background
//                           SizedBox(
//                             width: double.infinity,
//                             height: 48,
//                             child: ElevatedButton.icon(
//                               // BUTTON ACTION - Calls the emergency clock-out method
//                               onPressed: _handleEmergencyClockOut,
                              
//                               // Warning icon - matches the emergency theme
//                               icon: const Icon(
//                                 Icons.warning_amber_rounded,
//                                 size: 20,
//                                 color: Colors.white,
//                               ),
                              
//                               // Button text
//                               label: const Text(
//                                 "Emergency Clock Out",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
                              
//                               // Button styling
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.redAccent,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 elevation: 2,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                   // NEW CODE END
                  
//                 ] else
//                   _buildTimeTrackingItem(
//                     "Clock Out",
//                     clockOutTime,
//                     Icons.logout,
//                     "Shift Completed",
//                     () {},
//                     isEnabled: false,
//                     photo: clockOutPhoto,
//                   ),
                
//                 const SizedBox(height: 16),
                
//                 if (clockInTime != null && clockOutTime == null) ...[
//                   if (currentBreakStart == null)
//                     _buildTimeTrackingItem(
//                       "Start Break",
//                       null,
//                       Icons.free_breakfast,
//                       "Start Break",
//                       _handleBreakStart,
//                       isEnabled: isBreakEnabled,
//                     )
//                   else
//                     _buildTimeTrackingItem(
//                       "End Break",
//                       currentBreakStart,
//                       Icons.task_alt,
//                       "End Break",
//                       _handleBreakEnd,
//                       isEnabled: isBreakEnabled,
//                       customButtonColor: Colors.orangeAccent,
//                       customTextColor: Colors.black,
//                     ),
//                   const SizedBox(height: 16),
//                   _buildLiveTrackingButton(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 if (breaks.isNotEmpty) ...[
//                   _buildBreakHistory(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 if (clockOutTime != null) ...[
//                   _buildShiftSummary(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildShiftSummary() {
//     if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

//     final duration = clockOutTime!.difference(clockInTime!);
//     if (duration.isNegative) {
//       return const Text(
//         'Shift times are invalid (Clock-out before Clock-in)',
//         style: TextStyle(color: Colors.redAccent, fontSize: 14),
//       );
//     }

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.access_time, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Shift Summary',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.login, color: Colors.green, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.logout, color: Colors.red, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.schedule, color: Colors.blue, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Total Time: ${hours}h ${minutes}m',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           if (breaks.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Breaks Taken: ${breaks.length}',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeTrackingItem(
//     String label,
//     DateTime? time,
//     IconData icon,
//     String buttonText,
//     VoidCallback onPressed, {
//     bool? isEnabled,
//     File? photo,
//     Color? customButtonColor,
//     Color? customTextColor,
//   }) {
//     final isRecorded = time != null;
//     final buttonEnabled = isEnabled ?? !isRecorded;

//     final isRedButton = buttonText.toLowerCase().contains("out") ||
//         buttonText.toLowerCase().contains("end");

//     final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
//     final textColor = customTextColor ?? Colors.white;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500),
//               ),
//               const Spacer(),
//               Text(
//                 time != null
//                     ? DateFormat('hh:mm:ss a').format(time)
//                     : "Time: 00:00:00",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               onPressed: buttonEnabled ? onPressed : null,
//               icon: Icon(
//                 buttonText == "Completed" ? Icons.check_circle : icon,
//                 size: 20,
//                 color: buttonEnabled ? textColor : null,
//               ),
//               label: Text(
//                 buttonText,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: buttonEnabled ? textColor : null,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
//                 foregroundColor: textColor,
//                 disabledForegroundColor: Colors.white.withOpacity(0.6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBreakHistory() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Break History',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...breaks.map((breakItem) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Icon(Icons.circle, color: Colors.white70, size: 8),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }















// import 'package:shiftsmart/models/Job.dart';
// import 'package:shiftsmart/models/Site.dart';
// import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
// import 'package:shiftsmart/services/AttendanceService.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/ImagePickerService.dart';
// import 'package:shiftsmart/services/LocationService.dart';
// import 'package:shiftsmart/services/ShiftService.dart';
// import 'package:shiftsmart/services/SiteService.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'dart:async';
// import 'dart:io';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// class Employeeshiftview extends StatefulWidget {
//   final Job job;
//   final int shiftId;
//   final int employeeId;
//   final String scheduledStartTime;
//   final String scheduledEndTime;
//   final LocationService locationService;
//   final ImagePickerService imagePickerService;

//   const Employeeshiftview({
//     super.key,
//     required this.job,
//     required this.shiftId,
//     required this.employeeId,
//     required this.scheduledStartTime,
//     required this.scheduledEndTime,
//     required this.locationService,
//     required this.imagePickerService,
//   });

//   @override
//   State<Employeeshiftview> createState() => _EmployeeshiftviewState();
// }

// class _EmployeeshiftviewState extends State<Employeeshiftview> {
//   List<Map<String, DateTime>> breaks = [];
//   Map<String, dynamic>? shiftDetails;
//   StreamSubscription<Position>? _positionStreamSubscription;
//   DateTime? currentBreakStart;
//   DateTime? clockInTime;
//   DateTime? clockOutTime;
//   bool isClockedIn = false;
//   File? clockInPhoto;
//   File? clockOutPhoto;
//   int? attendanceId;
//   Site? currentSite;
//   bool isLoading = false;

//   String myStatus = "Pending";
//   String? myRejectionReason;
//   bool isActionLoading = false;
//   List<File> _capturedPhotos = [];

//   final SiteService _siteService = SiteService();
//   final AttendanceService _attendanceService = AttendanceService();
//   final ShiftService _shiftService = ShiftService();
//   final LocationService _locationService = RealLocationService();

//   final Color green = const Color.fromARGB(255, 1, 126, 42);
//   static const Duration networkTimeout = Duration(seconds: 30);

//   // ============================================================================
//   // HELPER METHODS (NO CHANGES)
//   // ============================================================================
  
//   String formatTime(String timeString) {
//     try {
//       final time = TimeOfDay(
//         hour: int.parse(timeString.split(':')[0]),
//         minute: int.parse(timeString.split(':')[1]),
//       );
//       return time.format(context);
//     } catch (e) {
//       return timeString;
//     }
//   }

//   DateTime _getScheduledEndDateTime() {
//     final now = DateTime.now();
//     try {
//       String timeStr = widget.scheduledEndTime.trim();
//       int hour = 0;
//       int minute = 0;

//       if (timeStr.toLowerCase().contains("pm") ||
//           timeStr.toLowerCase().contains("am")) {
//         if (timeStr.split(':').length > 2) {
//           timeStr =
//               "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
//         }
//         final dt = DateFormat("h:mm a").parse(timeStr);
//         hour = dt.hour;
//         minute = dt.minute;
//       } else {
//         final parts = timeStr.split(':');
//         hour = int.parse(parts[0]);
//         minute = int.parse(parts[1]);
//       }
//       return DateTime(now.year, now.month, now.day, hour, minute);
//     } catch (e) {
//       debugPrint("Date Parsing Error: $e");
//       return DateTime.now();
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadSiteData();
//     _loadShiftDetailsAndStatus();
//     _loadShiftProgress();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     if (mounted) _disposePhotos();
//     super.dispose();
//   }

//   void _disposePhotos() {
//     clockInPhoto = null;
//     clockOutPhoto = null;
//   }

//   Future<void> _loadShiftDetailsAndStatus() async {
//     try {
//       final myShifts =
//           await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
//       final shift = myShifts.firstWhere(
//         (s) => s['ShiftId'] == widget.shiftId,
//         orElse: () => {},
//       );

//       if (shift.isNotEmpty && mounted) {
//         setState(() {
//           shiftDetails = shift;
//           myStatus = shift['MyStatus'] ?? "Pending";
//           myRejectionReason = shift['MyRejectionReason'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading shift details & status: $e');
//     }
//   }

//   Future<void> _handleAccept() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success =
//           await _shiftService.respondToShift(widget.shiftId, "Accept");
//       if (success) {
//         setState(() => myStatus = "Accepted");
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
//       }
//     } catch (e) {
//       debugPrint("Error accepting shift: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _handleDecline() async {
//     TextEditingController reasonCtrl = TextEditingController();
//     showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Decline Shift",
//                   style: TextStyle(color: Colors.white)),
//               content: TextField(
//                 controller: reasonCtrl,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Reason (Required)",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: Colors.white54)),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel")),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () async {
//                     if (reasonCtrl.text.isEmpty) return;
//                     Navigator.pop(ctx);
//                     setState(() => isActionLoading = true);
//                     bool success = await _shiftService.respondToShift(
//                         widget.shiftId, "Decline",
//                         reason: reasonCtrl.text);
//                     if (success) setState(() => myStatus = "Declined");
//                     setState(() => isActionLoading = false);
//                   },
//                   child: const Text("Decline"),
//                 )
//               ],
//             ));
//   }

//   Future<void> _handleSwapRequest() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success = await _shiftService.requestSwap(widget.shiftId);
//       if (success) {
//         setState(() => myStatus = "Swap Requested");
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Swap Requested Successfully")));
//       }
//     } catch (e) {
//       debugPrint("Error requesting swap: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   Future<void> _loadSiteData() async {
//     setState(() => isLoading = true);
//     try {
//       if (widget.job.siteId == 0 || widget.job.siteId == null) return;
//       final site = await _siteService.fetchSiteById(widget.job.siteId!);
//       if (site != null) currentSite = site;
//     } catch (e) {
//       debugPrint('Error loading site data: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _loadShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = prefs.getString(key);

//     if (progressData != null) {
//       final progress = jsonDecode(progressData);
//       if (mounted) {
//         setState(() {
//           clockInTime = progress['clockInTime'] != null
//               ? DateTime.parse(progress['clockInTime'])
//               : null;
//           clockOutTime = progress['clockOutTime'] != null
//               ? DateTime.parse(progress['clockOutTime'])
//               : null;
//           if (progress['breaks'] != null) {
//             breaks = (progress['breaks'] as List<dynamic>).map((b) {
//               return {
//                 'start': DateTime.parse(b['start']),
//                 'end': DateTime.parse(b['end']),
//               };
//             }).toList();
//           }
//           if (progress['currentBreakStart'] != null) {
//             currentBreakStart =
//                 DateTime.tryParse(progress['currentBreakStart']);
//           }
//           attendanceId = progress['attendanceId'];
//         });
//       }
//     }

//     try {
//       final shift = await _attendanceService.getShiftsByShiftId(
//           widget.employeeId,
//           shiftId: widget.shiftId) as Map<String, dynamic>?;

//       if (shift != null && mounted) {
//         final backendClockInTime = shift['ClockInTime'] != null
//             ? DateTime.tryParse(shift['ClockInTime'])
//             : null;
//         final backendClockOutTime = shift['ClockOutTime'] != null
//             ? DateTime.tryParse(shift['ClockOutTime'])
//             : null;

//         final backendBreakStart = shift['BreakStart'] != null
//             ? DateTime.tryParse(shift['BreakStart'])
//             : null;
//         final backendBreakEnd = shift['BreakEnd'] != null
//             ? DateTime.tryParse(shift['BreakEnd'])
//             : null;

//         if (mounted) {
//           setState(() {
//             if (backendClockInTime != null) {
//               if (attendanceId == null || clockInTime == null) {
//                 clockInTime = backendClockInTime;
//                 attendanceId = shift['AttendanceId'];
//               }
//             }

//             if (backendClockOutTime != null &&
//                 backendClockOutTime.year > 1900) {
//               clockOutTime = backendClockOutTime;
//             }

//             if (backendBreakStart != null) {
//               if (backendBreakEnd == null) {
//                 currentBreakStart = backendBreakStart;
//               } else {
//                 currentBreakStart = null;
//                 bool exists = breaks.any((b) =>
//                     b['start']!.isAtSameMomentAs(backendBreakStart) &&
//                     b['end']!.isAtSameMomentAs(backendBreakEnd!));

//                 if (!exists) {
//                   breaks.add({
//                     'start': backendBreakStart,
//                     'end': backendBreakEnd,
//                   });
//                 }
//               }
//             }
//           });

//           _saveShiftProgress();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching shift status: $e');
//     }
//   }

//   Future<void> _saveShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = {
//       'clockInTime': clockInTime?.toIso8601String(),
//       'clockOutTime': clockOutTime?.toIso8601String(),
//       'breaks': breaks
//           .map((b) => {
//                 'start': b['start']!.toIso8601String(),
//                 'end': b['end']!.toIso8601String()
//               })
//           .toList(),
//       'currentBreakStart': currentBreakStart?.toIso8601String(),
//       'attendanceId': attendanceId,
//     };
//     await prefs.setString(key, jsonEncode(progressData));
//   }

//   Future<bool> _checkLocationPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission != LocationPermission.denied &&
//         permission != LocationPermission.deniedForever;
//   }

//   Future<bool> _validateGeofence() async {
//     if (currentSite == null) return false;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 5),
//       );
//       final siteLat = double.tryParse(currentSite!.latitude ?? '');
//       final siteLng = double.tryParse(currentSite!.longitude ?? '');

//       if (siteLat == null || siteLng == null) return false;

//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         siteLat,
//         siteLng,
//       );
//       return distance <= (currentSite!.radius ?? 150);
//     } catch (e) {
//       debugPrint("Geofence Check Failed: $e");
//       return false;
//     }
//   }

//   Future<bool> _capturePhotos() async {
//     _capturedPhotos.clear();
//     bool done = false;

//     while (!done && _capturedPhotos.length < 5) {
//       final shouldAdd = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: Text("Add Photo (${_capturedPhotos.length}/5)",
//               style: const TextStyle(color: Colors.white)),
//           content: const Text("You must take at least one photo.",
//               style: TextStyle(color: Colors.white70)),
//           actions: [
//             if (_capturedPhotos.isNotEmpty)
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text("Done", style: TextStyle(color: Colors.blue)),
//               ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Take Photo"),
//             ),
//           ],
//         ),
//       );

//       if (shouldAdd == true) {
//         final File? photo = await widget.imagePickerService.pickImage();
//         if (photo != null) {
//           setState(() {
//             _capturedPhotos.add(File(photo.path));
//           });
//         }
//       } else {
//         done = true;
//       }
//     }
//     return _capturedPhotos.isNotEmpty;
//   }

//   Future<void> _clearOldShiftData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     await prefs.remove(key);
//     _capturedPhotos.clear();
//     if (mounted) {
//       setState(() {
//         clockInTime = null;
//         clockOutTime = null;
//         breaks.clear();
//         currentBreakStart = null;
//         attendanceId = null;
//       });
//     }
//   }

//   Future<void> _handleClockIn() async {
//     if (mounted) setState(() => isLoading = true);
//     try {
//       if (!await _checkLocationPermission()) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Location permission is required.')));
//           setState(() => isLoading = false);
//         }
//         return;
//       }

//       bool inRange = await _validateGeofence();
//       if (!inRange) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           showDialog(
//             context: context,
//             builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Out of Range",
//                   style: TextStyle(color: Colors.redAccent)),
//               content: const Text(
//                 "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
//                 style: TextStyle(color: Colors.white70),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text("OK"),
//                 ),
//               ],
//             ),
//           );
//         }
//         return;
//       }

//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final now = DateTime.now();

//       final result = await _attendanceService.clockIn(
//         employeeId: widget.employeeId,
//         shiftId: widget.shiftId,
//         siteId: widget.job.siteId ?? 0,
//         scheduledStartTime: widget.scheduledStartTime,
//         photos: _capturedPhotos,
//         clockInTime: now,
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );

//       if (result['success']) {
//         final attendanceIdFromResponse = result['attendanceId'];
//         if (mounted) {
//           setState(() {
//             clockInTime = now;
//             attendanceId = attendanceIdFromResponse;
//             clockInPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         await _saveShiftProgress();
//         await _sendEmployeeLocation(position);
//         _startLocationTracking();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Clock-in successful!')));
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-in error');
//       }
//     } catch (e) {
//       debugPrint('Clock-in error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   void _startLocationTracking() async {
//     final locationSettings =
//         LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
//     _positionStreamSubscription =
//         Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((Position position) async {
//       await _sendEmployeeLocation(position);
//     });
//   }

//   Future<void> _sendEmployeeLocation(Position position) async {
//     try {
//       await _locationService.sendLocation(position, widget.employeeId);
//     } catch (e) {
//       debugPrint(" Error sending employee location: $e");
//     }
//   }

//   Widget _buildDebugButton() {
//     return ElevatedButton(
//       onPressed: _clearOldShiftData,
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//       child: const Text('Clear Old Data'),
//     );
//   }

//   Future<void> _handleClockOut() async {
//     if (attendanceId == null) return;

//     final now = DateTime.now();
//     final scheduledEnd = _getScheduledEndDateTime();

//     bool isEarly =
//         now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

//     if (isEarly) {
//       bool? confirmEarly = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: const Text("Early Departure Warning",
//               style: TextStyle(color: Colors.orangeAccent)),
//           content: const Text(
//             "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Yes, Clock Out Early"),
//             ),
//           ],
//         ),
//       );

//       if (confirmEarly != true) return;
//     }

//     if (mounted) setState(() => isLoading = true);

//     try {
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: _capturedPhotos,
//         latitude: position.latitude,
//         longitude: position.longitude,
//         timeout: networkTimeout,
//       );

//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
//         await NotificationService()
//             .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
//         await _saveShiftProgress();

//         if (mounted) {
//           if (isEarly) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               backgroundColor: Colors.orange[800],
//               content: const Text(
//                   'Early Departure Recorded. You clocked out early.'),
//             ));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Clock-out successful!')));
//           }
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // ============================================================================
//   // NEW CODE START: EMERGENCY CLOCK OUT METHOD
//   // ============================================================================
//   /// Handles emergency clock-out situations where employees need to leave
//   /// immediately due to urgent circumstances and cannot complete normal
//   /// clock-out requirements (photos, geofence validation).
//   /// 
//   /// FEATURES:
//   /// - Bypasses photo requirements
//   /// - Bypasses geofence validation
//   /// - Location is optional
//   /// - Requires mandatory emergency reason
//   /// - Always requires manager approval
//   /// 
//   /// WORKFLOW:
//   /// 1. Validate employee is clocked in
//   /// 2. Show dialog to collect emergency reason
//   /// 3. Attempt to get location (non-blocking)
//   /// 4. Call backend emergency clock-out endpoint
//   /// 5. Update local state and save progress
//   /// 6. Send notifications to management
//   /// 7. Show confirmation to employee
//   Future<void> _handleEmergencyClockOut() async {
//     // STEP 1: VALIDATION - Check if employee is clocked in
//     if (attendanceId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No active shift to clock out from.'),
//           backgroundColor: Colors.orange,
//           duration: Duration(seconds: 3),
//         ),
//       );
//       return;
//     }

//     // Additional validation - check if already clocked out
//     if (clockOutTime != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You have already clocked out from this shift.'),
//           backgroundColor: Colors.orange,
//           duration: Duration(seconds: 3),
//         ),
//       );
//       return;
//     }

//     // STEP 2: COLLECT EMERGENCY REASON FROM EMPLOYEE
//     TextEditingController emergencyReasonController = TextEditingController();

//     bool? confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: const Color(0xFF1C2230),
        
//         // Dialog title with warning icon
//         title: Row(
//           children: const [
//             Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 "Emergency Clock Out",
//                 style: TextStyle(
//                   color: Colors.redAccent,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 18,
//                 ),
//               ),
//             ),
//           ],
//         ),
        
//         // Dialog content
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Explanation
//               const Text(
//                 "You are about to perform an emergency clock-out. This should only be used in urgent situations such as:",
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 14,
//                   height: 1.4,
//                 ),
//               ),
//               const SizedBox(height: 12),
              
//               // Valid examples container
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: Colors.white.withOpacity(0.1),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     // Medical emergencies
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.local_hospital, color: Colors.redAccent, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Medical emergencies (you or family member)",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Family crises
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.family_restroom, color: Colors.orange, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Family crises or emergencies",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Safety concerns
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.security, color: Colors.yellow, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Safety concerns or dangerous situations",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Natural disasters
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.warning, color: Colors.deepOrange, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Natural disasters or severe weather",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Equipment issues
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.phone_android, color: Colors.blueGrey, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Phone battery dead or equipment failure",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 16),
              
//               // Warning about bypassed requirements
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: Colors.orange.withOpacity(0.3),
//                   ),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     Icon(Icons.info_outline, color: Colors.orange, size: 20),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "Photos and location checks will be bypassed. Manager approval is required.",
//                         style: TextStyle(
//                           color: Colors.orange,
//                           fontSize: 12,
//                           height: 1.3,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
              
//               // Emergency reason input field
//               TextField(
//                 controller: emergencyReasonController,
//                 style: const TextStyle(color: Colors.white),
//                 maxLines: 4,
//                 minLines: 3,
//                 maxLength: 500,
//                 textCapitalization: TextCapitalization.sentences,
//                 keyboardType: TextInputType.multiline,
//                 decoration: const InputDecoration(
//                   labelText: "Emergency Reason (Required)",
//                   labelStyle: TextStyle(color: Colors.white70),
//                   hintText: "Please describe the emergency situation in detail...\n\nExample: Family emergency - received call that my child was injured at school and needs immediate medical attention.",
//                   hintStyle: TextStyle(
//                     color: Colors.white38,
//                     fontSize: 12,
//                   ),
//                   helperText: "Be specific - this will be reviewed by your manager",
//                   helperStyle: TextStyle(
//                     color: Colors.white54,
//                     fontSize: 11,
//                   ),
//                   counterStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white54),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.redAccent, width: 2),
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.red, width: 2),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
              
//               // Additional reminder
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(
//                     color: Colors.red.withOpacity(0.2),
//                   ),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     Icon(Icons.verified_user, color: Colors.red, size: 16),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "This action is logged and requires manager approval. Misuse may result in disciplinary action.",
//                         style: TextStyle(
//                           color: Colors.red,
//                           fontSize: 11,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
        
//         // Dialog actions
//         actions: [
//           // Cancel button
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text(
//               "Cancel",
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 16,
//               ),
//             ),
//           ),
          
//           // Confirm button
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               elevation: 2,
//             ),
//             onPressed: () {
//               // Validation 1: Check if reason is empty
//               if (emergencyReasonController.text.trim().isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a reason for emergency clock-out.'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // Validation 2: Check minimum length
//               if (emergencyReasonController.text.trim().length < 10) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a more detailed emergency reason (at least 10 characters).'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // Validation 3: Check for generic reasons
//               final reason = emergencyReasonController.text.trim().toLowerCase();
//               final vaguePhrases = ['emergency', 'need to go', 'have to leave', 'personal'];
              
//               if (vaguePhrases.any((phrase) => reason == phrase)) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide specific details about the emergency situation.'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // All validations passed
//               Navigator.pop(ctx, true);
//             },
//             child: const Text(
//               "Confirm Emergency Clock Out",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );

//     // STEP 3: CHECK USER DECISION
//     if (confirmed != true) {
//       debugPrint('Emergency clock-out cancelled by user');
//       return;
//     }

//     // STEP 4: PROCESS EMERGENCY CLOCK-OUT
//     if (mounted) setState(() => isLoading = true);

//     try {
//       final now = DateTime.now();
//       Position? position;

//       // STEP 4B: Try to get location (non-blocking)
//       try {
//         debugPrint('Attempting to get GPS location...');
//         position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         ).timeout(const Duration(seconds: 5));
//         debugPrint('✓ GPS location obtained: ${position.latitude}, ${position.longitude}');
//       } catch (locationError) {
//         debugPrint('⚠ Location unavailable during emergency clock-out');
//         debugPrint('Location error: $locationError');
//         debugPrint('Continuing without location data...');
//       }

//       // STEP 5: Call emergency clock-out service
//       debugPrint('Calling emergency clock-out service...');
      
//       final result = await _attendanceService.emergencyClockOut(
//         attendanceId: attendanceId!,
//         shiftId: widget.shiftId,
//         emergencyReason: emergencyReasonController.text.trim(),
//         latitude: position?.latitude,
//         longitude: position?.longitude,
//         timeout: networkTimeout,
//       );

//       // STEP 6: Handle success
//       if (result['success']) {
//         debugPrint('✓ Emergency clock-out service call successful');
        
//         // Update local state
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto = null; // No photo in emergency
//           });
//           debugPrint('Local state updated: clockOutTime set to $now');
//         }

//         // Send notifications
//         try {
//           debugPrint('Sending notification to management...');
//           final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//           final employeeName = employeeNameMap[widget.employeeId] ?? "An employee";
          
//           await NotificationService().sendShiftCompletionNotification(
//             employeeName,
//             widget.shiftId,
//             now,
//           );
//           debugPrint('✓ Notification sent successfully');
//         } catch (notificationError) {
//           debugPrint('⚠ Failed to send notification: $notificationError');
//         }

//         // Save progress
//         try {
//           await _saveShiftProgress();
//           debugPrint('✓ Shift progress saved to local storage');
//         } catch (saveError) {
//           debugPrint('⚠ Failed to save shift progress: $saveError');
//         }

//         // Show success message
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.redAccent,
//               duration: const Duration(seconds: 8),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Success title
//                   const Row(
//                     children: [
//                       Icon(Icons.check_circle, color: Colors.white, size: 22),
//                       SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           'Emergency Clock-Out Recorded',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Reason display
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Emergency Reason:',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           emergencyReasonController.text.trim(),
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Timestamp
//                   Row(
//                     children: [
//                       const Icon(Icons.access_time, size: 14, color: Colors.white70),
//                       const SizedBox(width: 6),
//                       Text(
//                         'Clocked out at ${DateFormat('h:mm a').format(now)}',
//                         style: const TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
                  
//                   // Location status
//                   Row(
//                     children: [
//                       Icon(
//                         position != null ? Icons.location_on : Icons.location_off,
//                         size: 14,
//                         color: Colors.white70,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         position != null ? 'Location recorded' : 'Location unavailable',
//                         style: const TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Next steps
//                   Container(
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Row(
//                           children: [
//                             Icon(Icons.warning_amber_rounded, 
//                               size: 16, color: Colors.orangeAccent),
//                             SizedBox(width: 6),
//                             Text(
//                               'Important Next Steps:',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 6),
//                         Text(
//                           '✓ Manager approval required\n'
//                           '✓ Please contact your supervisor ASAP\n'
//                           '✓ Provide any additional documentation if needed',
//                           style: TextStyle(
//                             fontSize: 11,
//                             height: 1.4,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//       } else {
//         // Backend returned failure
//         debugPrint('✗ Emergency clock-out service returned failure');
//         throw Exception(result['error'] ?? 'Unknown emergency clock-out error');
//       }
//     } catch (e) {
//       // STEP 8: ERROR HANDLING
//       debugPrint('==========================================');
//       debugPrint('✗ EMERGENCY CLOCK-OUT ERROR');
//       debugPrint('==========================================');
//       debugPrint('Error Type: ${e.runtimeType}');
//       debugPrint('Error Message: $e');
//       debugPrint('==========================================');
      
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => AlertDialog(
//             backgroundColor: const Color(0xFF1C2230),
            
//             title: const Row(
//               children: [
//                 Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
//                 SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     'Emergency Clock-Out Failed',
//                     style: TextStyle(
//                       color: Colors.redAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
            
//             content: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Error message
//                   const Text(
//                     'Error Details:',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.red.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                       border: Border.all(color: Colors.red.withOpacity(0.3)),
//                     ),
//                     child: Text(
//                       e.toString(),
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 13,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
                  
//                   // Troubleshooting
//                   const Text(
//                     'What to do next:',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
                  
//                   _buildTroubleshootingStep(
//                     '1',
//                     'Check Internet Connection',
//                     'Make sure you have a stable internet connection and try again.',
//                     Icons.wifi,
//                     Colors.blue,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '2',
//                     'Try Regular Clock-Out',
//                     'If possible, use the regular clock-out button instead.',
//                     Icons.logout,
//                     Colors.green,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '3',
//                     'Contact Your Supervisor',
//                     'Call or message your supervisor immediately to inform them.',
//                     Icons.phone,
//                     Colors.orange,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '4',
//                     'Report to IT Support',
//                     'Contact IT support with the error message shown above.',
//                     Icons.support_agent,
//                     Colors.purple,
//                   ),
//                   const SizedBox(height: 16),
                  
//                   // Emergency contact reminder
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.orange.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                       border: Border.all(color: Colors.orange.withOpacity(0.3)),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Icon(Icons.info_outline, color: Colors.orange, size: 18),
//                         SizedBox(width: 10),
//                         Expanded(
//                           child: Text(
//                             'If this is a true emergency, prioritize your safety first. '
//                             'You can resolve the clock-out issue later with your supervisor.',
//                             style: TextStyle(
//                               color: Colors.orange,
//                               fontSize: 12,
//                               height: 1.4,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(ctx);
//                   _handleEmergencyClockOut();
//                 },
//                 child: const Text(
//                   'Retry',
//                   style: TextStyle(color: Colors.blue),
//                 ),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.redAccent,
//                 ),
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('OK, I Understand'),
//               ),
//             ],
//           ),
//         );
//       }
//     } finally {
//       // STEP 9: CLEANUP
//       if (mounted) {
//         setState(() => isLoading = false);
//         debugPrint('Loading indicator removed');
//       }
//     }
    
//     debugPrint('==========================================');
//     debugPrint('Emergency clock-out method completed');
//     debugPrint('==========================================');
//   }

//   /// Helper method to build troubleshooting steps in error dialog
//   Widget _buildTroubleshootingStep(
//     String number,
//     String title,
//     String description,
//     IconData icon,
//     Color color,
//   ) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           width: 24,
//           height: 24,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//           child: Center(
//             child: Text(
//               number,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Icon(icon, color: color, size: 20),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 13,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 description,
//                 style: const TextStyle(
//                   color: Colors.white60,
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//   // ============================================================================
//   // NEW CODE END: EMERGENCY CLOCK OUT METHOD
//   // ============================================================================

//   Future<void> _handleBreakStart() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.breakStart(attendanceId!, startTime: now);

//       if (result == true) {
//         if (mounted) setState(() => currentBreakStart = now);
//         await _saveShiftProgress();
//         if (mounted) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break started!')));
//         }
//       }
//     } catch (e) {
//       debugPrint('Break start error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _handleBreakEnd() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.endBreak(attendanceId!, endTime: now);

//       if (result == true) {
//         if (mounted) {
//           setState(() {
//             if (currentBreakStart != null) {
//               breaks.add({'start': currentBreakStart!, 'end': now});
//               currentBreakStart = null;
//             }
//           });
//         }
//         await _saveShiftProgress();
//         if (mounted)
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break ended!')));
//       }
//     } catch (e) {
//       debugPrint('Break end error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const Sidenav(),
//       appBar: Uppernavbar(showBackButton: true),
//       body: Stack(
//         children: [
//           Background(),
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Gradienthorizontal(
//                     width: MediaQuery.of(context).size.width,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           _buildShiftInfoCard(),
//                           const SizedBox(height: 24),
//                           if (isActionLoading)
//                             const CircularProgressIndicator()
//                           else if (myStatus == "Pending")
//                             _buildAcknowledgementCard()
//                           else if (myStatus == "Declined")
//                             _buildStatusMessage(
//                                 "You have declined this shift.", Colors.red)
//                           else if (myStatus == "Swap Requested")
//                             _buildStatusMessage(
//                                 "Swap Requested. Waiting for approval.",
//                                 Colors.orange)
//                           else if (myStatus == "Accepted")
//                             _buildTimeTrackingCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTrackingButton() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 16),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           if (currentSite != null) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EmployeeTrackingScreen(
//                   currentSite: currentSite!,
//                   employeeId: widget.employeeId,
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Site location not available.")),
//             );
//           }
//         },
//         icon: const Icon(Icons.map, color: Colors.white),
//         label: const Text("View Live Location Map",
//             style: TextStyle(color: Colors.white)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blueAccent,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   Widget _buildAcknowledgementCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
//       ),
//       child: Column(
//         children: [
//           const Text(
//             "Shift Acknowledgment",
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Please accept this shift to start tracking time.",
//             style: TextStyle(color: Colors.white70),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleDecline,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent),
//                   child: const Text("Decline"),
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleAccept,
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Accept"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           TextButton.icon(
//             onPressed: _handleSwapRequest,
//             icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
//             label: const Text("Request Swap",
//                 style: TextStyle(color: Colors.orangeAccent)),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _buildStatusMessage(String msg, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         msg,
//         style:
//             TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   Widget _buildShiftInfoCard() {
//     final date = shiftDetails?['Date'];
//     final formattedDate = date != null
//         ? DateFormat.yMMMMd().format(DateTime.parse(date))
//         : 'Loading...';
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.job.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           shiftDetails?['TaskName'] ?? 'Loading...',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Icon(Icons.calendar_month_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Date: $formattedDate',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Start: ${formatTime(widget.scheduledStartTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'End: ${formatTime(widget.scheduledEndTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         if (currentSite != null) ...[
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on,
//                   color: Colors.white.withOpacity(0.9), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   currentSite!.siteName,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.9), fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildTimeTrackingCard() {
//     if (attendanceId == null && clockInTime != null) {
//       _buildDebugButton();
//     }

//     final isBreakEnabled = clockInTime != null && clockOutTime == null;

//     bool isEarlyDeparture = false;
//     if (clockOutTime != null) {
//       final scheduledEnd = _getScheduledEndDateTime();
//       isEarlyDeparture = clockOutTime!
//           .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
//     }

//     return Container(
//       child: Column(
//         children: [
//           Container(width: double.infinity),
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 if (clockOutTime != null) ...[
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: isEarlyDeparture
//                           ? Colors.orange.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isEarlyDeparture
//                             ? Colors.orange.withOpacity(0.5)
//                             : Colors.green.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           isEarlyDeparture
//                               ? Icons.warning_amber_rounded
//                               : Icons.check_circle,
//                           color:
//                               isEarlyDeparture ? Colors.orange : Colors.green,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'Early Departure'
//                                     : 'Shift Completed!',
//                                 style: TextStyle(
//                                   color: isEarlyDeparture
//                                       ? Colors.orange
//                                       : Colors.green,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
//                                     : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
                
//                 // ====================================================================
//                 // NEW CODE START: CLOCK IN/OUT BUTTONS WITH EMERGENCY OPTION
//                 // ====================================================================
//                 if (clockOutTime == null) ...[
//                   // Regular Clock In/Out button (EXISTING CODE - NO CHANGES)
//                   _buildTimeTrackingItem(
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime,
//                     clockInTime == null ? Icons.login : Icons.logout,
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime == null
//                         ? () => _handleClockIn()
//                         : () => _handleClockOut(),
//                     isEnabled: clockOutTime == null,
//                     photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
//                   ),
                  
//                   // NEW CODE: EMERGENCY CLOCK OUT BUTTON
//                   // Only shown when employee is clocked in
//                   if (clockInTime != null) ...[
//                     const SizedBox(height: 12),
                    
//                     // Emergency button container
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.redAccent.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: Colors.redAccent.withOpacity(0.3),
//                           width: 1.5,
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Info row explaining when to use
//                           Row(
//                             children: const [
//                               Icon(
//                                 Icons.info_outline,
//                                 color: Colors.orange,
//                                 size: 16,
//                               ),
//                               SizedBox(width: 6),
//                               Expanded(
//                                 child: Text(
//                                   "Use only in emergency situations (medical, safety, family crisis)",
//                                   style: TextStyle(
//                                     color: Colors.orange,
//                                     fontSize: 12,
//                                     fontStyle: FontStyle.italic,
//                                     height: 1.3,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
                          
//                           // Emergency clock out button
//                           SizedBox(
//                             width: double.infinity,
//                             height: 48,
//                             child: ElevatedButton.icon(
//                               onPressed: _handleEmergencyClockOut,
//                               icon: const Icon(
//                                 Icons.warning_amber_rounded,
//                                 size: 20,
//                                 color: Colors.white,
//                               ),
//                               label: const Text(
//                                 "Emergency Clock Out",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.redAccent,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 elevation: 2,
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 16,
//                                   vertical: 12,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                   // NEW CODE END
//                 ] else
//                   _buildTimeTrackingItem(
//                     "Clock Out",
//                     clockOutTime,
//                     Icons.logout,
//                     "Shift Completed",
//                     () {},
//                     isEnabled: false,
//                     photo: clockOutPhoto,
//                   ),
//                 // ====================================================================
//                 // NEW CODE END: CLOCK IN/OUT BUTTONS WITH EMERGENCY OPTION
//                 // ====================================================================
                
//                 const SizedBox(height: 16),
                
//                 if (clockInTime != null && clockOutTime == null) ...[
//                   if (currentBreakStart == null)
//                     _buildTimeTrackingItem(
//                       "Start Break",
//                       null,
//                       Icons.free_breakfast,
//                       "Start Break",
//                       _handleBreakStart,
//                       isEnabled: isBreakEnabled,
//                     )
//                   else
//                     _buildTimeTrackingItem(
//                       "End Break",
//                       currentBreakStart,
//                       Icons.task_alt,
//                       "End Break",
//                       _handleBreakEnd,
//                       isEnabled: isBreakEnabled,
//                       customButtonColor: Colors.orangeAccent,
//                       customTextColor: Colors.black,
//                     ),
//                   const SizedBox(height: 16),
//                   _buildLiveTrackingButton(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 if (breaks.isNotEmpty) ...[
//                   _buildBreakHistory(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 if (clockOutTime != null) ...[
//                   _buildShiftSummary(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildShiftSummary() {
//     if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

//     final duration = clockOutTime!.difference(clockInTime!);
//     if (duration.isNegative) {
//       return const Text(
//         'Shift times are invalid (Clock-out before Clock-in)',
//         style: TextStyle(color: Colors.redAccent, fontSize: 14),
//       );
//     }

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.access_time, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Shift Summary',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.login, color: Colors.green, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.logout, color: Colors.red, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.schedule, color: Colors.blue, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Total Time: ${hours}h ${minutes}m',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           if (breaks.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Breaks Taken: ${breaks.length}',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeTrackingItem(
//     String label,
//     DateTime? time,
//     IconData icon,
//     String buttonText,
//     VoidCallback onPressed, {
//     bool? isEnabled,
//     File? photo,
//     Color? customButtonColor,
//     Color? customTextColor,
//   }) {
//     final isRecorded = time != null;
//     final buttonEnabled = isEnabled ?? !isRecorded;

//     final isRedButton = buttonText.toLowerCase().contains("out") ||
//         buttonText.toLowerCase().contains("end");

//     final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
//     final textColor = customTextColor ?? Colors.white;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500),
//               ),
//               const Spacer(),
//               Text(
//                 time != null
//                     ? DateFormat('hh:mm:ss a').format(time)
//                     : "Time: 00:00:00",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               onPressed: buttonEnabled ? onPressed : null,
//               icon: Icon(
//                 buttonText == "Completed" ? Icons.check_circle : icon,
//                 size: 20,
//                 color: buttonEnabled ? textColor : null,
//               ),
//               label: Text(
//                 buttonText,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: buttonEnabled ? textColor : null,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
//                 foregroundColor: textColor,
//                 disabledForegroundColor: Colors.white.withOpacity(0.6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBreakHistory() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Break History',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...breaks.map((breakItem) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Icon(Icons.circle, color: Colors.white70, size: 8),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }

















// import 'package:shiftsmart/models/Job.dart';
// import 'package:shiftsmart/models/Site.dart';
// import 'package:shiftsmart/screens/employee/EmployeeTrackingScreen.dart';
// import 'package:shiftsmart/services/AttendanceService.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/ImagePickerService.dart';
// import 'package:shiftsmart/services/LocationService.dart';
// import 'package:shiftsmart/services/ShiftService.dart';
// import 'package:shiftsmart/services/SiteService.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'dart:async';
// import 'dart:io';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// /// Employee Shift View Screen
// /// Displays shift details and allows employees to clock in/out, take breaks,
// /// and perform emergency clock-outs when necessary.
// class Employeeshiftview extends StatefulWidget {
//   final Job job;
//   final int shiftId;
//   final int employeeId;
//   final String scheduledStartTime;
//   final String scheduledEndTime;
//   final LocationService locationService;
//   final ImagePickerService imagePickerService;

//   const Employeeshiftview({
//     super.key,
//     required this.job,
//     required this.shiftId,
//     required this.employeeId,
//     required this.scheduledStartTime,
//     required this.scheduledEndTime,
//     required this.locationService,
//     required this.imagePickerService,
//   });

//   @override
//   State<Employeeshiftview> createState() => _EmployeeshiftviewState();
// }

// class _EmployeeshiftviewState extends State<Employeeshiftview> {
//   // ============================================================================
//   // STATE VARIABLES
//   // ============================================================================
  
//   List<Map<String, DateTime>> breaks = [];
//   Map<String, dynamic>? shiftDetails;
//   StreamSubscription<Position>? _positionStreamSubscription;
//   DateTime? currentBreakStart;
//   DateTime? clockInTime;
//   DateTime? clockOutTime;
//   bool isClockedIn = false;
//   File? clockInPhoto;
//   File? clockOutPhoto;
//   int? attendanceId;
//   Site? currentSite;
//   bool isLoading = false;

//   String myStatus = "Pending";
//   String? myRejectionReason;
//   bool isActionLoading = false;
//   List<File> _capturedPhotos = [];

//   // Services
//   final SiteService _siteService = SiteService();
//   final AttendanceService _attendanceService = AttendanceService();
//   final ShiftService _shiftService = ShiftService();
//   final LocationService _locationService = RealLocationService();

//   // Constants
//   final Color green = const Color.fromARGB(255, 1, 126, 42);
//   static const Duration networkTimeout = Duration(seconds: 30);

//   // ============================================================================
//   // LIFECYCLE METHODS
//   // ============================================================================
  
//   @override
//   void initState() {
//     super.initState();
//     _loadSiteData();
//     _loadShiftDetailsAndStatus();
//     _loadShiftProgress();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _positionStreamSubscription?.cancel();
//     if (mounted) _disposePhotos();
//     super.dispose();
//   }

//   void _disposePhotos() {
//     clockInPhoto = null;
//     clockOutPhoto = null;
//   }

//   // ============================================================================
//   // HELPER METHODS
//   // ============================================================================
  
//   /// Formats time string to user-friendly format
//   String formatTime(String timeString) {
//     try {
//       final time = TimeOfDay(
//         hour: int.parse(timeString.split(':')[0]),
//         minute: int.parse(timeString.split(':')[1]),
//       );
//       return time.format(context);
//     } catch (e) {
//       return timeString;
//     }
//   }

//   /// Gets the scheduled end time as DateTime object
//   DateTime _getScheduledEndDateTime() {
//     final now = DateTime.now();
//     try {
//       String timeStr = widget.scheduledEndTime.trim();
//       int hour = 0;
//       int minute = 0;

//       if (timeStr.toLowerCase().contains("pm") ||
//           timeStr.toLowerCase().contains("am")) {
//         if (timeStr.split(':').length > 2) {
//           timeStr =
//               "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
//         }
//         final dt = DateFormat("h:mm a").parse(timeStr);
//         hour = dt.hour;
//         minute = dt.minute;
//       } else {
//         final parts = timeStr.split(':');
//         hour = int.parse(parts[0]);
//         minute = int.parse(parts[1]);
//       }
//       return DateTime(now.year, now.month, now.day, hour, minute);
//     } catch (e) {
//       debugPrint("Date Parsing Error: $e");
//       return DateTime.now();
//     }
//   }

//   // ============================================================================
//   // DATA LOADING METHODS
//   // ============================================================================
  
//   /// Loads shift details and current status from backend
//   Future<void> _loadShiftDetailsAndStatus() async {
//     try {
//       final myShifts =
//           await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
//       final shift = myShifts.firstWhere(
//         (s) => s['ShiftId'] == widget.shiftId,
//         orElse: () => {},
//       );

//       if (shift.isNotEmpty && mounted) {
//         setState(() {
//           shiftDetails = shift;
//           myStatus = shift['MyStatus'] ?? "Pending";
//           myRejectionReason = shift['MyRejectionReason'];
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading shift details & status: $e');
//     }
//   }

//   /// Loads site information
//   Future<void> _loadSiteData() async {
//     setState(() => isLoading = true);
//     try {
//       if (widget.job.siteId == 0 || widget.job.siteId == null) return;
//       final site = await _siteService.fetchSiteById(widget.job.siteId!);
//       if (site != null) currentSite = site;
//     } catch (e) {
//       debugPrint('Error loading site data: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   /// Loads shift progress from local storage and syncs with backend
//   Future<void> _loadShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = prefs.getString(key);

//     // Load from local storage
//     if (progressData != null) {
//       final progress = jsonDecode(progressData);
//       if (mounted) {
//         setState(() {
//           clockInTime = progress['clockInTime'] != null
//               ? DateTime.parse(progress['clockInTime'])
//               : null;
//           clockOutTime = progress['clockOutTime'] != null
//               ? DateTime.parse(progress['clockOutTime'])
//               : null;
//           if (progress['breaks'] != null) {
//             breaks = (progress['breaks'] as List<dynamic>).map((b) {
//               return {
//                 'start': DateTime.parse(b['start']),
//                 'end': DateTime.parse(b['end']),
//               };
//             }).toList();
//           }
//           if (progress['currentBreakStart'] != null) {
//             currentBreakStart =
//                 DateTime.tryParse(progress['currentBreakStart']);
//           }
//           attendanceId = progress['attendanceId'];
//         });
//       }
//     }

//     // Sync with backend
//     try {
//       final shift = await _attendanceService.getShiftsByShiftId(
//           widget.employeeId,
//           shiftId: widget.shiftId) as Map<String, dynamic>?;

//       if (shift != null && mounted) {
//         final backendClockInTime = shift['ClockInTime'] != null
//             ? DateTime.tryParse(shift['ClockInTime'])
//             : null;
//         final backendClockOutTime = shift['ClockOutTime'] != null
//             ? DateTime.tryParse(shift['ClockOutTime'])
//             : null;

//         final backendBreakStart = shift['BreakStart'] != null
//             ? DateTime.tryParse(shift['BreakStart'])
//             : null;
//         final backendBreakEnd = shift['BreakEnd'] != null
//             ? DateTime.tryParse(shift['BreakEnd'])
//             : null;

//         if (mounted) {
//           setState(() {
//             if (backendClockInTime != null) {
//               if (attendanceId == null || clockInTime == null) {
//                 clockInTime = backendClockInTime;
//                 attendanceId = shift['AttendanceId'];
//               }
//             }

//             if (backendClockOutTime != null &&
//                 backendClockOutTime.year > 1900) {
//               clockOutTime = backendClockOutTime;
//             }

//             if (backendBreakStart != null) {
//               if (backendBreakEnd == null) {
//                 currentBreakStart = backendBreakStart;
//               } else {
//                 currentBreakStart = null;
//                 bool exists = breaks.any((b) =>
//                     b['start']!.isAtSameMomentAs(backendBreakStart) &&
//                     b['end']!.isAtSameMomentAs(backendBreakEnd!));

//                 if (!exists) {
//                   breaks.add({
//                     'start': backendBreakStart,
//                     'end': backendBreakEnd,
//                   });
//                 }
//               }
//             }
//           });

//           _saveShiftProgress();
//         }
//       }
//     } catch (e) {
//       debugPrint('Error fetching shift status: $e');
//     }
//   }

//   /// Saves current shift progress to local storage
//   Future<void> _saveShiftProgress() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     final progressData = {
//       'clockInTime': clockInTime?.toIso8601String(),
//       'clockOutTime': clockOutTime?.toIso8601String(),
//       'breaks': breaks
//           .map((b) => {
//                 'start': b['start']!.toIso8601String(),
//                 'end': b['end']!.toIso8601String()
//               })
//           .toList(),
//       'currentBreakStart': currentBreakStart?.toIso8601String(),
//       'attendanceId': attendanceId,
//     };
//     await prefs.setString(key, jsonEncode(progressData));
//   }

//   /// Clears old shift data from local storage
//   Future<void> _clearOldShiftData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
//     await prefs.remove(key);
//     _capturedPhotos.clear();
//     if (mounted) {
//       setState(() {
//         clockInTime = null;
//         clockOutTime = null;
//         breaks.clear();
//         currentBreakStart = null;
//         attendanceId = null;
//       });
//     }
//   }

//   // ============================================================================
//   // SHIFT ACTION HANDLERS (Accept/Decline/Swap)
//   // ============================================================================
  
//   /// Handles shift acceptance
//   Future<void> _handleAccept() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success =
//           await _shiftService.respondToShift(widget.shiftId, "Accept");
//       if (success) {
//         setState(() => myStatus = "Accepted");
//         ScaffoldMessenger.of(context)
//             .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
//       }
//     } catch (e) {
//       debugPrint("Error accepting shift: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   /// Handles shift decline with reason
//   Future<void> _handleDecline() async {
//     TextEditingController reasonCtrl = TextEditingController();
//     showDialog(
//         context: context,
//         builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Decline Shift",
//                   style: TextStyle(color: Colors.white)),
//               content: TextField(
//                 controller: reasonCtrl,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Reason (Required)",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: UnderlineInputBorder(
//                       borderSide: BorderSide(color: Colors.white54)),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                     onPressed: () => Navigator.pop(ctx),
//                     child: const Text("Cancel")),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () async {
//                     if (reasonCtrl.text.isEmpty) return;
//                     Navigator.pop(ctx);
//                     setState(() => isActionLoading = true);
//                     bool success = await _shiftService.respondToShift(
//                         widget.shiftId, "Decline",
//                         reason: reasonCtrl.text);
//                     if (success) setState(() => myStatus = "Declined");
//                     setState(() => isActionLoading = false);
//                   },
//                   child: const Text("Decline"),
//                 )
//               ],
//             ));
//   }

//   /// Handles shift swap request
//   Future<void> _handleSwapRequest() async {
//     setState(() => isActionLoading = true);
//     try {
//       bool success = await _shiftService.requestSwap(widget.shiftId);
//       if (success) {
//         setState(() => myStatus = "Swap Requested");
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Swap Requested Successfully")));
//       }
//     } catch (e) {
//       debugPrint("Error requesting swap: $e");
//     } finally {
//       setState(() => isActionLoading = false);
//     }
//   }

//   // ============================================================================
//   // LOCATION & PERMISSION METHODS
//   // ============================================================================
  
//   /// Checks if location permissions are granted
//   Future<bool> _checkLocationPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission != LocationPermission.denied &&
//         permission != LocationPermission.deniedForever;
//   }

//   /// Validates if employee is within geofence radius
//   Future<bool> _validateGeofence() async {
//     if (currentSite == null) return false;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 5),
//       );
//       final siteLat = double.tryParse(currentSite!.latitude ?? '');
//       final siteLng = double.tryParse(currentSite!.longitude ?? '');

//       if (siteLat == null || siteLng == null) return false;

//       final distance = Geolocator.distanceBetween(
//         position.latitude,
//         position.longitude,
//         siteLat,
//         siteLng,
//       );
//       return distance <= (currentSite!.radius ?? 150);
//     } catch (e) {
//       debugPrint("Geofence Check Failed: $e");
//       return false;
//     }
//   }

//   /// Starts continuous location tracking
//   void _startLocationTracking() async {
//     final locationSettings =
//         LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
//     _positionStreamSubscription =
//         Geolocator.getPositionStream(locationSettings: locationSettings)
//             .listen((Position position) async {
//       await _sendEmployeeLocation(position);
//     });
//   }

//   /// Sends employee location to backend
//   Future<void> _sendEmployeeLocation(Position position) async {
//     try {
//       await _locationService.sendLocation(position, widget.employeeId);
//     } catch (e) {
//       debugPrint("Error sending employee location: $e");
//     }
//   }

//   // ============================================================================
//   // PHOTO CAPTURE METHODS
//   // ============================================================================
  
//   /// Captures photos for clock in/out
//   Future<bool> _capturePhotos() async {
//     _capturedPhotos.clear();
//     bool done = false;

//     while (!done && _capturedPhotos.length < 5) {
//       final shouldAdd = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: Text("Add Photo (${_capturedPhotos.length}/5)",
//               style: const TextStyle(color: Colors.white)),
//           content: const Text("You must take at least one photo.",
//               style: TextStyle(color: Colors.white70)),
//           actions: [
//             if (_capturedPhotos.isNotEmpty)
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text("Done", style: TextStyle(color: Colors.blue)),
//               ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Take Photo"),
//             ),
//           ],
//         ),
//       );

//       if (shouldAdd == true) {
//         final File? photo = await widget.imagePickerService.pickImage();
//         if (photo != null) {
//           setState(() {
//             _capturedPhotos.add(File(photo.path));
//           });
//         }
//       } else {
//         done = true;
//       }
//     }
//     return _capturedPhotos.isNotEmpty;
//   }

//   // ============================================================================
//   // REGULAR CLOCK IN/OUT METHODS
//   // ============================================================================
  
//   /// Handles regular clock in with location and photo verification
//   Future<void> _handleClockIn() async {
//     if (mounted) setState(() => isLoading = true);
//     try {
//       // Check location permission
//       if (!await _checkLocationPermission()) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Location permission is required.')));
//           setState(() => isLoading = false);
//         }
//         return;
//       }

//       // Validate geofence
//       bool inRange = await _validateGeofence();
//       if (!inRange) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           showDialog(
//             context: context,
//             builder: (ctx) => AlertDialog(
//               backgroundColor: const Color(0xFF1C2230),
//               title: const Text("Out of Range",
//                   style: TextStyle(color: Colors.redAccent)),
//               content: const Text(
//                 "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
//                 style: TextStyle(color: Colors.white70),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(ctx),
//                   child: const Text("OK"),
//                 ),
//               ],
//             ),
//           );
//         }
//         return;
//       }

//       // Capture photos
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       // Get current position
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       final now = DateTime.now();

//       // Call clock in service
//       final result = await _attendanceService.clockIn(
//         employeeId: widget.employeeId,
//         shiftId: widget.shiftId,
//         siteId: widget.job.siteId ?? 0,
//         scheduledStartTime: widget.scheduledStartTime,
//         photos: _capturedPhotos,
//         clockInTime: now,
//         latitude: position.latitude,
//         longitude: position.longitude,
//       );

//       if (result['success']) {
//         final attendanceIdFromResponse = result['attendanceId'];
//         if (mounted) {
//           setState(() {
//             clockInTime = now;
//             attendanceId = attendanceIdFromResponse;
//             clockInPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
//         await _saveShiftProgress();
//         await _sendEmployeeLocation(position);
//         _startLocationTracking();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Clock-in successful!')));
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-in error');
//       }
//     } catch (e) {
//       debugPrint('Clock-in error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   /// Handles regular clock out with early departure detection
//   Future<void> _handleClockOut() async {
//     if (attendanceId == null) return;

//     final now = DateTime.now();
//     final scheduledEnd = _getScheduledEndDateTime();

//     // Check for early departure
//     bool isEarly =
//         now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));

//     if (isEarly) {
//       bool? confirmEarly = await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: const Color(0xFF1C2230),
//           title: const Text("Early Departure Warning",
//               style: TextStyle(color: Colors.orangeAccent)),
//           content: const Text(
//             "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
//             style: TextStyle(color: Colors.white70),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text("Cancel"),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text("Yes, Clock Out Early"),
//             ),
//           ],
//         ),
//       );

//       if (confirmEarly != true) return;
//     }

//     if (mounted) setState(() => isLoading = true);

//     try {
//       // Capture photos
//       bool hasPhotos = await _capturePhotos();
//       if (!hasPhotos) {
//         if (mounted) {
//           setState(() => isLoading = false);
//           ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('At least one photo is required.')));
//         }
//         return;
//       }

//       // Get current position
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       // Call clock out service
//       final result = await _attendanceService.clockOut(
//         attendanceId: attendanceId!,
//         clockOutTime: now,
//         photos: _capturedPhotos,
//         latitude: position.latitude,
//         longitude: position.longitude,
//         timeout: networkTimeout,
//       );

//       if (result['success']) {
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto =
//                 _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
//           });
//         }
        
//         // Send notification
//         final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//         final employeeName =
//             employeeNameMap[widget.employeeId] ?? "An employee";
//         await NotificationService()
//             .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
//         await _saveShiftProgress();

//         if (mounted) {
//           if (isEarly) {
//             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//               backgroundColor: Colors.orange[800],
//               content: const Text(
//                   'Early Departure Recorded. You clocked out early.'),
//             ));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Clock-out successful!')));
//           }
//         }
//       } else {
//         throw Exception(result['error'] ?? 'Unknown clock-out error');
//       }
//     } catch (e) {
//       debugPrint('Clock-out error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // ============================================================================
//   // ✨ NEW FEATURE: EMERGENCY CLOCK OUT METHOD ✨
//   // ============================================================================
//   /// Handles emergency clock-out situations where employees need to leave
//   /// immediately due to urgent circumstances and cannot complete normal
//   /// clock-out requirements (photos, geofence validation).
//   /// 
//   /// FEATURES:
//   /// - Bypasses photo requirements
//   /// - Bypasses geofence validation
//   /// - Location is optional (non-blocking)
//   /// - Requires mandatory emergency reason
//   /// - Always requires manager approval
//   /// 
//   /// WORKFLOW:
//   /// 1. Validate employee is clocked in
//   /// 2. Show dialog to collect emergency reason
//   /// 3. Attempt to get location (non-blocking)
//   /// 4. Call backend emergency clock-out endpoint
//   /// 5. Update local state and save progress
//   /// 6. Send notifications to management
//   /// 7. Show confirmation to employee
//   Future<void> _handleEmergencyClockOut() async {
//     // STEP 1: VALIDATION - Check if employee is clocked in
//     if (attendanceId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No active shift to clock out from.'),
//           backgroundColor: Colors.orange,
//           duration: Duration(seconds: 3),
//         ),
//       );
//       return;
//     }

//     // Additional validation - check if already clocked out
//     if (clockOutTime != null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You have already clocked out from this shift.'),
//           backgroundColor: Colors.orange,
//           duration: Duration(seconds: 3),
//         ),
//       );
//       return;
//     }

//     // STEP 2: COLLECT EMERGENCY REASON FROM EMPLOYEE
//     TextEditingController emergencyReasonController = TextEditingController();

//     bool? confirmed = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: const Color(0xFF1C2230),
        
//         // Dialog title with warning icon
//         title: Row(
//           children: const [
//             Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 "Emergency Clock Out",
//                 style: TextStyle(
//                   color: Colors.redAccent,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 18,
//                 ),
//               ),
//             ),
//           ],
//         ),
        
//         // Dialog content
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Explanation
//               const Text(
//                 "You are about to perform an emergency clock-out. This should only be used in urgent situations such as:",
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 14,
//                   height: 1.4,
//                 ),
//               ),
//               const SizedBox(height: 12),
              
//               // Valid examples container
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: Colors.white.withOpacity(0.1),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     // Medical emergencies
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.local_hospital, color: Colors.redAccent, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Medical emergencies (you or family member)",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Family crises
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.family_restroom, color: Colors.orange, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Family crises or emergencies",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Safety concerns
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.security, color: Colors.yellow, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Safety concerns or dangerous situations",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Natural disasters
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.warning, color: Colors.deepOrange, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Natural disasters or severe weather",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Equipment issues
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(Icons.phone_android, color: Colors.blueGrey, size: 16),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             "Phone battery dead or equipment failure",
//                             style: TextStyle(color: Colors.white60, fontSize: 13),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 16),
              
//               // Warning about bypassed requirements
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: Colors.orange.withOpacity(0.3),
//                   ),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     Icon(Icons.info_outline, color: Colors.orange, size: 20),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "Photos and location checks will be bypassed. Manager approval is required.",
//                         style: TextStyle(
//                           color: Colors.orange,
//                           fontSize: 12,
//                           height: 1.3,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
              
//               // Emergency reason input field
//               TextField(
//                 controller: emergencyReasonController,
//                 style: const TextStyle(color: Colors.white),
//                 maxLines: 4,
//                 minLines: 3,
//                 maxLength: 500,
//                 textCapitalization: TextCapitalization.sentences,
//                 keyboardType: TextInputType.multiline,
//                 decoration: const InputDecoration(
//                   labelText: "Emergency Reason (Required)",
//                   labelStyle: TextStyle(color: Colors.white70),
//                   hintText: "Please describe the emergency situation in detail...\n\nExample: Family emergency - received call that my child was injured at school and needs immediate medical attention.",
//                   hintStyle: TextStyle(
//                     color: Colors.white38,
//                     fontSize: 12,
//                   ),
//                   helperText: "Be specific - this will be reviewed by your manager",
//                   helperStyle: TextStyle(
//                     color: Colors.white54,
//                     fontSize: 11,
//                   ),
//                   counterStyle: TextStyle(color: Colors.white54),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.white54),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.redAccent, width: 2),
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.red, width: 2),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
              
//               // Additional reminder
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(
//                     color: Colors.red.withOpacity(0.2),
//                   ),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     Icon(Icons.verified_user, color: Colors.red, size: 16),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "This action is logged and requires manager approval. Misuse may result in disciplinary action.",
//                         style: TextStyle(
//                           color: Colors.red,
//                           fontSize: 11,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
        
//         // Dialog actions
//         actions: [
//           // Cancel button
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text(
//               "Cancel",
//               style: TextStyle(
//                 color: Colors.white70,
//                 fontSize: 16,
//               ),
//             ),
//           ),
          
//           // Confirm button
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               elevation: 2,
//             ),
//             onPressed: () {
//               // Validation 1: Check if reason is empty
//               if (emergencyReasonController.text.trim().isEmpty) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a reason for emergency clock-out.'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // Validation 2: Check minimum length
//               if (emergencyReasonController.text.trim().length < 10) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide a more detailed emergency reason (at least 10 characters).'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // Validation 3: Check for generic reasons
//               final reason = emergencyReasonController.text.trim().toLowerCase();
//               final vaguePhrases = ['emergency', 'need to go', 'have to leave', 'personal'];
              
//               if (vaguePhrases.any((phrase) => reason == phrase)) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Please provide specific details about the emergency situation.'),
//                     backgroundColor: Colors.red,
//                     duration: Duration(seconds: 3),
//                   ),
//                 );
//                 return;
//               }
              
//               // All validations passed
//               Navigator.pop(ctx, true);
//             },
//             child: const Text(
//               "Confirm Emergency Clock Out",
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );

//     // STEP 3: CHECK USER DECISION
//     if (confirmed != true) {
//       debugPrint('Emergency clock-out cancelled by user');
//       return;
//     }

//     // STEP 4: PROCESS EMERGENCY CLOCK-OUT
//     if (mounted) setState(() => isLoading = true);

//     try {
//       final now = DateTime.now();
//       Position? position;

//       // STEP 4B: Try to get location (non-blocking)
//       try {
//         debugPrint('Attempting to get GPS location...');
//         position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         ).timeout(const Duration(seconds: 5));
//         debugPrint('✓ GPS location obtained: ${position.latitude}, ${position.longitude}');
//       } catch (locationError) {
//         debugPrint('⚠ Location unavailable during emergency clock-out');
//         debugPrint('Location error: $locationError');
//         debugPrint('Continuing without location data...');
//       }

//       // STEP 5: Call emergency clock-out service
//       debugPrint('Calling emergency clock-out service...');
      
//       final result = await _attendanceService.emergencyClockOut(
//         attendanceId: attendanceId!,
//         shiftId: widget.shiftId,
//         emergencyReason: emergencyReasonController.text.trim(),
//         latitude: position?.latitude,
//         longitude: position?.longitude,
//         timeout: networkTimeout,
//       );

//       // STEP 6: Handle success
//       if (result['success']) {
//         debugPrint('✓ Emergency clock-out service call successful');
        
//         // Update local state
//         if (mounted) {
//           setState(() {
//             clockOutTime = now;
//             clockOutPhoto = null; // No photo in emergency
//           });
//           debugPrint('Local state updated: clockOutTime set to $now');
//         }

//         // Send notifications
//         try {
//           debugPrint('Sending notification to management...');
//           final employeeNameMap = await EmployeeService().fetchEmployeeNameMap();
//           final employeeName = employeeNameMap[widget.employeeId] ?? "An employee";
          
//           await NotificationService().sendShiftCompletionNotification(
//             employeeName,
//             widget.shiftId,
//             now,
//           );
//           debugPrint('✓ Notification sent successfully');
//         } catch (notificationError) {
//           debugPrint('⚠ Failed to send notification: $notificationError');
//         }

//         // Save progress
//         try {
//           await _saveShiftProgress();
//           debugPrint('✓ Shift progress saved to local storage');
//         } catch (saveError) {
//           debugPrint('⚠ Failed to save shift progress: $saveError');
//         }

//         // Show success message
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.redAccent,
//               duration: const Duration(seconds: 8),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Success title
//                   const Row(
//                     children: [
//                       Icon(Icons.check_circle, color: Colors.white, size: 22),
//                       SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           'Emergency Clock-Out Recorded',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Reason display
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Emergency Reason:',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           emergencyReasonController.text.trim(),
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Timestamp
//                   Row(
//                     children: [
//                       const Icon(Icons.access_time, size: 14, color: Colors.white70),
//                       const SizedBox(width: 6),
//                       Text(
//                         'Clocked out at ${DateFormat('h:mm a').format(now)}',
//                         style: const TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
                  
//                   // Location status
//                   Row(
//                     children: [
//                       Icon(
//                         position != null ? Icons.location_on : Icons.location_off,
//                         size: 14,
//                         color: Colors.white70,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         position != null ? 'Location recorded' : 'Location unavailable',
//                         style: const TextStyle(fontSize: 12, color: Colors.white70),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
                  
//                   // Next steps
//                   Container(
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Row(
//                           children: [
//                             Icon(Icons.warning_amber_rounded, 
//                               size: 16, color: Colors.orangeAccent),
//                             SizedBox(width: 6),
//                             Text(
//                               'Important Next Steps:',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 6),
//                         Text(
//                           '✓ Manager approval required\n'
//                           '✓ Please contact your supervisor ASAP\n'
//                           '✓ Provide any additional documentation if needed',
//                           style: TextStyle(
//                             fontSize: 11,
//                             height: 1.4,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//       } else {
//         // Backend returned failure
//         debugPrint('✗ Emergency clock-out service returned failure');
//         throw Exception(result['error'] ?? 'Unknown emergency clock-out error');
//       }
//     } catch (e) {
//       // STEP 7: ERROR HANDLING
//       debugPrint('==========================================');
//       debugPrint('✗ EMERGENCY CLOCK-OUT ERROR');
//       debugPrint('==========================================');
//       debugPrint('Error Type: ${e.runtimeType}');
//       debugPrint('Error Message: $e');
//       debugPrint('==========================================');
      
//       if (mounted) {
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => AlertDialog(
//             backgroundColor: const Color(0xFF1C2230),
            
//             title: const Row(
//               children: [
//                 Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
//                 SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     'Emergency Clock-Out Failed',
//                     style: TextStyle(
//                       color: Colors.redAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
            
//             content: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Error message
//                   const Text(
//                     'Error Details:',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.red.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                       border: Border.all(color: Colors.red.withOpacity(0.3)),
//                     ),
//                     child: Text(
//                       e.toString(),
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 13,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
                  
//                   // Troubleshooting
//                   const Text(
//                     'What to do next:',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
                  
//                   _buildTroubleshootingStep(
//                     '1',
//                     'Check Internet Connection',
//                     'Make sure you have a stable internet connection and try again.',
//                     Icons.wifi,
//                     Colors.blue,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '2',
//                     'Try Regular Clock-Out',
//                     'If possible, use the regular clock-out button instead.',
//                     Icons.logout,
//                     Colors.green,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '3',
//                     'Contact Your Supervisor',
//                     'Call or message your supervisor immediately to inform them.',
//                     Icons.phone,
//                     Colors.orange,
//                   ),
//                   const SizedBox(height: 10),
                  
//                   _buildTroubleshootingStep(
//                     '4',
//                     'Report to IT Support',
//                     'Contact IT support with the error message shown above.',
//                     Icons.support_agent,
//                     Colors.purple,
//                   ),
//                   const SizedBox(height: 16),
                  
//                   // Emergency contact reminder
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.orange.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                       border: Border.all(color: Colors.orange.withOpacity(0.3)),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Icon(Icons.info_outline, color: Colors.orange, size: 18),
//                         SizedBox(width: 10),
//                         Expanded(
//                           child: Text(
//                             'If this is a true emergency, prioritize your safety first. '
//                             'You can resolve the clock-out issue later with your supervisor.',
//                             style: TextStyle(
//                               color: Colors.orange,
//                               fontSize: 12,
//                               height: 1.4,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(ctx);
//                   _handleEmergencyClockOut();
//                 },
//                 child: const Text(
//                   'Retry',
//                   style: TextStyle(color: Colors.blue),
//                 ),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.redAccent,
//                 ),
//                 onPressed: () => Navigator.pop(ctx),
//                 child: const Text('OK, I Understand'),
//               ),
//             ],
//           ),
//         );
//       }
//     } finally {
//       // STEP 8: CLEANUP
//       if (mounted) {
//         setState(() => isLoading = false);
//         debugPrint('Loading indicator removed');
//       }
//     }
    
//     debugPrint('==========================================');
//     debugPrint('Emergency clock-out method completed');
//     debugPrint('==========================================');
//   }

//   /// Helper method to build troubleshooting steps in error dialog
//   Widget _buildTroubleshootingStep(
//     String number,
//     String title,
//     String description,
//     IconData icon,
//     Color color,
//   ) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           width: 24,
//           height: 24,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//           child: Center(
//             child: Text(
//               number,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Icon(icon, color: color, size: 20),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 13,
//                 ),
//               ),
//               const SizedBox(height: 2),
//               Text(
//                 description,
//                 style: const TextStyle(
//                   color: Colors.white60,
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//   // ============================================================================
//   // ✨ END OF NEW FEATURE: EMERGENCY CLOCK OUT ✨
//   // ============================================================================

//   // ============================================================================
//   // BREAK METHODS
//   // ============================================================================
  
//   /// Handles starting a break
//   Future<void> _handleBreakStart() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.breakStart(attendanceId!, startTime: now);

//       if (result == true) {
//         if (mounted) setState(() => currentBreakStart = now);
//         await _saveShiftProgress();
//         if (mounted) {
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break started!')));
//         }
//       }
//     } catch (e) {
//       debugPrint('Break start error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   /// Handles ending a break
//   Future<void> _handleBreakEnd() async {
//     if (attendanceId == null) return;
//     if (mounted) setState(() => isLoading = true);
//     try {
//       final now = DateTime.now();
//       final result =
//           await _attendanceService.endBreak(attendanceId!, endTime: now);

//       if (result == true) {
//         if (mounted) {
//           setState(() {
//             if (currentBreakStart != null) {
//               breaks.add({'start': currentBreakStart!, 'end': now});
//               currentBreakStart = null;
//             }
//           });
//         }
//         await _saveShiftProgress();
//         if (mounted)
//           ScaffoldMessenger.of(context)
//               .showSnackBar(const SnackBar(content: Text('Break ended!')));
//       }
//     } catch (e) {
//       debugPrint('Break end error: $e');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   // ============================================================================
//   // DEBUG METHODS
//   // ============================================================================
  
//   /// Debug button to clear old shift data
//   Widget _buildDebugButton() {
//     return ElevatedButton(
//       onPressed: _clearOldShiftData,
//       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
//       child: const Text('Clear Old Data'),
//     );
//   }

//   // ============================================================================
//   // UI BUILD METHODS
//   // ============================================================================
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const Sidenav(),
//       appBar: Uppernavbar(showBackButton: true),
//       body: Stack(
//         children: [
//           Background(),
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Gradienthorizontal(
//                     width: MediaQuery.of(context).size.width,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         children: [
//                           _buildShiftInfoCard(),
//                           const SizedBox(height: 24),
//                           if (isActionLoading)
//                             const CircularProgressIndicator()
//                           else if (myStatus == "Pending")
//                             _buildAcknowledgementCard()
//                           else if (myStatus == "Declined")
//                             _buildStatusMessage(
//                                 "You have declined this shift.", Colors.red)
//                           else if (myStatus == "Swap Requested")
//                             _buildStatusMessage(
//                                 "Swap Requested. Waiting for approval.",
//                                 Colors.orange)
//                           else if (myStatus == "Accepted")
//                             _buildTimeTrackingCard(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   /// Builds the shift information card
//   Widget _buildShiftInfoCard() {
//     final date = shiftDetails?['Date'];
//     final formattedDate = date != null
//         ? DateFormat.yMMMMd().format(DateTime.parse(date))
//         : 'Loading...';
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           widget.job.title,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           shiftDetails?['TaskName'] ?? 'Loading...',
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w400,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             Icon(Icons.calendar_month_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Date: $formattedDate',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'Start: ${formatTime(widget.scheduledStartTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Icon(Icons.schedule_outlined,
//                 color: Colors.white.withOpacity(0.9), size: 18),
//             const SizedBox(width: 8),
//             Text(
//               'End: ${formatTime(widget.scheduledEndTime)}',
//               style:
//                   TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
//             ),
//           ],
//         ),
//         if (currentSite != null) ...[
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on,
//                   color: Colors.white.withOpacity(0.9), size: 18),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   currentSite!.siteName,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.9), fontSize: 16),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   /// Builds the acknowledgement card for pending shifts
//   Widget _buildAcknowledgementCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
//       ),
//       child: Column(
//         children: [
//           const Text(
//             "Shift Acknowledgment",
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 10),
//           const Text(
//             "Please accept this shift to start tracking time.",
//             style: TextStyle(color: Colors.white70),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleDecline,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent),
//                   child: const Text("Decline"),
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: _handleAccept,
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Accept"),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           TextButton.icon(
//             onPressed: _handleSwapRequest,
//             icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
//             label: const Text("Request Swap",
//                 style: TextStyle(color: Colors.orangeAccent)),
//           )
//         ],
//       ),
//     );
//   }

//   /// Builds status message for declined/swap requested shifts
//   Widget _buildStatusMessage(String msg, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: color),
//       ),
//       child: Text(
//         msg,
//         style:
//             TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   /// Builds the live tracking button
//   Widget _buildLiveTrackingButton() {
//     return Container(
//       width: double.infinity,
//       margin: const EdgeInsets.only(bottom: 16),
//       child: ElevatedButton.icon(
//         onPressed: () {
//           if (currentSite != null) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EmployeeTrackingScreen(
//                   currentSite: currentSite!,
//                   employeeId: widget.employeeId,
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Site location not available.")),
//             );
//           }
//         },
//         icon: const Icon(Icons.map, color: Colors.white),
//         label: const Text("View Live Location Map",
//             style: TextStyle(color: Colors.white)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: Colors.blueAccent,
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   /// Builds the time tracking card with clock in/out and break controls
//   Widget _buildTimeTrackingCard() {
//     if (attendanceId == null && clockInTime != null) {
//       _buildDebugButton();
//     }

//     final isBreakEnabled = clockInTime != null && clockOutTime == null;

//     bool isEarlyDeparture = false;
//     if (clockOutTime != null) {
//       final scheduledEnd = _getScheduledEndDateTime();
//       isEarlyDeparture = clockOutTime!
//           .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
//     }

//     return Container(
//       child: Column(
//         children: [
//           Container(width: double.infinity),
//           Padding(
//             padding: const EdgeInsets.all(10),
//             child: Column(
//               children: [
//                 // Shift completion banner
//                 if (clockOutTime != null) ...[
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(16),
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: isEarlyDeparture
//                           ? Colors.orange.withOpacity(0.1)
//                           : Colors.green.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(
//                         color: isEarlyDeparture
//                             ? Colors.orange.withOpacity(0.5)
//                             : Colors.green.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Icon(
//                           isEarlyDeparture
//                               ? Icons.warning_amber_rounded
//                               : Icons.check_circle,
//                           color:
//                               isEarlyDeparture ? Colors.orange : Colors.green,
//                           size: 24,
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'Early Departure'
//                                     : 'Shift Completed!',
//                                 style: TextStyle(
//                                   color: isEarlyDeparture
//                                       ? Colors.orange
//                                       : Colors.green,
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 isEarlyDeparture
//                                     ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
//                                     : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                                 style: const TextStyle(
//                                   color: Colors.white70,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
                
//                 // ================================================================
//                 // ✨ NEW UI SECTION: CLOCK IN/OUT WITH EMERGENCY OPTION ✨
//                 // ================================================================
//                 if (clockOutTime == null) ...[
//                   // Regular Clock In/Out button
//                   _buildTimeTrackingItem(
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime,
//                     clockInTime == null ? Icons.login : Icons.logout,
//                     clockInTime == null ? "Clock In" : "Clock Out",
//                     clockInTime == null
//                         ? () => _handleClockIn()
//                         : () => _handleClockOut(),
//                     isEnabled: clockOutTime == null,
//                     photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
//                   ),
                  
//                   // ✨ NEW: EMERGENCY CLOCK OUT BUTTON ✨
//                   // Only shown when employee is clocked in
//                   if (clockInTime != null) ...[
//                     const SizedBox(height: 12),
                    
//                     // Emergency button container
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.redAccent.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: Colors.redAccent.withOpacity(0.3),
//                           width: 1.5,
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Info row explaining when to use
//                           Row(
//                             children: const [
//                               Icon(
//                                 Icons.info_outline,
//                                 color: Colors.orange,
//                                 size: 16,
//                               ),
//                               SizedBox(width: 6),
//                               Expanded(
//                                 child: Text(
//                                   "Use only in emergency situations (medical, safety, family crisis)",
//                                   style: TextStyle(
//                                     color: Colors.orange,
//                                     fontSize: 12,
//                                     fontStyle: FontStyle.italic,
//                                     height: 1.3,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
                          
//                           // Emergency clock out button
//                           SizedBox(
//                             width: double.infinity,
//                             height: 48,
//                             child: ElevatedButton.icon(
//                               onPressed: _handleEmergencyClockOut,
//                               icon: const Icon(
//                                 Icons.warning_amber_rounded,
//                                 size: 20,
//                                 color: Colors.white,
//                               ),
//                               label: const Text(
//                                 "Emergency Clock Out",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.redAccent,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 elevation: 2,
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 16,
//                                   vertical: 12,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                   // ✨ END OF NEW UI SECTION ✨
//                 ] else
//                   _buildTimeTrackingItem(
//                     "Clock Out",
//                     clockOutTime,
//                     Icons.logout,
//                     "Shift Completed",
//                     () {},
//                     isEnabled: false,
//                     photo: clockOutPhoto,
//                   ),
//                 // ================================================================
                
//                 const SizedBox(height: 16),
                
//                 // Break controls
//                 if (clockInTime != null && clockOutTime == null) ...[
//                   if (currentBreakStart == null)
//                     _buildTimeTrackingItem(
//                       "Start Break",
//                       null,
//                       Icons.free_breakfast,
//                       "Start Break",
//                       _handleBreakStart,
//                       isEnabled: isBreakEnabled,
//                     )
//                   else
//                     _buildTimeTrackingItem(
//                       "End Break",
//                       currentBreakStart,
//                       Icons.task_alt,
//                       "End Break",
//                       _handleBreakEnd,
//                       isEnabled: isBreakEnabled,
//                       customButtonColor: Colors.orangeAccent,
//                       customTextColor: Colors.black,
//                     ),
//                   const SizedBox(height: 16),
//                   _buildLiveTrackingButton(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 // Break history
//                 if (breaks.isNotEmpty) ...[
//                   _buildBreakHistory(),
//                   const SizedBox(height: 16),
//                 ],
                
//                 // Shift summary
//                 if (clockOutTime != null) ...[
//                   _buildShiftSummary(),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Builds shift summary widget
//   Widget _buildShiftSummary() {
//     if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

//     final duration = clockOutTime!.difference(clockInTime!);
//     if (duration.isNegative) {
//       return const Text(
//         'Shift times are invalid (Clock-out before Clock-in)',
//         style: TextStyle(color: Colors.redAccent, fontSize: 14),
//       );
//     }

//     final hours = duration.inHours;
//     final minutes = duration.inMinutes.remainder(60);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.access_time, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Shift Summary',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Icon(Icons.login, color: Colors.green, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.logout, color: Colors.red, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.schedule, color: Colors.blue, size: 16),
//               const SizedBox(width: 8),
//               Text(
//                 'Total Time: ${hours}h ${minutes}m',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           if (breaks.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Breaks Taken: ${breaks.length}',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   /// Builds time tracking item widget (clock in/out/break buttons)
//   Widget _buildTimeTrackingItem(
//     String label,
//     DateTime? time,
//     IconData icon,
//     String buttonText,
//     VoidCallback onPressed, {
//     bool? isEnabled,
//     File? photo,
//     Color? customButtonColor,
//     Color? customTextColor,
//   }) {
//     final isRecorded = time != null;
//     final buttonEnabled = isEnabled ?? !isRecorded;

//     final isRedButton = buttonText.toLowerCase().contains("out") ||
//         buttonText.toLowerCase().contains("end");

//     final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
//     final textColor = customTextColor ?? Colors.white;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.w500),
//               ),
//               const Spacer(),
//               Text(
//                 time != null
//                     ? DateFormat('hh:mm:ss a').format(time)
//                     : "Time: 00:00:00",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: ElevatedButton.icon(
//               onPressed: buttonEnabled ? onPressed : null,
//               icon: Icon(
//                 buttonText == "Completed" ? Icons.check_circle : icon,
//                 size: 20,
//                 color: buttonEnabled ? textColor : null,
//               ),
//               label: Text(
//                 buttonText,
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: buttonEnabled ? textColor : null,
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor:
//                     buttonEnabled ? buttonColor : buttonColor.withOpacity(0.4),
//                 foregroundColor: textColor,
//                 disabledForegroundColor: Colors.white.withOpacity(0.6),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Builds break history widget
//   Widget _buildBreakHistory() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: Colors.white.withOpacity(0.3),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.history, color: Colors.white70, size: 18),
//               const SizedBox(width: 8),
//               Text(
//                 'Break History',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           ...breaks.map((breakItem) => Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Row(
//                   children: [
//                     Icon(Icons.circle, color: Colors.white70, size: 8),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               )),
//         ],
//       ),
//     );
//   }
// }