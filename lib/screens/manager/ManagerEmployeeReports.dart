import 'package:flutter/material.dart';
import 'package:shiftsmart/screens/manager/ManagerEmployeePerformanceReport.dart';
import 'package:shiftsmart/screens/manager/managerAttendanceReport.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class ManagerEmployeeReports extends StatefulWidget {
  const ManagerEmployeeReports({super.key});

  @override
  State<ManagerEmployeeReports> createState() => _ManagerEmployeeReportsState();
}

class _ManagerEmployeeReportsState extends State<ManagerEmployeeReports> {
  @override
  void initState() {
    super.initState();
    enableFullScreen();
    
  }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF1C2230),
    appBar: const Uppernavbar(),
    drawer: const Sidenav(currentScreen: 'ManagerReports',),
    body: Stack(
      children: [
        const Positioned(child: Background()),
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    _buildReportCard(
                      icon: Icons.line_axis_sharp,
                      title: "Employee Performance Reports",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManagerEmployeePerformanceReport(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildReportCard(
                      icon: Icons.fact_check_outlined,
                      title: "Shift Attendance Report",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Managerattendancereport(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
Widget _buildReportCard({
  required IconData icon,
  required String title,
  required VoidCallback onPressed,
}) {
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromARGB(180, 42, 50, 67),
          Color.fromARGB(180, 34, 40, 52),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B6E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_sharp, color: Colors.white, size: 35),
          onPressed: onPressed,
        ),
      ],
    ),
  );
}


}
