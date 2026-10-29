import 'package:shiftsmart/models/JobRole.dart';

class Job {
  final int jobId;
  final String title;
  final String description;
  final String startDate;
  final String jobDueDate;
  final String status;
  final int projectId;
  final int siteId;
  final int? shiftId;
  final int? employeeId;
  final String? startTime;
  final String? endTime;
  final int totalEstimatedTime;
  final String jobImageUrl;
  final List<JobRole> jobRoles;

  Job({
    required this.jobId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.jobDueDate,
    required this.status,
    required this.projectId,
    required this.siteId,
    this.shiftId,
    this.employeeId,
    this.startTime,
    this.endTime,
    required this.totalEstimatedTime,
    required this.jobImageUrl,
    required this.jobRoles,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    try {
      return Job(
        jobId: json['JobId'] ?? 0,
        title: json['Title'] ?? 'Unknown Title',
        description: json['Description'] ?? '',
        startDate: json['StartDate'] ?? '',
        jobDueDate: json['JobDueDate'] ?? '',
        status: json['Status'] ?? 'Unknown',
        projectId: json['ProjectId'] ?? 0,
        siteId: json['SiteId'] ?? 0,
        shiftId: json['shiftId'] as int?,
        employeeId: json['employeeId'] as int?,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        totalEstimatedTime: json['TotalEstimatedTime'] ?? 0,
        jobImageUrl: json['JobImageUrl'] ?? '',
        jobRoles: (json['JobRoles'] as List<dynamic>?)
                ?.map((role) => JobRole.fromJson(role))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing Job from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'JobId': jobId,
      'Title': title,
      'Description': description,
      'StartDate': startDate,
      'JobDueDate': jobDueDate,
      'Status': status,
      'ProjectId': projectId,
      'SiteId': siteId,
      'shiftId': shiftId,
      'employeeId': employeeId,
      'startTime': startTime,
      'endTime': endTime,
      'TotalEstimatedTime': totalEstimatedTime,
      'JobImageUrl': jobImageUrl,
      'JobRoles': jobRoles.map((role) => role.toJson()).toList(),
    };
  }
}
