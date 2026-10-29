import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shiftsmart/services/JobService.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/services/SiteService.dart';
import 'package:shiftsmart/widgets/custom_date_picker.dart';
import 'package:shiftsmart/models/Job.dart';
import 'package:shiftsmart/models/JobRole.dart';
import 'package:shiftsmart/models/JobRoleType.dart';
import 'package:shiftsmart/models/Project.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/bottomnavbar.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class ManagerCreateJob extends StatefulWidget {
  final Job? existingJob;
  const ManagerCreateJob({super.key, this.existingJob});

  @override
  State<ManagerCreateJob> createState() => _ManagerCreateJobState();
}

class _ManagerCreateJobState extends State<ManagerCreateJob> {
  // Controllers
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Data Lists
  List<Project> _projects = [];
  List<Site> _sites = [];
  List<JobRoleType> _jobRoleTypes = [];
  final List<JobRole> _selectedJobRoles = [];

  // Selections
  Project? _selectedProject;
  Site? _selectedSite;
  File? _selectedImage;

  // UI State
  bool _isInitializing = true;
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _initializeData();
  }

  // --- 1. ROBUST INITIALIZATION LOGIC ---
  Future<void> _initializeData() async {
    try {
      // Fetch all necessary data first
      final results = await Future.wait([
        ProjectService().fetchAllProjects(),
        SiteService().fetchAllSites(),
        JobService().fetchJobRoleType(),
      ]);

      final allProjects = results[0] as List<Project>;
      final allSites = results[1] as List<Site>;
      final allJobRoleTypes = results[2] as List<JobRoleType>;

      // Variables to hold initial selections
      Project? initialProject;
      Site? initialSite;
      List<JobRole> initialRoles = [];

      // If Editing, populate data
      if (widget.existingJob != null) {
        final job = widget.existingJob!;

        // Fill Text Fields
        _jobNameController.text = job.title;
        _descriptionController.text = job.description;
        _startDateController.text = job.startDate.split('T')[0];
        _endDateController.text = job.jobDueDate.split('T')[0];

        // Find Project (Safe check)
        try {
          initialProject =
              allProjects.firstWhere((p) => p.projectId == job.projectId);
        } catch (e) {
          debugPrint("Warning: Project ID ${job.projectId} not found in list.");
        }

        // Find Site (Safe check)
        if (initialProject != null) {
          try {
            initialSite = allSites.firstWhere((s) =>
                s.siteId == job.siteId &&
                s.projectId == initialProject!.projectId);
          } catch (e) {
            debugPrint(
                "Warning: Site ID ${job.siteId} not found for this project.");
          }
        }

        // Fetch & Populate Roles
        if (job.jobId != 0) {
          try {
            final jobRolesFromServer =
                await JobService().fetchJobRole(job.jobId);
            for (final role in jobRolesFromServer) {
              try {
                // Find matching role type name
                final roleType = allJobRoleTypes
                    .firstWhere((t) => t.id == role.jobRoleTypeId);

                initialRoles.add(JobRole(
                  jobRoleTypeId: role.jobRoleTypeId,
                  estimatedTime: role.estimatedTime,
                  numberOfRoles: role.numberOfRoles,
                  notes: role.notes,
                  roleName: roleType.name,
                ));
              } catch (e) {
                // Role type mismatch, skip adding this role to UI
              }
            }
          } catch (e) {
            debugPrint("Error fetching existing job roles: $e");
          }
        }
      }

      // Update State ONLY once all data is ready
      if (mounted) {
        setState(() {
          _projects = allProjects;
          _sites = allSites;
          _jobRoleTypes = allJobRoleTypes;

          _selectedProject = initialProject;
          _selectedSite = initialSite;

          _selectedJobRoles.clear();
          _selectedJobRoles.addAll(initialRoles);

          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint("Critical Error initializing data: $e");
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load form data. Please retry.')),
        );
      }
    }
  }

  // --- Helper: Get Sites for current Project ---
  List<Site> get sitesForSelectedProject {
    if (_selectedProject == null) return [];
    return _sites
        .where((site) => site.projectId == _selectedProject!.projectId)
        .toList();
  }

  // --- Date Picker Logic ---
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: datePickerThemeBuilder);
    if (pickedDate != null) {
      setState(() {
        controller.text = "${pickedDate.toLocal()}".split(' ')[0];
      });
    }
  }

  // --- Navigation: Next Step ---
  void _nextStep() {
    // Validation Step 1
    if (_currentStep == 0) {
      if (_jobNameController.text.isEmpty ||
          _descriptionController.text.isEmpty ||
          _startDateController.text.isEmpty ||
          _endDateController.text.isEmpty ||
          _selectedProject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all required fields.")),
        );
        return;
      }
    }
    // Validation Step 2
    else if (_currentStep == 1) {
      if (_selectedSite == null || _selectedJobRoles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Please select a site and add at least one job role.")),
        );
        return;
      }
    }
    // Submission Step 3
    else if (_currentStep == 2) {
      _submitJobAction();
      return;
    }

    setState(() {
      _currentStep++;
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // --- Navigation: Previous Step ---
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- Job Roles Logic ---
  void _addJobRole(JobRoleType jobRoleType) {
    bool alreadyExists =
        _selectedJobRoles.any((role) => role.jobRoleTypeId == jobRoleType.id);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${jobRoleType.name} is already added.")),
      );
      return;
    }

    setState(() {
      _selectedJobRoles.insert(
          0,
          JobRole(
            jobRoleTypeId: jobRoleType.id,
            roleName: jobRoleType.name,
            estimatedTime: 8,
            numberOfRoles: 1,
            notes: "",
          ));
    });
  }

  void _removeJobRole(int index) {
    setState(() {
      _selectedJobRoles.removeAt(index);
    });
  }

  // --- Image Picker ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 768,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // --- 2. SUBMIT ACTION ---
  Future<void> _submitJobAction() async {
    String startDate = "${_startDateController.text}T00:00:00";
    String endDate = "${_endDateController.text}T00:00:00";

    final jobData = {
      "title": _jobNameController.text,
      "description": _descriptionController.text,
      "projectId": _selectedProject!.projectId,
      "siteId": _selectedSite!.siteId,
      "startDate": startDate,
      "jobDueDate": endDate,
      "jobRoles": _selectedJobRoles.map((role) => role.toJson()).toList(),
    };

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool success = false;
    String errorMessage = "";

    try {
      if (widget.existingJob != null) {
        // UPDATE
        success =
            await JobService().updateJob(widget.existingJob!.jobId, jobData);
      } else {
        // CREATE
        if (_selectedImage != null) {
          success =
              await JobService().createJobWithImage(jobData, _selectedImage!);
        } else {
          final result = await JobService().addJob(jobData);
          success = result != null && result == 1;
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      success = false;
    }

    Navigator.pop(context); // Dismiss Loading

    if (mounted) {
      if (success) {
        // --- Show Success Dialog ---
        SuccessDialog.show(
          context,
          title: widget.existingJob != null ? "Job Updated" : "Job Created",
          message: widget.existingJob != null
              ? "The job details have been updated successfully."
              : "New job created successfully!",
          buttonText: "Ok",
          onPressed: () {
            Navigator.pop(context); // Close dialog
            // Navigate to Job List (Manager Dashboard)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const Bottomnavbar(selectedIndex: 2)),
              (Route<dynamic> route) => false,
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed: $errorMessage")));
      }
    }
  }

  // --- Image Picker Modal ---
  void _showImageSourceSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A3243),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take a Photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.white),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidenav(),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      backgroundColor: const Color(0xFF1C2230),
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Gradienthorizontal(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.existingJob != null
                              ? "UPDATE JOB"
                              : "CREATE JOB",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isInitializing
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildStep1(),
                                _buildStep2(),
                                _buildStep3(),
                              ],
                            ),
                    ),
                    // --- 🛠️ FIX APPLIED HERE ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _currentStep > 0
                                ? GradientButton(
                                    text: "Back",
                                    isCancel: true,
                                    onPressed: _previousStep,
                                  )
                                : GradientButton(
                                    text: "Cancel",
                                    isCancel: true,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: GradientButton(
                              text: _currentStep == 2
                                  ? (widget.existingJob != null
                                      ? "Update"
                                      : "Create")
                                  : "Next",
                              onPressed: _nextStep,
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
        ],
      ),
    );
  }

  // --- Step 1: Basic Details ---
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField("Name", _jobNameController),
          const SizedBox(height: 16),
          _buildInputField("Description", _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          _buildDateField("Start Date", _startDateController),
          const SizedBox(height: 16),
          _buildDateField("Due Date", _endDateController),
          const SizedBox(height: 16),
          _buildProjectDropdown(),
        ],
      ),
    );
  }

  // --- Step 2: Site & Roles ---
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSiteDropdown(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select Resources",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_jobRoleTypes.isEmpty) return;
                  final defaultRole = _jobRoleTypes.first;
                  _addJobRole(defaultRole);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedJobRoles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text("No roles added yet.",
                      style: TextStyle(color: Colors.white54))),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedJobRoles.length,
            itemBuilder: (context, index) {
              return _buildRoleCard(index, _selectedJobRoles[index]);
            },
          ),
        ],
      ),
    );
  }

  // --- Step 3: Media Upload ---
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Upload files",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Select and upload the files of your choice",
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _showImageSourceSelection,
            child: Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cloud_upload_outlined,
                            color: Colors.white70, size: 48),
                        SizedBox(height: 16),
                        Text("Tap to upload an image",
                            style: TextStyle(color: Colors.white70))
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helper: Role Card ---
  Widget _buildRoleCard(int index, JobRole role) {
    // Ensure we have a valid role type to show in dropdown
    final currentRoleType = _jobRoleTypes.firstWhere(
      (type) => type.id == role.jobRoleTypeId,
      orElse: () => _jobRoleTypes.first, // Fallback safety
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3545),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5568),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<JobRoleType>(
                    value: currentRoleType,
                    onChanged: (newType) {
                      if (newType != null) {
                        setState(() {
                          _selectedJobRoles[index].jobRoleTypeId = newType.id;
                          _selectedJobRoles[index].roleName = newType.name;
                        });
                      }
                    },
                    dropdownColor: const Color(0xFF2E3545),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    iconEnabledColor: Colors.white70,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _jobRoleTypes.map((roleType) {
                      return DropdownMenuItem(
                        value: roleType,
                        child: Text(roleType.name),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _removeJobRole(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCardField(
                  label: "Count:",
                  initialValue: role.numberOfRoles,
                  onChanged: (v) {
                    setState(() => _selectedJobRoles[index].numberOfRoles = v);
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCardField(
                  label: "Time(Hrs):",
                  initialValue: role.estimatedTime,
                  onChanged: (v) {
                    setState(() => _selectedJobRoles[index].estimatedTime = v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardField({
    required String label,
    required int initialValue,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A5568),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextFormField(
              initialValue: initialValue.toString(),
              onChanged: (val) {
                int? parsed = int.tryParse(val);
                if (parsed != null && parsed > 0) {
                  onChanged(parsed);
                }
              },
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Generic UI Helpers ---
  Widget _buildInputField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white70),
                onPressed: () => _selectDate(context, controller),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Project",
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<Project>(
            value: _selectedProject,
            hint: const Text("Select the project",
                style: TextStyle(color: Colors.white70)),
            dropdownColor: const Color(0xFF2E3545),
            iconEnabledColor: Colors.white70,
            isExpanded: true,
            underline: const SizedBox(),
            items: _projects.map((project) {
              return DropdownMenuItem<Project>(
                value: project,
                child: Text(project.name,
                    style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProject = value;
                final sites = sitesForSelectedProject;
                // Auto-select first site if available, else null
                _selectedSite = sites.isNotEmpty ? sites.first : null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSiteDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Site",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<Site>(
            // Safe selection logic:
            value: _sites.contains(_selectedSite) ? _selectedSite : null,
            hint: const Text("Select a site",
                style: TextStyle(color: Colors.white70)),
            dropdownColor: const Color(0xFF2E3545),
            iconEnabledColor: Colors.white70,
            isExpanded: true,
            underline: const SizedBox(),
            items: sitesForSelectedProject.map((site) {
              return DropdownMenuItem<Site>(
                value: site,
                child: Text(site.siteName,
                    style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSite = value;
              });
            },
          ),
        ),
      ],
    );
  }
}
