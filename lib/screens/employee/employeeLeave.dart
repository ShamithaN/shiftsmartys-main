import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/screens/employee/employeeLeavecreate.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';
import 'package:shiftsmart/services/LeaveService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/emp_slidenav.dart';

class Employeeleave extends StatefulWidget {
  const Employeeleave({super.key});

  @override
  State<Employeeleave> createState() => _EmployeeleaveState();
}

class _EmployeeleaveState extends State<Employeeleave> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  // State Variables
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;

  // Services
  final LeaveService _leaveService = LeaveService();

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
    await _fetchLeaveRequests();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLeaveRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getInt('employeeId');

    if (employeeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee ID not found!')),
        );
      }
      return;
    }

    try {
      final allRequests = await _leaveService.fetchLeaveRequests();
      final empRequests = allRequests
          .where((request) => request.employeeId == employeeId)
          .toList();

      if (mounted) {
        setState(() {
          _leaveRequests = empRequests
              .map((request) => {
                    'LeaveRequestId': request.leaveRequestId,
                    'LeaveType': request.leaveType,
                    'StartDate': request.startDate,
                    'EndDate': request.endDate,
                    'Reason': request.reason,
                    'Status': request.status,
                    'RequestedAt': request.requestedAt,
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const EmpSidenav(),
      backgroundColor: const Color(0xFF1C2230),
      body: Stack(
        children: [
          const Background(),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF724584)))
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
                              const SizedBox(height: 10),
                              addLeave(context),
                              const SizedBox(height: 15),
                              _leaveList(),
                              const SizedBox(height: 10),
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

  Widget addLeave(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(180, 42, 50, 67),
            Color.fromARGB(180, 34, 40, 52),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/Leave.png',
                color: const Color(0xFF3498DB),
                width: 30,
                height: 30,
              ),
              const SizedBox(width: 12),
              const Text(
                "APPLY FOR LEAVE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () async {
              // We wait for the result from the create screen
              final result = await showGeneralDialog(
                context: context,
                barrierColor: Colors.black,
                barrierDismissible: true,
                barrierLabel: 'APPLY FOR LEAVE',
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, __, ___) {
                  return Employeeleavecreate(leaveRequests: _leaveRequests);
                },
              );

              // 1. Refresh list regardless
              _refreshData();

              // 2. Show Success Dialog ONLY if result is true
              // (NOTE: Your Employeeleavecreate.dart must return true on success)
              if (result == true && mounted) {
                SuccessDialog.show(
                  context,
                  title: "Application Sent",
                  message:
                      "Your leave request has been submitted successfully.",
                  buttonText: "OK",
                  onPressed: () => Navigator.pop(context),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.add_box_outlined,
                color: Colors.blueAccent,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveList() {
    final reversedRequests = _leaveRequests.reversed.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedRequests.length,
      itemBuilder: (itemContext, index) {
        final leaveRequest = reversedRequests[index];
        final String status = leaveRequest['Status'] ?? 'Pending';

        // Define colors based on status
        Color statusColor;
        Color statusBgColor;

        if (status == "Approved") {
          statusColor = Colors.greenAccent;
          statusBgColor = Colors.green.withOpacity(0.2);
        } else if (status == "Rejected") {
          statusColor = Colors.redAccent;
          statusBgColor = Colors.red.withOpacity(0.2);
        } else {
          statusColor = Colors.amberAccent;
          statusBgColor = Colors.amber.withOpacity(0.2);
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF363E51), Color(0xFF191E26)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Type and Delete Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    leaveRequest['LeaveType'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                      size: 24,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2F36),
                          title: const Text("Confirm Deletion"),
                          titleTextStyle: const TextStyle(
                              color: Colors.white, fontSize: 20),
                          contentTextStyle:
                              const TextStyle(color: Colors.white70),
                          content: const Text(
                              "Are you sure you want to delete this request?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel",
                                  style: TextStyle(color: Colors.white)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Delete",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final success = await _leaveService
                            .deleteLeaveRequest(leaveRequest['LeaveRequestId']);

                        if (success != null && success) {
                          _refreshData();
                          if (mounted) {
                            SuccessDialog.show(
                              context,
                              title: "Request Deleted",
                              message: "The leave request has been removed.",
                              buttonText: "OK",
                              onPressed: () => Navigator.pop(context),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Failed to delete request")),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Dates
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "${DateFormat('MMM dd, yyyy').format(leaveRequest['StartDate'])}  —  ${DateFormat('MMM dd, yyyy').format(leaveRequest['EndDate'])}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Highlighted Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
