import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/widgets/custom_date_picker.dart';
import 'package:shiftsmart/screens/manager/managerCreateProject2.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/models/Project.dart';

class Managercreateproject extends StatefulWidget {
  final Project? project;
  const Managercreateproject({this.project, super.key});

  @override
  State<Managercreateproject> createState() => _ManagercreateprojectState();
}

class _ManagercreateprojectState extends State<Managercreateproject> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _additionalController = TextEditingController();
  final TextEditingController _datedueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    // Pre-fill data if editing
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descController.text = widget.project!.description;
      _additionalController.text = widget.project!.additionalRemark;
      _datedueController.text = widget.project!.projectDue;
    }
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
      final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      setState(() => controller.text = formattedDate);
    }
  }

  // --- Navigation Logic ---
  void _goToNextStep() {
    // 1. Basic Validation
    if (_nameController.text.isEmpty ||
        _descController.text.isEmpty ||
        _datedueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }

    // 2. Navigate to Step 2
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Managercreateproject2(
          name: _nameController.text,
          description: _descController.text,
          additionalRemark: _additionalController.text,
          projectDue: _datedueController.text,
          project: widget.project, // Pass original object if editing
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20.0),
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.project != null
                                ? "UPDATE PROJECT (Step 1/2)"
                                : "CREATE PROJECT (Step 1/2)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Fields
                        _buildTextField("Name", _nameController),
                        const SizedBox(height: 10),
                        _buildTextField("Description", _descController),
                        const SizedBox(height: 10),
                        _buildTextField(
                            "Additional Remark", _additionalController),
                        const SizedBox(height: 10),
                        _buildDateField(
                            "Estimated Due Date", _datedueController),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
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
                        Expanded(
                          child: GradientButton(
                            text: "Next",
                            onPressed: _goToNextStep,
                          ),
                        ),
                      ],
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

  // --- UI Helper: Text Field ---
  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Date Field ---
  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
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
                onPressed: () => _selectDate(context, controller),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
