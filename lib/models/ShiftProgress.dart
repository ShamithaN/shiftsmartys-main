// In models/ShiftProgress.dart
class ShiftProgress {
  final int employeeId;
  final int shiftId;
  final DateTime scheduledStartTime;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  DateTime? breakStart;
  DateTime? breakEnd;
  double? clockInLat; 
  double? clockInLng;
  final int? attendanceId;

  ShiftProgress({
    required this.employeeId,
    required this.shiftId,
    required this.scheduledStartTime,
    this.clockInTime,
    this.clockOutTime,
    this.breakStart,
    this.breakEnd,
    this.clockInLat,  
    this.clockInLng,  
    this.attendanceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'shiftId': shiftId,
      'scheduledStartTime': scheduledStartTime.toIso8601String(),
      'clockInTime': clockInTime?.toIso8601String(),
      'clockOutTime': clockOutTime?.toIso8601String(),
      'breakStart': breakStart?.toIso8601String(),
      'breakEnd': breakEnd?.toIso8601String(),
      'clockInLat': clockInLat,  
      'clockInLng': clockInLng, 
      'attendanceId': attendanceId,
    };
  }

  factory ShiftProgress.fromJson(Map<String, dynamic> json) {
    return ShiftProgress(
      employeeId: json['employeeId'],
      shiftId: json['shiftId'],
      scheduledStartTime: DateTime.parse(json['scheduledStartTime']),
      clockInTime: json['clockInTime'] != null ? DateTime.parse(json['clockInTime']) : null,
      clockOutTime: json['clockOutTime'] != null ? DateTime.parse(json['clockOutTime']) : null,
      breakStart: json['breakStart'] != null ? DateTime.parse(json['breakStart']) : null,
      breakEnd: json['breakEnd'] != null ? DateTime.parse(json['breakEnd']) : null,
      clockInLat: json['clockInLat']?.toDouble(), 
      clockInLng: json['clockInLng']?.toDouble(), 
      attendanceId: json['attendanceId'],
    );
  }

  // Add copyWith method for easier updates
  ShiftProgress copyWith({
    int? employeeId,
    int? shiftId,
    DateTime? scheduledStartTime,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    DateTime? breakStart,
    DateTime? breakEnd,
    double? clockInLat,
    double? clockInLng,
    int? attendanceId,
  }) {
    return ShiftProgress(
      employeeId: employeeId ?? this.employeeId,
      shiftId: shiftId ?? this.shiftId,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      breakStart: breakStart ?? this.breakStart,
      breakEnd: breakEnd ?? this.breakEnd,
      clockInLat: clockInLat ?? this.clockInLat,
      clockInLng: clockInLng ?? this.clockInLng,
      attendanceId: attendanceId ?? this.attendanceId,
    );
  }
}