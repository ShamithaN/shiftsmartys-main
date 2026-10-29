class LeaveRequest {
  final int leaveRequestId;
  final int employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  String status;
  final DateTime requestedAt;

  LeaveRequest({
    required this.leaveRequestId,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.requestedAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      leaveRequestId: json['LeaveRequestId'],
      employeeId: json['EmployeeId'],
      leaveType: json['LeaveType'],
      startDate: DateTime.parse(json['StartDate']),
      endDate: DateTime.parse(json['EndDate']),
      reason: json['Reason'],
      status: json['Status'],
      requestedAt: DateTime.parse(json['RequestedAt']),
    );
  }
  bool get isPending {
    return status.toLowerCase() == 'pending';
  }

  bool get isAcceptedOrRejected {
    return status.toLowerCase() == 'approved' ||
        status.toLowerCase() == 'rejected';
  }
}