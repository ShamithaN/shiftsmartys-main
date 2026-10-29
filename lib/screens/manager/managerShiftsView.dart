import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/models/Shift.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/services/JobService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/services/AttendanceService.dart';

class ManagerShiftsView extends StatefulWidget {
  final Shift shift;

  const ManagerShiftsView({super.key, required this.shift});

  @override
  State<ManagerShiftsView> createState() => _ManagerShiftsViewState();
}

class _ManagerShiftsViewState extends State<ManagerShiftsView> {
  List<Job> allJobs = [];
  List<Job> filteredJobs = [];
  Map<int, String> employeeMap = {};
  Map<int, int> attendanceMap = {};
  final JobService _jobservice = JobService();
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchJobs();
    fetchEmployees();
  }

  Future<void> fetchJobs() async {
    final jobs = await _jobservice.fetchAllJobs();

    setState(() {
      allJobs = jobs;
      filteredJobs = List.from(allJobs);
    });
  }

  Future<void> fetchEmployees() async {
    final map = await EmployeeService().fetchEmployeeNameMap();
    if (mounted) {
      setState(() {
        employeeMap = map;
      });
    }
  }

  String _getJobTitleByJobId(int jobId) {
    final job = allJobs.firstWhere(
      (j) => j.jobId == jobId,
      orElse: () => Job(
        jobId: 0,
        title: 'Unknown',
        description: '',
        status: '',
        projectId: 0,
        totalEstimatedTime: 0,
        siteId: 0,
        startDate: '',
        jobDueDate: '',
        jobImageUrl: '',
        jobRoles: [],
      ),
    );
    return job.title;
  }

  String _getJobImageByJobId(int jobId) {
    final job = allJobs.firstWhere(
      (j) => j.jobId == jobId,
      orElse: () => Job(
        jobId: 0,
        title: 'Unknown',
        description: '',
        status: '',
        projectId: 0,
        totalEstimatedTime: 0,
        siteId: 0,
        startDate: '',
        jobDueDate: '',
        jobImageUrl: '',
        jobRoles: [],
      ),
    );
    return job.jobImageUrl;
  }

  String _formatTime(String timeString) {
    try {
      final time = DateFormat.Hms().parse(timeString); // Parses "HH:mm:ss"
      return DateFormat.Hm().format(time); // Formats as "HH:mm"
    } catch (e) {
      return timeString; // fallback if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;
    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Background(),
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Gradienthorizontal(
                width: double.infinity,
                height: double.infinity,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return SingleChildScrollView(
                          child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.taskName,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 30),
                              _buildInfoRow("Status:", shift.status,
                                  color: shift.status == "Active" ? Colors.greenAccent : Colors.yellowAccent),
                              _buildInfoRow(
                                "Date:",
                                DateFormat.yMMMMd().format(shift.date),
                              ),
                              _buildInfoRow(
                                  "Start Time:", _formatTime(shift.startTime)),
                              _buildInfoRow(
                                  "End Time:", _formatTime(shift.endTime)),
                              _buildInfoRow("Job:",
                                  _getJobTitleByJobId(shift.jobId ?? 0)),
                              const SizedBox(height: 20),
                              LabelWithImageDialog(
                                label: "Job Media:",
                                buttonLabel: "Media",
                                imageUrl: _getJobImageByJobId(shift.jobId ?? 0),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Assigned Employees",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...shift.employeeResponses.map((response) {
                                  final name = _getEmployeeNameById(response.employeeId);
                                  return _buildEmployeeCard(name, response);
                                }),
                            ],
                          ),
                        ),
                      ));
                    }),
                  ),
                ),
              ))
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(width: 8), // Add some spacing
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              maxLines: null, // Allow unlimited lines
              overflow: TextOverflow.visible, // Show all text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(String name, EmployeeResponse response) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(response.status).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(response.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  response.status,
                  style: TextStyle(
                    color: _getStatusColor(response.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (response.clockInTime != null)
            _buildDetailRow(Icons.login, "Clock In:",
                DateFormat('MMM d, hh:mm a').format(response.clockInTime!.toLocal())),
          if (response.clockOutTime != null)
            _buildDetailRow(Icons.logout, "Clock Out:",
                DateFormat('MMM d, hh:mm a').format(response.clockOutTime!.toLocal())),
          if (response.isEarlyExit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Early Exit: ${response.earlyExitReason ?? 'No reason provided'}",
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1BAFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                final photos = await _attendanceService.fetchAttendancePhotos(
                    response.employeeId, widget.shift.shiftId);

                if (photos.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Attendance images not found for this shift')),
                  );
                  return;
                }

                final clockInUrl = photos['clockIn'];
                final clockOutUrl = photos['clockOut'];
                
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2F36),
                    title: const Text("Evidence"),
                    titleTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (clockInUrl != null && clockInUrl.isNotEmpty) ...[
                            const Text("Clock In",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(clockInUrl),
                            ),
                          ] else 
                            const Text("Clock In image not available", style: TextStyle(color: Colors.white70)),
                          
                          const SizedBox(height: 20),
                          
                          if (clockOutUrl != null && clockOutUrl.isNotEmpty) ...[
                            const Text("Clock Out",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(clockOutUrl),
                            ),
                          ] else 
                            const Text("Clock Out image not available", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close", style: TextStyle(color: Color(0xFF1BAFFF))),
                      )
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              label:
                  const Text("View Evidence", style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'clockedin':
        return Colors.green;
      case 'clockedout':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'declined':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.white54;
    }
  }

  String _getEmployeeNameById(int id) {
    return employeeMap[id] ?? "$id";
  }
}

class LabelWithImageDialog extends StatelessWidget {
  final String label;
  final String buttonLabel;
  final String? imageUrl;

  const LabelWithImageDialog({
    super.key,
    required this.label,
    required this.buttonLabel,
    required this.imageUrl,
  });

  void _showImageDialog(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Failed to load image',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            )),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1BAFFF),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 5,
          ),
          onPressed: () => _showImageDialog(context),
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
          label: Text(buttonLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
