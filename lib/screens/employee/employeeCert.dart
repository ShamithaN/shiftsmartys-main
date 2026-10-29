import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/empcertModel.dart';
import 'package:shiftsmart/services/EmployeeService.dart'; // 👈 Import this
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/emp_slidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:url_launcher/url_launcher.dart';

class Employeecert extends StatefulWidget {
  const Employeecert({super.key});

  @override
  State<Employeecert> createState() => _EmployeecertState();
}

class _EmployeecertState extends State<Employeecert> {
  List<EmployeeCertificate> _certificates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get Logged-in Employee ID
      final prefs = await SharedPreferences.getInstance();
      // Ensure 'employeeId' key matches what you save in Login.dart (it might be 'userId' or 'employeeId')
      final int? empId = prefs.getInt('employeeId') ?? prefs.getInt('userId');

      if (empId != null) {
        // 2. Fetch Docs using EmployeeService
        final docs = await EmployeeService().fetchEmployeeDocuments(empId);
        setState(() {
          _certificates = docs;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint("❌ No Employee ID found in SharedPreferences");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading docs: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const EmpSidenav(currentScreen: 'EmployeeCert'),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(showBackButton: false),
      body: Stack(children: [
        const Background(),
        Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "MY DOCUMENTS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Documents submitted during onboarding",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _buildDocList(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ])
      ]),
    );
  }

  Widget _buildDocList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 50.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_certificates.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 30),
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: const [
            Icon(Icons.folder_off_outlined, size: 40, color: Colors.white38),
            SizedBox(height: 10),
            Text("No documents found.",
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Column(
      children: _certificates.map((doc) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3240), Color(0xFF1C2230)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Color(0xFF3498DB),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.fileName.toUpperCase(), // Display "NATIONAL ID", etc.
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Verified Document",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // View Button
              SizedBox(
                height: 38,
                width: 85,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final url = doc.documentUrl;
                    if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cannot open document")),
                        );
                      }
                    }
                  },
                  child: const Text("View",
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
