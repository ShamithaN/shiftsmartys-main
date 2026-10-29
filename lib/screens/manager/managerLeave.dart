import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/models/LeaveRequest.dart';
import 'package:shiftsmart/models/Employee.dart';
import 'package:shiftsmart/services/LeaveService.dart';
import 'package:shiftsmart/services/EmployeeService.dart';

class Managerleave extends StatefulWidget {
  const Managerleave({super.key});

  @override
  State<Managerleave> createState() => _ManagerleaveState();
}

class _ManagerleaveState extends State<Managerleave> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
      
  final LeaveService _leaveService = LeaveService();
  List<Employee> filteredEmployees = [];
  List<LeaveRequest> _leaveRequests = [];
  List<LeaveRequest> _pendingRequests = [];
  List<LeaveRequest> _acceptedRejectedRequests = [];
  bool _isLoading = true;
  List<Employee> _allEmployees = [];
  final EmployeeService _employeeService = EmployeeService();
  final NotificationService _notificationService = NotificationService();


  @override
  void initState() {
    super.initState();
    enableFullScreen();
    filteredEmployees = List.from(_allEmployees);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show(); // optional spinner
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _fetchLeaveRequests();
    await _fetchAllEmployees();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchLeaveRequests() async {
    try {
      final leaveRequests = await _leaveService.fetchLeaveRequests();
      if (!mounted) return;
      setState(() {
        _leaveRequests = leaveRequests;
        _pendingRequests =
            _leaveRequests.where((req) => req.isPending).toList();
        _acceptedRejectedRequests = _leaveRequests
            .where((req) => req.isAcceptedOrRejected)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error fetching leave requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<int?> _fetchLeaveBalance(int employeeId) async {
    try {
      return await _leaveService.fetchLeaveBalance(employeeId);
    } catch (e) {
      debugPrint("Leave balance fetch error: $e");
      return null;
    }
  }
Future<void> _updateLeaveStatus(String id, String newStatus) async {
  try {
    await _leaveService.updateLeaveStatus(id, newStatus);

    if (!mounted) return;

    // Find the updated request
    final updatedRequest = _leaveRequests.firstWhere(
      (req) => req.leaveRequestId.toString() == id,
    );

    // 🔔 Send notification using employeeId from the request model
    await _notificationService.leaveNotification(updatedRequest.employeeId, newStatus);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Leave $newStatus")),
    );

    // Update state
    setState(() {
      updatedRequest.status = newStatus;

      if (newStatus.toLowerCase() == 'approved' ||
          newStatus.toLowerCase() == 'rejected') {
        _acceptedRejectedRequests.add(updatedRequest);
      } else {
        _pendingRequests.add(updatedRequest);
      }
    });
  } catch (e) {
    if (!mounted) return;

    debugPrint('Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
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

  List<LeaveRequest> getTodayLeaveRequests() {
    final today = DateTime.now();
    return _leaveRequests.where((req) {
      final isToday =
          !today.isBefore(req.startDate) && !today.isAfter(req.endDate);
      final isApproved = req.status.toLowerCase() == 'approved';

      return isToday && isApproved;
    }).toList();
  }

  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = List.from(_allEmployees);
      } else {
        filteredEmployees = _allEmployees
            .where((emp) =>
                emp.firstName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Search(onQueryChanged: onQueryChanged),
                              const SizedBox(height: 20),
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
                                  children: getTodayLeaveRequests().isNotEmpty
                                      ? getTodayLeaveRequests().map((leave) {
                                          final employee =
                                              getEmployeeById(leave.employeeId);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: Column(
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor:
                                                      Colors.grey[800],
                                                  backgroundImage: (employee
                                                                  ?.profilePicture !=
                                                              null &&
                                                          employee!
                                                              .profilePicture!
                                                              .startsWith(
                                                                  'data:image'))
                                                      ? MemoryImage(
                                                          base64Decode(employee
                                                              .profilePicture!
                                                              .split(',')
                                                              .last),
                                                        )
                                                      : (employee?.profilePicture !=
                                                                  null &&
                                                              employee!
                                                                  .profilePicture!
                                                                  .isNotEmpty)
                                                          ? NetworkImage(employee
                                                              .profilePicture!)
                                                          : null,
                                                  child:
                                                      (employee?.profilePicture ==
                                                                  null ||
                                                              employee!
                                                                  .profilePicture!
                                                                  .isEmpty)
                                                          ? const Icon(
                                                              Icons.person,
                                                              size: 30,
                                                              color:
                                                                  Colors.white)
                                                          : null,
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  width: 70,
                                                  child: Text(
                                                    employee?.firstName ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList()
                                      : [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Text(
                                              "No one is on leave today.",
                                              style: TextStyle(
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Awaiting Approval",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              _leaveList(isPending: true),
                              const SizedBox(height: 20),
                              const Text(
                                "Approved/Denied Requests",
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              _leaveList(isPending: false),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
        ],
      ),
    );
  }

  Widget _leaveList({required bool isPending}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final requests = isPending ? _pendingRequests : _acceptedRejectedRequests;
    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            isPending
                ? "No pending requests."
                : "No approved or rejected requests.",
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Column(
      children: requests.map((request) {
        final employee = getEmployeeById(request.employeeId);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF363E51),
                Color(0xFF191E26),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Replace Icon with CircleAvatar for profile picture
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[800],
                backgroundImage: (employee?.profilePicture != null &&
                        employee!.profilePicture!.startsWith('data:image'))
                    ? MemoryImage(
                        base64Decode(employee.profilePicture!.split(',').last),
                      )
                    : (employee?.profilePicture != null &&
                            employee!.profilePicture!.isNotEmpty)
                        ? NetworkImage(employee.profilePicture!)
                        : null,
                child: (employee?.profilePicture == null ||
                        employee!.profilePicture!.isEmpty)
                    ? const Icon(Icons.person, size: 30, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee?.firstName ?? 'Unknown',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      request.startDate.toLocal().toString().split(' ')[0],
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    Text(
                      "${request.endDate.difference(request.startDate).inDays + 1} Days",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      request.status,
                      style: TextStyle(
                        color: request.status.toLowerCase() == "approved"
                            ? Colors.green
                            : request.status.toLowerCase() == "rejected"
                                ? Colors.red
                                : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GradientButton(
                text: "View Details",
                onPressed: () => _showDetailsDialog(request),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showDetailsDialog(LeaveRequest request) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final employee = getEmployeeById(request.employeeId);

    int? remainingDays;
    try {
      remainingDays = await _fetchLeaveBalance(request.employeeId);
    } catch (e) {
      print("Error fetching leave balance: $e");
    }

    final requestDays =
        request.endDate.difference(request.startDate).inDays + 1;
    final hasEnoughLeave =
        remainingDays != null && remainingDays >= requestDays;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF363E51), Color(0xFF191E26)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leave Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailRow(
                        "Employee Name", employee?.firstName ?? 'Unknown'),
                    _detailRow("Leave Type", request.leaveType),
                    _detailRow(
                        "Start Date", dateFormat.format(request.startDate)),
                    _detailRow("End Date", dateFormat.format(request.endDate)),
                    _detailRow("Requested Days", "$requestDays"),
                    _detailRow("Reason", request.reason),
                    _detailRow(
                      "Status",
                      request.status,
                      valueColor: request.status.toLowerCase() == "approved"
                          ? Colors.green
                          : request.status.toLowerCase() == "rejected"
                              ? Colors.red
                              : Colors.white,
                    ),
                    _detailRow(
                        "Requested At", dateFormat.format(request.requestedAt)),
                    const SizedBox(height: 10),
                    Text(
                      "Remaining Leave Days: ${remainingDays ?? 'N/A'}",
                      style: TextStyle(
                        color: hasEnoughLeave ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updateLeaveStatus(
                                    request.leaveRequestId.toString(),
                                    "Rejected")
                                .then((_) {
                              _fetchLeaveRequests();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 226, 66, 63),
                                  Color.fromARGB(255, 133, 5, 5)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF1A1F2C).withOpacity(0.6),
                                  spreadRadius: 0,
                                  blurRadius: 8,
                                  offset: const Offset(3, 3),
                                ),
                              ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              width: 120,
                              height: 44,
                              child: const Text(
                                "Reject",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Approve with default GradientButton
                        GradientButton(
                          text: "Approve",
                          onPressed: () {
                            Navigator.of(context).pop();
                            _updateLeaveStatus(
                                    request.leaveRequestId.toString(),
                                    "Approved")
                                .then((_) {
                              _fetchLeaveRequests();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

}
