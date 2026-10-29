import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shiftsmart/models/company.dart';
import 'package:shiftsmart/services/CompanyService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/success_dialog.dart'; // 👈 Import Success Dialog
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class Managercreatecom extends StatefulWidget {
  final Company? company;

  const Managercreatecom({super.key, this.company});

  @override
  State<Managercreatecom> createState() => _ManagercreatecomState();
}

class _ManagercreatecomState extends State<Managercreatecom> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _personController = TextEditingController();

  // Address Search Variables
  String tokenForSession = const Uuid().v4();
  List<String> _suggestions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    if (widget.company != null) {
      _nameController.text = widget.company!.name;
      _phoneController.text = widget.company!.phoneNumber.toString();
      _addController.text = widget.company!.address;
      _personController.text = widget.company!.ContactPerson;
    }
  }

  // --- 1. Address Suggestion Logic ---
  Future<List<Map<String, String>>> makeSuggestion(String input) async {
    String key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&sessiontoken=$tokenForSession";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List;
        return predictions.map<Map<String, String>>((e) {
          return {
            "description": e['description'],
            "place_id": e['place_id'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Address fetch error: $e");
    }
    return [];
  }

  // --- 2. Save Logic ---
  Future<void> _saveCompany() async {
    // Basic Validation
    if (_nameController.text.isEmpty || _addController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and Address are required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> companyData = {
      "Name": _nameController.text.trim(),
      "ContactNumber": _phoneController.text.trim(),
      "Address": _addController.text.trim(),
      "ContactPerson": _personController.text.trim()
    };

    if (widget.company != null) {
      companyData["CompanyId"] = widget.company!.id;
    }

    bool success = false;

    try {
      if (widget.company != null) {
        success = await CompanyService()
            .updateCompany(widget.company!.id, companyData);
      } else {
        success = await CompanyService().addCompany(companyData);
      }

      setState(() => _isSaving = false);

      if (mounted) {
        if (success) {
          // --- Show Success Dialog ---
          SuccessDialog.show(
            context,
            title: widget.company != null
                ? "Update Successful"
                : "Creation Successful",
            message: widget.company != null
                ? "Company details have been updated."
                : "New company has been created successfully.",
            buttonText: "OK",
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to list screen with 'true'
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save company")),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.company != null;

    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      body: Stack(children: [
        const Background(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Gradienthorizontal(
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      isEditMode ? "UPDATE COMPANY" : "CREATE COMPANY",
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
                  _buildTextField("Contact Person", _personController),
                  const SizedBox(height: 10),
                  _buildTextField("Contact Number", _phoneController,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),

                  // Address Field with Search
                  _buildAddressField(),

                  const SizedBox(height: 30),

                  // Action Buttons
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
                      const SizedBox(width: 15),
                      Expanded(
                        child: GradientButton(
                          text: isEditMode ? "Update" : "Create",
                          onPressed: _saveCompany,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        )
      ]),
    );
  }

  // Generic Text Field
  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
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
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
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

  // Address Field with Suggestions
  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Address",
          style: TextStyle(
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
            controller: _addController,
            style: const TextStyle(color: Colors.white),
            onChanged: (value) async {
              if (value.isNotEmpty) {
                final results = await makeSuggestion(value);
                setState(() {
                  _suggestions =
                      results.map((e) => e['description'] ?? '').toList();
                });
              } else {
                setState(() {
                  _suggestions = [];
                });
              }
            },
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              suffixIcon: _suggestions.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () => setState(() => _suggestions = []),
                    )
                  : const Icon(Icons.search, color: Colors.white54),
            ),
          ),
        ),

        // Suggestion List Dropdown
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    suggestion,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  onTap: () {
                    setState(() {
                      _addController.text = suggestion;
                      _suggestions.clear(); // Hide list after selection
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
