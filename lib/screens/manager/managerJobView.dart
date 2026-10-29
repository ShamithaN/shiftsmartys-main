import 'package:flutter/material.dart';
import 'package:shiftsmart/models/Project.dart' as model;
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/screens/manager/managerCreateJob.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/models/Job.dart';

class ManagerJobView extends StatefulWidget {
  final Job job;

  const ManagerJobView({super.key, required this.job});

  @override
  State<ManagerJobView> createState() => _ManagerJobViewState();
}

class _ManagerJobViewState extends State<ManagerJobView> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late String selectedStatus;
  late int selectedProjectId;
  late int selectedSiteId;
  late DateTime selectedStartDate;
  late DateTime selectedDueDate;
  List<Map<String, dynamic>> jobRoles = [];
  final ProjectService _projectService = ProjectService();

  model.Project? project;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchProject();

    titleController = TextEditingController(text: widget.job.title);
    descriptionController = TextEditingController(text: widget.job.description);
    selectedStatus = widget.job.status;
    selectedProjectId = widget.job.projectId;
    selectedSiteId = widget.job.siteId;
    selectedStartDate = DateTime.parse(widget.job.startDate);
    selectedDueDate = DateTime.parse(widget.job.jobDueDate);
  }

  String _formatDate(String dateTimeString) {
    if (dateTimeString.contains('T')) {
      return dateTimeString.split('T')[0];
    }
    return dateTimeString;
  }

  Future<void> fetchProject() async {
    try {
      final projects = await _projectService.fetchAllProjects();
      setState(() {
        project =
            projects.firstWhere((p) => p.projectId == widget.job.projectId,
                orElse: () => model.Project(
                      projectId: 0,
                      name: 'Unknown Project',
                      estimatedTime: 0,
                      location: 'Unknown',
                      description: '',
                      additionalRemark: '',
                      projectDue: '',
                      startDate: '',
                      endDate: '',
                      companyName: '',
                      status: '',
                      sites: [],
                    ));
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to load projects $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          Column(
            children: [
              const Uppernavbar(
                showBackButton: true,
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.07, vertical: 20),
                          child: Gradienthorizontal(
                            width: double.infinity,
                            // height: 950,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.job.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    project?.name ?? "Unknown Project",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 40),

                                  _infoRow("Status", widget.job.status,
                                      isStatus: true),
                                  const SizedBox(height: 15),

                                  _infoRow(
                                    "Location",
                                    project?.sites
                                            .firstWhere(
                                              (s) =>
                                                  s.siteId == widget.job.siteId,
                                              orElse: () => Site(
                                                siteId: 0,
                                                projectId: widget.job.projectId,
                                                siteName: 'Unknown Location',
                                                latitude: '',
                                                longitude: '',
                                                geoFenceType: '',
                                                geoCoordinates: '',
                                                radius: 0,
                                              ),
                                            )
                                            .siteName ??
                                        'Unknown Location',
                                  ),
                                  const SizedBox(height: 15),

                                  _infoRow("Due Date",
                                      _formatDate(widget.job.jobDueDate)),
                                  const SizedBox(height: 15),

                                  _infoRow("Start Date",
                                      _formatDate(widget.job.startDate)),
                                  const SizedBox(height: 15),

                                  _infoRow("End Date",
                                      _formatDate(widget.job.jobDueDate)),
                                  const SizedBox(height: 15),

                                  const Text(
                                    "Description",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.job.description.isNotEmpty
                                        ? widget.job.description
                                        : "No description available.",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  // const Spacer(),

                                  Row(
                                    children: [
                                      // Expanded(
                                      //   child: GradientButton(
                                      //     text: "Delete",
                                      //     onPressed: _confirmAndDelete,
                                      //     gradientColors: [
                                      //       const Color.fromARGB(255, 89, 1, 1),
                                      //       const Color(0xFFC04143)
                                      //     ],
                                      //   ),
                                      // ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: GradientButton(
                                          text: "Update",
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                  ManagerCreateJob(
                                                    existingJob:
                                                      widget.job),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value.toString(),
            style: TextStyle(
              color: isStatus ? const Color(0xFFEBCC46) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
