import 'package:shiftsmart/models/Site.dart';

class Project {
  final int projectId;
  final String name;
  final int estimatedTime;
  final String location;
  final String description;
  final String additionalRemark;
  final String projectDue;
  final String startDate;
  final String endDate;
  final String companyName;
  late String status;
  final List<Site> sites;

  Project({
    required this.projectId,
    required this.name,
    required this.estimatedTime,
    required this.location,
    required this.description,
    required this.additionalRemark,
    required this.projectDue,
    required this.startDate,
    required this.endDate,
    required this.companyName,
    required this.status,
    required this.sites, 
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: json['ProjectId'] ?? 0, 
      name: json['Name'] ?? 'Unnamed Project',
      estimatedTime: json['EstimatedTime'] ?? 0,
      location: json['Location'] ?? 'Unknown Location',
      description: json['Description'] ?? 'No Description',
      additionalRemark: json['AdditionalRemarks'] ?? 'No Remarks',
      projectDue: json['ProjectDue'] ?? 'No Due Date',
      startDate: json['StartDate'] ?? 'No Start Date',
      endDate: json['EndDate'] ?? 'No End Date',
      companyName: json['CompanyName'] ?? 'No Company Name',
      status: json['Status'] ?? 'No Status',
      sites: (json['Sites'] as List<dynamic>?)
              ?.map((e) => Site.fromJson(e))
              .toList() ??
          [],
    );
  }
}
