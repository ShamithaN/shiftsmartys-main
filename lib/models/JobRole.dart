// Job Role models
class JobRole {
  int jobRoleTypeId;
  int estimatedTime;
  int numberOfRoles;
  String notes;
  String roleName;

  JobRole({
    required this.jobRoleTypeId,
    required this.estimatedTime,
    required this.numberOfRoles,
    required this.notes,
    required this.roleName,
  });

  // Factory constructor to create JobRole from JSON
  factory JobRole.fromJson(Map<String, dynamic> json) {
    return JobRole(
      jobRoleTypeId: json['jobRoleTypeId'] ?? 0,
      estimatedTime: json['estimatedTime'] ?? 8,
      numberOfRoles: json['numberOfRoles'] ?? 1,
      notes: json['notes'] ?? '',
      roleName: json['roleName'] ?? '',
    );
  }

  // Convert JobRole to JSON
  Map<String, dynamic> toJson() {
    return {
      'jobRoleTypeId': jobRoleTypeId,
      'estimatedTime': estimatedTime,
      'numberOfRoles': numberOfRoles,
      'notes': notes,
      'roleName': roleName, 
    };
  }
}