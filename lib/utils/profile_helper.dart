import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/auth_service.dart';


Future<void> refreshUserProfileFromBackend(
  BuildContext context, {
  AuthService? authService,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('userEmail');

  if (email != null) {
    final service = authService ?? AuthService(); // Use provided or default
    final fullProfile = await service.fetchFullEmployeeProfile(email);

    if (fullProfile != null) {
      final userProfile = {
        "userId": fullProfile["UserId"],
        "employeeId": fullProfile["EmployeeId"],
        "firstName": fullProfile["FirstName"] ?? "",
        "middleName": fullProfile["MiddleName"] ?? "",
        "lastName": fullProfile["LastName"] ?? "",
        "gender": fullProfile["Gender"] ?? "",
        "email": fullProfile["Email"] ?? "",
        "mobileNumber": fullProfile["MobileNumber"] ?? "",
        "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
        "street": fullProfile["Street"] ?? "",
        "city": fullProfile["City"] ?? "",
        "state": fullProfile["State"] ?? "",
        "postalCode": fullProfile["PostalCode"] ?? "",
        "country": fullProfile["Country"] ?? "",
        "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
        "jobRole": fullProfile["JobRole"] ?? "",
        "userRole": fullProfile["UserRole"] ?? "",
        "profilePicture": fullProfile["ProfilePicture"] ?? "",
        "bankAccountName": fullProfile["BankAccountName"] ?? "",
        "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
        "bankBSB": fullProfile["BankBSB"] ?? "",
        "bankName": fullProfile["BankName"] ?? "",
        "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []).map((nok) {
          return {
            "nextOfKinId": nok["NextOfKinId"],
            "employeeId": nok["EmployeeId"],
            "fullName": nok["FullName"],
            "relationship": nok["Relationship"],
            "mobileNumber": nok["MobileNumber"],
            "email": nok["Email"],
            "address": nok["Address"],
          };
        }).toList(),
      };

      Provider.of<UserProvider>(context, listen: false).setUserProfile(userProfile);
    }
  }
}
