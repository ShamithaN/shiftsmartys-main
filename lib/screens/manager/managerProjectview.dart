import 'package:flutter/material.dart';
import 'package:shiftsmart/screens/manager/managerCreateProject1.dart';
import 'package:shiftsmart/services/ProjectService.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/models/Project.dart';

class Managerprojectview extends StatefulWidget {
  final Project? project;

  const Managerprojectview({required this.project, super.key});

  @override
  State<Managerprojectview> createState() => _ManagerprojectviewState();
}

class _ManagerprojectviewState extends State<Managerprojectview> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      drawer: const Sidenav(),
      appBar: const Uppernavbar(showBackButton: true),
      body: Stack(
        children: [
          const Positioned(child: Background()),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: double.infinity, // Full width for mobile
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Gradienthorizontal(
                            width: double.infinity,
                            height: 630,  // Fixed height for mobile
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: double.infinity,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildHeader(),
                                      SizedBox(height: 24),
                                      _buildProjectInfo(),
                                      const SizedBox(height: 16),
                                      _buildDescription(),
                                      SizedBox(height: 40),
                                      _buildActionButtons(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.checklist_rounded,
          color: Colors.blueAccent,
          size: 48,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            widget.project!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectInfo() {
    return Column(
      children: [
        _info("Status:", widget.project!.status, valueColor: Colors.yellowAccent),
        _info("Project owner:", widget.project!.companyName),
        _info("Start Date:", _formatDate(widget.project!.startDate)),
        _info("End Date:", _formatDate(widget.project!.endDate)),
        _info("Due date:", _formatDate(widget.project!.projectDue)),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Description",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            widget.project!.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, // This will space the buttons evenly
    children: [
      // First button (Complete)
      Expanded(
        child: GradientButton(
          onPressed: _markComplete,
          text: 'Complete',
        ),
      ),
      const SizedBox(width: 16), // Space between the two buttons
      // Second button (Update)
      Expanded(
        child: GradientButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Managercreateproject(project: widget.project),
              ),
            );
          },
          text: 'Update',
        ),
      ),
    ],
  );
}

  Widget _info(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _formatDate(String rawDate) {
    try {
      final date = DateTime.parse(rawDate);
      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}";
    } catch (e) {
      return rawDate; // fallback to original if parsing fails
    }
  }

  void _markComplete() async {
    final success =
        await ProjectService().updateProject(widget.project!.projectId, {
      "name": widget.project!.name,
      "description": widget.project!.description,
      "additionalRemarks": widget.project!.additionalRemark,
      "projectDue": widget.project!.projectDue,
      "startDate": widget.project!.startDate,
      "endDate": widget.project!.endDate,
      "companyName": widget.project!.companyName,
      "status": "Complete",
    });
    if (success) {
      setState(() {
        widget.project!.status = "Complete";
      });
    }
  }
}
