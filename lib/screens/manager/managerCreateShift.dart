import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/LeaveRequest.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/services/JobService.dart';
import 'package:shiftsmart/services/ShiftService.dart';
import 'package:shiftsmart/services/SiteService.dart';
import 'package:shiftsmart/services/LeaveService.dart';
import 'package:shiftsmart/widgets/custom_date_picker.dart';
import 'package:shiftsmart/models/Employee.dart';
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/models/Shift.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class Managercreateshift extends StatefulWidget {
  final Shift? shift;
  const Managercreateshift({super.key, this.shift});

  @override
  State<Managercreateshift> createState() => _ManagercreateshiftState();
}

class _ManagercreateshiftState extends State<Managercreateshift> {
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _starttimecontroller = TextEditingController();
  final TextEditingController _endtimecontroller = TextEditingController();

  // Data Lists
  List<Employee> allEmployees = [];
  final List<int> _selectedEmptIds = [];
  List<Job> allJobs = [];
  List<Shift> allShifts = [];
  List<LeaveRequest> allLeaves = [];
  List<Site> _sites = [];

  // Selections
  int? _selectedJobId;
  Map<int, String> employeeNameMap = {};

  // Services & State
  final NotificationService _notificationService = NotificationService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _initializeData();
  }

  // --- 1. Initialize All Data ---
  Future<void> _initializeData() async {
    await Future.wait([
      fetchJobs(),
      fetchEmployee(),
      fetchSites(),
      fetchAllShifts(),
      fetchAllLeaves(),
    ]);

    // Pre-fill if editing
    if (widget.shift != null && mounted) {
      final dateFormat = DateFormat('yyyy-MM-dd');
      setState(() {
        _titleController.text = widget.shift!.taskName;
        _dateController.text = dateFormat.format(widget.shift!.date);
        _starttimecontroller.text = widget.shift!.startTime;
        _endtimecontroller.text = widget.shift!.endTime;
        _selectedJobId = widget.shift!.jobId;
        _selectedEmptIds.addAll(widget.shift!.assignedEmployeeIds);
      });
    }
  }

  // --- Fetch Methods ---
  Future<void> fetchAllShifts() async {
    allShifts = await ShiftService().fetchAllShifts();
  }

  Future<void> fetchAllLeaves() async {
    allLeaves = await LeaveService().fetchLeaveRequests();
  }

  Future<void> fetchSites() async {
    final sites = await SiteService().fetchAllSites();
    if (mounted) setState(() => _sites = sites);
  }

  Future<void> fetchEmployee() async {
    final employees = await EmployeeService().fetchAllEmployees();
    final nameMap = await EmployeeService().fetchEmployeeNameMap();
    if (mounted) {
      setState(() {
        allEmployees = employees;
        employeeNameMap = nameMap;
      });
    }
  }

  Future<void> fetchJobs() async {
    final jobs = await JobService().fetchAllJobs();
    if (mounted) setState(() => allJobs = jobs);
  }

  // --- Helper: Format Employee Names ---
  String getEmployeeNames(List<int> employeeIds) {
    List<String> names =
        employeeIds.map((id) => employeeNameMap[id] ?? 'Unknown').toList();
    if (names.isEmpty) return "";
    if (names.length <= 2) return names.join(", ");
    return "${names.take(2).join(", ")} +${names.length - 2} more";
  }

  // --- Date & Time Pickers ---
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: datePickerThemeBuilder);
    if (pickedDate != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
    }
  }

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      builder: datePickerThemeBuilder,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      controller.text = DateFormat('HH:mm:ss').format(dt);
    }
  }

  // --- Conflict Detection Logic ---
  bool isOverlapping(String start1, String end1, String start2, String end2) {
    try {
      final fmt = DateFormat('HH:mm:ss');
      final s1 = fmt.parse(start1);
      final e1 = fmt.parse(end1);
      final s2 = fmt.parse(start2);
      final e2 = fmt.parse(end2);
      return s1.isBefore(e2) && s2.isBefore(e1);
    } catch (e) {
      return false;
    }
  }

  bool isOnLeave(int employeeId, String shiftDateStr) {
    if (shiftDateStr.isEmpty) return false;
    try {
      final shiftDate = DateFormat('yyyy-MM-dd').parse(shiftDateStr);
      for (final leave in allLeaves) {
        if (leave.employeeId == employeeId &&
            leave.status.toLowerCase() == 'approved' &&
            !shiftDate.isBefore(leave.startDate) &&
            !shiftDate.isAfter(leave.endDate)) {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  bool hasConflict(int employeeId, String selectedDate, String selectedStart,
      String selectedEnd) {
    if (selectedDate.isEmpty || selectedStart.isEmpty || selectedEnd.isEmpty) {
      return false;
    }

    for (final shift in allShifts) {
      if (widget.shift != null && shift.shiftId == widget.shift!.shiftId) {
        continue;
      }

      final shiftDate = DateFormat('yyyy-MM-dd').format(shift.date);
      if (shiftDate == selectedDate &&
          shift.assignedEmployeeIds.contains(employeeId)) {
        if (isOverlapping(
            shift.startTime, shift.endTime, selectedStart, selectedEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  // --- 2. Submit Logic ---
  Future<void> _submitShift() async {
    // Basic Validations
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a job first")));
      return;
    }

    if (_isSubmitting) return; // Prevent double taps

    setState(() => _isSubmitting = true);

    // Check Leaves
    final onLeaveEmployees = _selectedEmptIds
        .where((id) => isOnLeave(id, _dateController.text.trim()))
        .toList();

    if (onLeaveEmployees.isNotEmpty) {
      final names = onLeaveEmployees
          .map((id) => employeeNameMap[id] ?? 'Unknown')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$names are on approved leave.")));
      setState(() => _isSubmitting = false);
      return;
    }

    // Check Shift Overlaps
    final date = _dateController.text.trim();
    final start = _starttimecontroller.text.trim();
    final end = _endtimecontroller.text.trim();
    final conflictingAssignments = <int, int>{};

    for (final empId in _selectedEmptIds) {
      for (final shift in allShifts) {
        if (widget.shift != null && shift.shiftId == widget.shift!.shiftId) {
          continue;
        }

        if (shift.date.toString().substring(0, 10) == date &&
            shift.assignedEmployeeIds.contains(empId)) {
          if (isOverlapping(shift.startTime, shift.endTime, start, end)) {
            conflictingAssignments[empId] = shift.shiftId;
          }
        }
      }
    }

    if (conflictingAssignments.isNotEmpty) {
      final employeeNames = conflictingAssignments.keys
          .map((id) => employeeNameMap[id] ?? 'Unknown')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Overlapping shifts for: $employeeNames")));
      setState(() => _isSubmitting = false);
      return;
    }

    // Prepare Data
    final selectedJob = allJobs.firstWhere(
      (job) => job.jobId == _selectedJobId,
      orElse: () => Job(
          jobId: 0,
          title: '',
          description: '',
          status: '',
          projectId: 0,
          totalEstimatedTime: 0,
          siteId: 0,
          startDate: '',
          jobDueDate: '',
          jobImageUrl: '',
          jobRoles: []),
    );

    final matchingSite = _sites.firstWhere(
      (site) => site.siteId == selectedJob.siteId,
      orElse: () => Site(siteId: 0, siteName: 'Unknown'),
    );

    final shiftData = {
      "JobId": _selectedJobId,
      "TaskName": _titleController.text.trim(),
      "Date": _dateController.text.trim(),
      "StartTime": _starttimecontroller.text.trim(),
      "EndTime": _endtimecontroller.text.trim(),
      "Location": matchingSite.siteName,
      "Status": "Scheduled",
      "AssignedEmployeeIds": _selectedEmptIds,
    };

    // API Call
    bool success = false;
    try {
      if (widget.shift != null) {
        success =
            await ShiftService().updateShift(widget.shift!.shiftId, shiftData);
      } else {
        success = await ShiftService().addShift(shiftData);
      }
    } catch (e) {
      debugPrint("Error submitting shift: $e");
      success = false;
    }

    if (success) {
      // Send Notifications
      for (var empId in _selectedEmptIds) {
        await _notificationService.sendShiftNotification(
            empId, "New shift assigned: $date at $start");
      }

      if (mounted) {
        // --- Show Success Dialog ---
        SuccessDialog.show(
          context,
          title: widget.shift != null ? "Shift Updated" : "Shift Created",
          message: widget.shift != null
              ? "The shift details have been updated successfully."
              : "New shift has been created successfully.",
          buttonText: "OK",
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(
                context, true); // Return to list screen with 'true' to refresh
          },
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Operation Failed")));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(showBackButton: true),
      body: Stack(
        children: [
          const Background(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Gradienthorizontal(
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        widget.shift != null ? "UPDATE SHIFT" : "CREATE SHIFT",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownJob(),
                    const SizedBox(height: 10),
                    _buildTextField("Shift Name", _titleController),
                    const SizedBox(height: 10),
                    _buildDateField("Date", _dateController),
                    const SizedBox(height: 10),
                    _buildTime("Start Time", _starttimecontroller),
                    const SizedBox(height: 10),
                    _buildTime("End Time", _endtimecontroller),
                    const SizedBox(height: 10),
                    _buildMultiEmployeeSelector(),
                    const SizedBox(height: 20),

                    // --- Action Buttons ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GradientButton(
                            text: "Cancel",
                            onPressed: () => Navigator.pop(context),
                            isCancel: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Expanded(
                        //   child: GradientButton(
                        //     text: widget.shift != null ? "Update" : "Create",
                        //     // ✅ Fixed onPressed syntax
                        //     onPressed: _isSubmitting ? null : () { _submitShift(); },
                        //   ),
                        // ),
                        Expanded(
                          child: GradientButton(
                            text: widget.shift != null ? "Update" : "Create",
                            onPressed: _isSubmitting ? () {} : _submitShift,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helper: Text Field ---
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly
                ? Colors.grey.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white70),
            enabled: !isReadOnly,
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Date Picker ---
  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined,
                      color: Colors.white70, size: 20),
                  onPressed: () => _selectDate(context, controller)),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Time Picker ---
  Widget _buildTime(String label, TextEditingController timeController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: timeController,
            readOnly: true,
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time,
                      color: Colors.white70, size: 20),
                  onPressed: () => _selectTime(context, timeController)),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Job Dropdown ---
  Widget _buildDropdownJob() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Job",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: const Color(0xFF2A3243),
              value: allJobs.any((job) => job.jobId == _selectedJobId)
                  ? _selectedJobId
                  : null,
              isExpanded: true,
              items: allJobs
                  .map((job) => DropdownMenuItem<int>(
                      value: job.jobId,
                      child: Text(job.title,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (value) => setState(() => _selectedJobId = value),
              hint: const Text("Choose a Job",
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Employee Selector Modal ---
  Widget _buildMultiEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Employees",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            // Already fetched in initState, but safe check
            if (allShifts.isEmpty) await fetchAllShifts();

            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF2A3243),
              isScrollControlled: true, // Better for search
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              builder: (context) {
                String searchQuery = '';
                List<Employee> filteredEmployees = List.from(allEmployees);

                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              onChanged: (value) {
                                setModalState(() {
                                  searchQuery = value.toLowerCase();
                                  filteredEmployees = allEmployees.where((e) {
                                    final fullName =
                                        employeeNameMap[e.employeeId] ??
                                            e.firstName;
                                    return fullName
                                        .toLowerCase()
                                        .contains(searchQuery);
                                  }).toList();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Search employees...",
                                hintStyle:
                                    const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final employee = filteredEmployees[index];
                                final isSelected = _selectedEmptIds
                                    .contains(employee.employeeId);
                                final fullName =
                                    employeeNameMap[employee.employeeId] ??
                                        employee.firstName;
                                final hasCon = hasConflict(
                                    employee.employeeId,
                                    _dateController.text,
                                    _starttimecontroller.text,
                                    _endtimecontroller.text);
                                final onL = isOnLeave(
                                    employee.employeeId, _dateController.text);

                                return ListTile(
                                  title: Text(fullName,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check,
                                          color: Colors.greenAccent)
                                      : (hasCon || onL
                                          ? const Icon(Icons.warning,
                                              color: Colors.red)
                                          : null),
                                  subtitle: (hasCon || onL)
                                      ? Text(hasCon ? "Conflict" : "On Leave",
                                          style: const TextStyle(
                                              color: Colors.red, fontSize: 12))
                                      : null,
                                  onTap: (hasCon || onL)
                                      ? null
                                      : () {
                                          setModalState(() {
                                            // Toggle selection inside modal
                                          });
                                          setState(() {
                                            if (isSelected) {
                                              _selectedEmptIds
                                                  .remove(employee.employeeId);
                                            } else {
                                              _selectedEmptIds
                                                  .add(employee.employeeId);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        _selectedEmptIds.isEmpty
                            ? "Search and select employees"
                            : getEmployeeNames(_selectedEmptIds),
                        style: TextStyle(
                            color: _selectedEmptIds.isEmpty
                                ? Colors.white54
                                : Colors.white))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
