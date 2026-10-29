class Contact {
  final int employeeId;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String? gender;
  final String? email;
  final String? mobileNumber;
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final DateTime? dateOfBirth;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankBSB;
  final String? bankName;
  final String? employmentStatus;
  final String? jobRole;
  final String? userRole;
  final String? profilePicture;
  final List<NextOfKin> nextOfKins;

  const Contact({
    required this.employeeId,
    required this.firstName,
    this.middleName,
    this.lastName,
    this.gender,
    this.email,
    this.mobileNumber,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.dateOfBirth,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankBSB,
    this.bankName,
    this.employmentStatus,
    this.jobRole,
    this.userRole,
    this.profilePicture,
    required this.nextOfKins,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      employeeId: json['EmployeeId'],
      firstName: json['FirstName'],
      middleName: json['MiddleName'],
      lastName: json['LastName'],
      gender: json['Gender'],
      email: json['Email'],
      mobileNumber: json['MobileNumber'],
      street: json['Street'],
      city: json['City'],
      state: json['State'],
      postalCode: json['PostalCode'],
      country: json['Country'],
      dateOfBirth: json['DateOfBirth'] != null
          ? DateTime.parse(json['DateOfBirth'])
          : null,
      bankAccountName: json['BankAccountName'],
      bankAccountNumber: json['BankAccountNumber'],
      bankBSB: json['BankBSB'],
      bankName: json['BankName'],
      employmentStatus: json['EmploymentStatus'],
      jobRole: json['JobRole'],
      userRole: json['UserRole'],
      profilePicture: json['ProfilePicture'],
      nextOfKins: (json['NextOfKins'] as List<dynamic>)
          .map((kin) => NextOfKin.fromJson(kin))
          .toList(),
    );
  }
}

class NextOfKin {
  final int nextOfKinId;
  final int employeeId;
  final String fullName;
  final String relationship;
  final String mobileNumber;
  final String email;
  final String address;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NextOfKin({
    required this.nextOfKinId,
    required this.employeeId,
    required this.fullName,
    required this.relationship,
    required this.mobileNumber,
    required this.email,
    required this.address,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NextOfKin.fromJson(Map<String, dynamic> json) {
    return NextOfKin(
      nextOfKinId: json['NextOfKinId'],
      employeeId: json['EmployeeId'],
      fullName: json['FullName'],
      relationship: json['Relationship'],
      mobileNumber: json['MobileNumber'],
      email: json['Email'],
      address: json['Address'],
      isPrimary: json['IsPrimary'],
      createdAt: DateTime.parse(json['CreatedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
    );
  }
}
