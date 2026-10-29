import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/screens/employee/employeeCert.dart';
import 'package:shiftsmart/screens/employee/employeeEmergency.dart';
import 'package:shiftsmart/screens/employee/employeeFaq.dart';
import 'package:shiftsmart/screens/employee/employeeSettings.dart';
import 'package:shiftsmart/screens/login.dart';
import 'package:shiftsmart/screens/employee/employeeProfile.dart';
import 'package:shiftsmart/services/phoneService.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
import 'package:shiftsmart/services/auth_service.dart';

class AppTextStyle {
  static const sidenavtext = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}

class EmpSidenav extends StatefulWidget {
  final String? currentScreen;
  const EmpSidenav({super.key,  this.currentScreen});

  @override
  State<EmpSidenav> createState() => _EmpSidenavState();
}

class _EmpSidenavState extends State<EmpSidenav> {
  final AuthService _authService = AuthService();

  // ignore: prefer_typing_uninitialized_variables
  late final userProfile;
  @override
  void initState() {
    super.initState();
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    int? employeeId = prefs.getInt('employeeId');

    bool success = await _authService.logout(employeeId);

    if (success) {
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logout failed. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userProfile = userProvider.userProfile;

    if (userProfile.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final size = MediaQuery.of(context).size;
    final paddingUnit = size.width * 0.05;
    final iconSize = size.width * 0.06;
    final logoSize = size.width * 0.4;
    return Drawer(
      width: size.width * 0.5,
      child: Container(
        color: const Color(0xFF161622),
        child: Column(
          children: [
            Padding(
              padding:
                  EdgeInsets.only(top: paddingUnit * 3, bottom: paddingUnit),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EmployeeProfile()),
                      );
                    },
                    child: const ProfileAvatar(editable: false),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}'
                            .trim()
                            .isEmpty
                        ? 'No Name'
                        : '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userProfile['jobRole'] ?? 'No Position',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24, thickness: 1),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  buildNavItem('Home', 'assets/Home.png', iconSize, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmpBottomnavbar(),
                      ),
                    );
                  }),
                  buildNavItem(
                    'Settings',
                    'assets/settings.png',
                    iconSize,
                    () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeeSettings(),
                          settings:
                              const RouteSettings(name: 'EmployeeSettings'),
                        ),
                      );
                    },
                    isActive: widget.currentScreen == 'EmployeeSettings',
                  ),
                  buildNavItem(
                    'Emergency',
                    'assets/Siren.png',
                    iconSize,
                    () {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeEmergency(phoneService: RealPhoneService()),
                            settings:
                                const RouteSettings(name: 'EmployeeEmergency'),
                          ));
                    },
                    isActive: widget.currentScreen == 'EmployeeEmergency',
                  ),
                  buildNavItem('Certificate', 'assets/Diploma.png', iconSize,
                      () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Employeecert(),
                            settings: const RouteSettings(name: 'EmployeeCert'),
                            ));
                  },
                  isActive: widget.currentScreen == 'EmployeeCert',
                  ),
                  buildNavItem('FAQ', 'assets/faq.png', iconSize, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EmployeeFaq(),
                            settings: const RouteSettings(name: 'EmployeeFAQ'),
                            ));
                  },isActive: widget.currentScreen == 'EmployeeFAQ',
                  ),
                  buildNavItem('Log out', 'assets/logout.png', iconSize, () {
                    // Navigator.push(context,
                    //     MaterialPageRoute(builder: (context) => const Login()));
                    _handleLogout();
                  }),
                  const Divider(color: Colors.white24, thickness: 1),
                ],
              ),
            ),

            // Bottom Logo
            Padding(
              padding: EdgeInsets.symmetric(vertical: paddingUnit * 1.5),
              child: Image.asset(
                'assets/logo.png',
                height: logoSize,
                width: logoSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavItem(
      String title, String iconPath, double iconSize, VoidCallback? onTap,
      {bool isActive = false}) {
    final textStyle = AppTextStyle.sidenavtext.copyWith(
      fontSize: MediaQuery.of(context).size.width * 0.03,
      color: isActive ? Colors.grey : Colors.white, // gray if current
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          Image.asset(iconPath,
              height: iconSize, color: isActive ? Colors.grey : Colors.white),
          const SizedBox(width: 10),
          Text(title, style: textStyle),
        ],
      ),
      onTap: isActive ? null : onTap,
    );
  }
}
