class JobRoleType {
  final int id;
  final String name;
  final List<String> requiredDocuments;

  JobRoleType({
    required this.id,
    required this.name,
    required this.requiredDocuments,
  });

  static JobRoleType unKnown() => JobRoleType(
    id: 0, 
    name: 'UnKnown', 
    requiredDocuments: [],
  );

  factory JobRoleType.fromJson(Map<String, dynamic> json) {
    return JobRoleType(
      id: json['JobRoleTypeId'],
      name: json['JobRoleName'],
      requiredDocuments: (json['RequiredDocuments'] as String)
        .split(',')
        .map((e) => e.trim())
        .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'JobRoleTypeId': id,
      'JobRoleName': name,
      'RequiredDocuments': requiredDocuments.join(','),
    };
  }
}
