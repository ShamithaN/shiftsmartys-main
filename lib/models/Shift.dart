class EmployeeResponse {
  final int employeeId;
  final String status;
  final String? reason;
  final DateTime? respondedAt;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final bool isEarlyExit;
  final String? earlyExitReason;
  final String? approvalStatus;

  EmployeeResponse({
    required this.employeeId,
    required this.status,
    this.reason,
    this.respondedAt,
    this.clockInTime,
    this.clockOutTime,
    required this.isEarlyExit,
    this.earlyExitReason,
    this.approvalStatus,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeResponse(
      employeeId: (json['EmployeeId'] as num?)?.toInt() ?? 0,
      status: json['Status'] ?? 'Pending',
      reason: json['Reason'],
      respondedAt: DateTime.tryParse(json['RespondedAt'] ?? ''),
      clockInTime: DateTime.tryParse(json['ClockInTime'] ?? ''),
      clockOutTime: DateTime.tryParse(json['ClockOutTime'] ?? ''),
      isEarlyExit: json['IsEarlyExit'] ?? false,
      earlyExitReason: json['EarlyExitReason'],
      approvalStatus: json['ApprovalStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EmployeeId': employeeId,
      'Status': status,
      'Reason': reason,
      'RespondedAt': respondedAt?.toIso8601String(),
      'ClockInTime': clockInTime?.toIso8601String(),
      'ClockOutTime': clockOutTime?.toIso8601String(),
      'IsEarlyExit': isEarlyExit,
      'EarlyExitReason': earlyExitReason,
      'ApprovalStatus': approvalStatus,
    };
  }
}

class Shift {
  final int shiftId;
  final int projectId;
  final String taskName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String location;
  final String status;
  final List<int> assignedEmployeeIds;
  final List<EmployeeResponse> employeeResponses;
  final int? jobId;
  final int? siteId;
  final String? latitude;
  final String? longitude;

  Shift({
    required this.shiftId,
    required this.projectId,
    required this.taskName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.status,
    required this.assignedEmployeeIds,
    this.employeeResponses = const [],
    this.jobId,
    this.siteId,
    this.latitude,
    this.longitude,
  });

  Shift copyWith({
    int? shiftId,
    int? projectId,
    String? taskName,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? location,
    String? status,
    List<int>? assignedEmployeeIds,
    List<EmployeeResponse>? employeeResponses,
    int? siteId,
    String? latitude,
    String? longitude,
    int? jobId,
  }) {
    return Shift(
      shiftId: shiftId ?? this.shiftId,
      projectId: projectId ?? this.projectId,
      taskName: taskName ?? this.taskName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      status: status ?? this.status,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      employeeResponses: employeeResponses ?? this.employeeResponses,
      siteId: siteId ?? this.siteId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      jobId: jobId ?? this.jobId,
    );
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    try {
      return Shift(
        shiftId: (json['ShiftId'] as num?)?.toInt() ?? 0,
        projectId: (json['ProjectId'] as num?)?.toInt() ?? 0,
        taskName: json['TaskName']?.toString() ?? '',
        date: DateTime.tryParse(json['Date'] ?? '') ?? DateTime.now(),
        startTime: json['StartTime']?.toString() ?? '',
        endTime: json['EndTime']?.toString() ?? '',
        location: json['Location']?.toString() ?? '',
        status: json['Status']?.toString() ?? '',
        jobId: (json['JobId'] as num?)?.toInt(),
        assignedEmployeeIds:
            (json['AssignedEmployeeIds'] as List<dynamic>? ?? [])
                .map((e) => (e as num?)?.toInt() ?? 0)
                .toList(),
        employeeResponses: (json['EmployeeResponses'] as List<dynamic>? ?? [])
            .map((e) => EmployeeResponse.fromJson(e))
            .toList(),
        siteId: (json['SiteId'] as num?)?.toInt(),
        latitude: json['Latitude']?.toString(),
        longitude: json['Longitude']?.toString(),
      );
    } catch (e, stack) {
      print("🔥 ERROR in Shift.fromJson(): $e\n$stack");
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ShiftId': shiftId,
      'ProjectId': projectId,
      'TaskName': taskName,
      'Date': date.toIso8601String(),
      'StartTime': startTime,
      'EndTime': endTime,
      'Location': location,
      'Status': status,
      'AssignedEmployeeIds': assignedEmployeeIds,
      'EmployeeResponses': employeeResponses.map((e) => e.toJson()).toList(),
      'JobId': jobId,
      'SiteId': siteId,
      'Latitude': latitude,
      'Longitude': longitude,
    };
  }
}
