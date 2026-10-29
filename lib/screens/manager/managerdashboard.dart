import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/Employee.dart';
import 'package:shiftsmart/models/LeaveRequest.dart';
import 'package:shiftsmart/models/Shift.dart';
import 'package:shiftsmart/screens/manager/managerShiftsView.dart';
import 'package:shiftsmart/services/LeaveService.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/services/ShiftService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/circleindicator.dart';
import 'package:shiftsmart/widgets/gradientbox.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/models/Project.dart';

class Managerdashboard extends StatefulWidget {
  const Managerdashboard({super.key});

  @override
  State<Managerdashboard> createState() => _ManagerdashboardState();
}

class _ManagerdashboardState extends State<Managerdashboard> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  int completed = 0;
  int total = 0;
  int inProgress = 0;
  List<Project> allProjects = [];
  List<String> filteredEmployees = [];
  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = true;
  List<Employee> _allEmployees = [];
  List<Shift> _todayShifts = [];

  final ProjectService _projectService = ProjectService();
  final LeaveService _leaveService = LeaveService();
  final EmployeeService _employeeService = EmployeeService();
  final ShiftService _shiftService = ShiftService();

  @override
  void initState() {
    super.initState();
    enableFullScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show();
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await fetchProjects();
    await _fetchLeaveRequests();
    await _fetchAllEmployees();
    await _fetchAllShifts();
    // if you want to show current shift too
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAllEmployees() async {
    try {
      final employees = await _employeeService.fetchAllEmployees();
      setState(() {
        _allEmployees = employees;
      });
    } catch (e) {
      print("Error fetching employees: $e");
    }
  }

  Future<void> _fetchLeaveRequests() async {
    try {
      final requests = await _leaveService.fetchLeaveRequests();
      setState(() {
        _leaveRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchProjects() async {
    final projects = await _projectService.fetchAllProjects();
    if (!mounted) return;
    setState(() {
      allProjects = projects;
      total = allProjects.length;
      completed = getCompletedProjectsCount();
      inProgress = getInProgressProjectsCount();
    });
  }

  Future<void> _fetchAllShifts() async {
    try {
      final allRawShifts = await _shiftService.fetchAllRawShifts();
      final today = DateTime.now();
      final todayOnly = allRawShifts
          .map((shiftData) => Shift.fromJson(shiftData))
          .where((shift) =>
              shift.date.year == today.year &&
              shift.date.month == today.month &&
              shift.date.day == today.day)
          .toList();
      debugPrint("Today only: $todayOnly");
      setState(() {
        _todayShifts = todayOnly;
        debugPrint("Today shifts: $_todayShifts");
      });
    } catch (e) {
      debugPrint("Error fetching today's shifts: $e");
    }
  }

  int getCompletedProjectsCount() {
    return allProjects.where((project) => project.status == 'Completed').length;
  }

  int getInProgressProjectsCount() {
    return allProjects.where((project) => project.status == 'Active').length;
  }

  Employee? getEmployeeById(int id) {
    return _allEmployees.firstWhere(
      (emp) => emp.employeeId == id,
      orElse: () => Employee(
          employeeId: id,
          firstName: 'Unknown',
          profilePicture: '',
          nextOfKins: []),
    );
  }

  String formatTime(String timeString) {
    try {
      final parsedTime = DateFormat("HH:mm:ss").parse(timeString);
      return DateFormat("HH:mm").format(parsedTime);
    } catch (e) {
      return timeString; // fallback if parsing fails
    }
  }

  List<LeaveRequest> getTodayLeaveRequests() {
    final today = DateTime.now();
    return _leaveRequests.where((req) {
      final isToday =
          !today.isBefore(req.startDate) && !today.isAfter(req.endDate);
      final isApproved = req.status.toLowerCase() == 'approved';
      return isApproved && isToday;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        body: Stack(children: [
      const Background(),
      _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF724584)),
            )
          : Column(
              children: [
                Expanded(
                    child: RefreshIndicator(
                        key: _refreshKey,
                        onRefresh: _refreshData,
                        child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenHeight * 0.02,
                                ),
                                child: Column(children: [
                                  Gradientbox(
                                    width: double.infinity,
                                    height: screenHeight * 0.35,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.03,
                                        vertical: screenHeight * 0.015,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "PROJECT OVERVIEW",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                children: [
                                                  const SizedBox(width: 50),
                                                  Column(
                                                    children: [
                                                      const Text(
                                                        "In Progress",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Circleindicator(
                                                        value: total > 0
                                                            ? inProgress / total
                                                            : 0,
                                                        total: total,
                                                        count: inProgress,
                                                        label: "In Progress",
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 30),
                                                  Column(
                                                    children: [
                                                      const Text(
                                                        "Completed",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Circleindicator(
                                                        value: total > 0
                                                            ? completed / total
                                                            : 0,
                                                        total: total,
                                                        count: completed,
                                                        label: "Completed",
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.025),
                                  Gradienthorizontal(
                                    width: double.infinity,
                                    height: screenHeight * 0.20,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.04,
                                        vertical: screenHeight * 0.015,
                                      ),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Today on Leave",
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children:
                                                    getTodayLeaveRequests()
                                                        .isNotEmpty
                                                        ? getTodayLeaveRequests()
                                                            .map((leave) {
                                                            final employee =
                                                              getEmployeeById(leave.employeeId);
                                                            return Padding(
                                                              padding: const EdgeInsets.only(right: 12),
                                                              child: Column(
                                                                children: [
                                                                  CircleAvatar(
                                                                    radius: 30,
                                                                    backgroundColor: Colors.grey[800],
                                                                    backgroundImage: (employee?.profilePicture != null &&
                                                                            employee!.profilePicture!.startsWith('data:image'))
                                                                        ? MemoryImage(base64Decode(employee.profilePicture!.split(',').last),)
                                                                        : (employee?.profilePicture != null &&
                                                                                employee!.profilePicture!.isNotEmpty)
                                                                            ? NetworkImage(employee.profilePicture!)
                                                                            : null,
                                                                    child: (employee?.profilePicture == null ||
                                                                            employee!.profilePicture!.isEmpty)
                                                                        ? const Icon(
                                                                            Icons.person,
                                                                            size: 30,
                                                                            color:Colors.white)
                                                                        : null,
                                                                  ),
                                                                  const SizedBox(height: 6),
                                                                  SizedBox(
                                                                    width: 70,
                                                                    child: Text(
                                                                      employee?.firstName ?? 'Unknown',
                                                                      style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontSize: 12),
                                                                      overflow: TextOverflow.ellipsis,
                                                                      textAlign: TextAlign.center,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList()
                                                        : [ const Padding(
                                                              padding: EdgeInsets.symmetric(vertical: 12),
                                                              child: Text(
                                                                "No one is on leave today.",
                                                                style: TextStyle(color: Colors.white70),
                                                              ),
                                                            ),
                                                          ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.025),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: screenHeight * 0.18,
                                      maxHeight: screenHeight * 0.45,
                                    ),
                                    child: Gradienthorizontal(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: Padding(
                                        padding: EdgeInsets.all(screenWidth * 0.04),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "TODAY'S SHIFTS",
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              "${_todayShifts.length} shift(s) scheduled for today",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              height: screenHeight * 0.25,
                                              child: _todayShifts.isEmpty
                                                  ? const Center(
                                                      child: Text(
                                                        "No shifts scheduled today.",
                                                        style: TextStyle(color:Colors.white70),
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      physics: const BouncingScrollPhysics(),
                                                      itemCount: _todayShifts.length,
                                                      itemBuilder: (context, index) {
                                                        final shift =
                                                          _todayShifts[index];
                                                        return Padding(
                                                            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.008),
                                                            child: InkWell(
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context, 
                                                                  MaterialPageRoute(
                                                                    builder: (context) =>
                                                                      ManagerShiftsView(shift: shift),
                                                                  ),
                                                                );
                                                              },
                                                              child: Container(
                                                                padding: EdgeInsets.all(screenWidth *0.03),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white.withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    /// Row: Task name and status
                                                                    Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Expanded(
                                                                          child: Text(
                                                                            shift.taskName,
                                                                            style: const TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.white,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          shift.status,
                                                                          style: TextStyle(
                                                                            fontSize: 13,
                                                                            fontWeight: FontWeight.w500,
                                                                            color: shift.status.trim().toLowerCase() == 'scheduled'
                                                                                ? Colors.yellowAccent
                                                                                : Colors.white70,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(height: 10,
                                                                        ),
                                                                        const Icon(
                                                                          Icons.arrow_forward_ios,
                                                                          color: Colors.white70,
                                                                          size: 14,
                                                                        )
                                                                      ],
                                                                    ),
                                                                    const SizedBox(height: 6),
                                                                    /// Time
                                                                    Text("${formatTime(shift.startTime)} - ${formatTime(shift.endTime)}",
                                                                      style: const TextStyle(
                                                                        fontSize: 13,
                                                                        color: Colors.white70,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 12),
                                                                    Text(
                                                                      "Assigned employees: ",
                                                                      style: const TextStyle(
                                                                        fontSize: 15,
                                                                        color: Colors.white,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 12),
                                                                    /// Assigned employees (up to 2)
                                                                    Row(
                                                                      children: shift.assignedEmployeeIds.take(2).map((empId) {
                                                                        final employee = getEmployeeById(empId);
                                                                        return Padding(
                                                                          padding: const EdgeInsets.only(right: 12),
                                                                          child: Column(
                                                                            children: [
                                                                              CircleAvatar(
                                                                                radius: 20,
                                                                                backgroundColor: Colors.grey[800],
                                                                                backgroundImage: (employee?.profilePicture != null && employee!.profilePicture!.startsWith('data:image'))
                                                                                    ? MemoryImage(base64Decode(employee.profilePicture!.split(',').last))
                                                                                    : (employee?.profilePicture != null && employee!.profilePicture!.isNotEmpty)
                                                                                        ? NetworkImage(employee.profilePicture!)
                                                                                        : null,
                                                                                child: (employee?.profilePicture == null || employee!.profilePicture!.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
                                                                              ),
                                                                              const SizedBox(height: 6),
                                                                              SizedBox(
                                                                                width: 60,
                                                                                child: Text(
                                                                                  employee?.firstName ?? 'Unknown',
                                                                                  style: const TextStyle(
                                                                                    color: Colors.white,
                                                                                    fontSize: 12,
                                                                                  ),
                                                                                  textAlign: TextAlign.center,
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ));
                                                      },
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ])))))
              ],
            ),
    ]));
  }
}
