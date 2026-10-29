import 'package:flutter/material.dart';
import 'package:shiftsmart/models/Employee.dart';
import 'package:shiftsmart/screens/manager/managerViewEmployee.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/search.dart';

class Manageremployee extends StatefulWidget {
  const Manageremployee({super.key});

  @override
  State<Manageremployee> createState() => _ManageremployeeState();
}

class _ManageremployeeState extends State<Manageremployee> {
  List<Employee> allEmployees = [];
  List<Employee> filteredEmployees = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchEmployee();
  }

  void onQueryChanged(String query) {
    setState(() {
      filteredEmployees = query.isEmpty
          ? List.from(allEmployees)
          : allEmployees
              .where((emp) =>
                  emp.firstName.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> fetchEmployee() async {
    try {
      final employees = await EmployeeService().fetchAllEmployees();
      debugPrint("Employees only: $employees");
      setState(() {
        allEmployees = employees;
        filteredEmployees = List.from(employees);
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching employee: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: Background()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Search(onQueryChanged: onQueryChanged),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Employee List",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _employeeList()),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _employeeList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: filteredEmployees.length,
      itemBuilder: (context, index) {
        final employee = filteredEmployees[index];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF363E51), Color(0xFF191E26)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Color(0xFF3498DB), size: 24),
              const SizedBox(width: 12),

              // Name and Status Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.firstName} ${employee.lastName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.employmentStatus ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Chevron Button
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Color.fromARGB(255, 19, 129, 180),
                  size: 24,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          Managerviewemployee(employee: employee),
                    ),
                  );
                },
              ),

              // Unread Badge (only show if count > 0)
            ],
          ),
        );
      },
    );
  }
}

class NextOfKin {
  final String fullName;
  final String relationship;
  final String mobileNumber;

  NextOfKin({
    required this.fullName,
    required this.relationship,
    required this.mobileNumber,
  });

  factory NextOfKin.fromJson(Map<String, dynamic> json) {
    return NextOfKin(
      fullName: json['fullName'] ?? 'Unknown',
      relationship: json['relationship'] ?? 'Unknown',
      mobileNumber: json['mobileNumber'] ?? 'xxx-xxx-xxxx',
    );
  }
}
