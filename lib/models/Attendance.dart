class Attendance {
  final int attendanceId;
  final int employeeId;
  final int shiftId;
  final String employeeName;
  final String shiftName;
  final String scheduledStartTime;
  final String clockInTime;
  final String clockOutTime;
  final String clockInPhotoUrl;
  final String clockOutPhotoUrl;
  final String breakStart;
  final String breakEnd;
  final bool isEmergency;
  final String emergencyReason;

  Attendance({
    required this.attendanceId,
    required this.employeeId,
    required this.shiftId,
    required this.employeeName,
    required this.shiftName,
    required this.scheduledStartTime,
    required this.clockInTime,
    required this.clockOutTime,
    required this.clockInPhotoUrl,
    required this.clockOutPhotoUrl,
    required this.breakStart,
    required this.breakEnd,
    this.isEmergency = false,
    this.emergencyReason = '',
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
  return Attendance(
    attendanceId: json['AttendanceId'] ?? 0,
    employeeId: json['EmployeeId'] ?? 0,
    shiftId: json['ShiftId'] ?? 0,
    employeeName: json['EmployeeName'] ?? 'Unknown',
    shiftName: json['ShiftName'] ?? 'Unknown',
    scheduledStartTime: json['ScheduledStartTime'] ?? '',
    clockInTime: json['ClockInTime'] ?? '',
    clockOutTime: json['ClockOutTime'] ?? '',
    clockInPhotoUrl: json['ClockInPhotoUrl'] ?? '',
    clockOutPhotoUrl: json['ClockOutPhotoUrl'] ?? '',
    breakStart: json['BreakStart'] ?? '',
    breakEnd: json['BreakEnd'] ?? '',
    isEmergency: json['IsEmergency'] ?? false,
    emergencyReason: json['EmergencyReason'] ?? '',
  );
}
}