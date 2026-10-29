class Company {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String ContactPerson;

  Company({required this.id, required this.name,required this.address,required this.phoneNumber,required this.ContactPerson});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['CompanyId']?? 0,
      name: json['Name'],
      address:json['Address']??'',
      phoneNumber: json['ContactNumber']?.toString() ?? '',
      ContactPerson:  json['ContactPerson'] ?? '',

    );
  }
}