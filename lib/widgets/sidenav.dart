// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/screens/chats/chatlist.dart';
// import 'package:shiftsmart/screens/login.dart';
// import 'package:shiftsmart/screens/manager/ManagerEmployeeReports.dart';
// import 'package:shiftsmart/screens/manager/managerLocationTracking.dart';
// import 'package:shiftsmart/screens/manager/managerProfile.dart';
// import 'package:shiftsmart/screens/manager/managerSettings.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/buildProfileAvatar.dart';

// class AppTextStyle {
//   static const sidenavtext = TextStyle(
//     color: Colors.white,
//     fontSize: 14,
//     fontWeight: FontWeight.w500,
//   );
// }

// class Sidenav extends StatefulWidget {
//   final String? currentScreen;
//   const Sidenav({super.key, this.currentScreen});

//   @override
//   State<Sidenav> createState() => _SidenavState();
// }

// class _SidenavState extends State<Sidenav> {
//   final AuthService _authService = AuthService();

//   late final userProfile;

//   @override
//   void initState() {
//     super.initState();
//     userProfile = Provider.of<UserProvider>(context, listen: false).userProfile;
//   }

//   void _handleLogout() async {
//     final prefs = await SharedPreferences.getInstance();
//     int? employeeId = prefs.getInt('employeeId');

//     bool success = await _authService.logout(employeeId);
//     print("Attempting logout for userId: $employeeId");

//     if (success) {
//       await prefs.clear();
//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const Login()),
//       );
//     } else {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Logout failed. Please try again.")),
//       );
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchSites() async {
//     final response = await http.get(Uri.parse(
//         "https://shiftsmart-dev-org-func.azurewebsites.net/api/site/all?code=<configure-from-env>"));

//     if (response.statusCode == 200) {
//       List<dynamic> data = jsonDecode(response.body);
//       return data.cast<Map<String, dynamic>>();
//     } else {
//       throw Exception("Failed to load sites");
//     }
//   }

//   void _showSitePicker(BuildContext context) async {
//     List<Map<String, dynamic>> sites = await fetchSites();

//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Color(0xFF2A3243),
//                 Color(0xFF222834),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.all(Radius.circular(20)),
//           ),
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Select a Site",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               SizedBox(
//                 height: MediaQuery.of(context).size.height * 0.5,
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: sites.length,
//                   itemBuilder: (context, index) {
//                     var site = sites[index];
//                     return GestureDetector(
//                       onTap: () {
//                         Navigator.pop(context);
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => ManagerLocationTracking(
//                               siteId: site['SiteId'],
//                             ),
//                           ),
//                         );
//                       },
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(vertical: 6),
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 12),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(site['SiteName'],
//                                 style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.w600)),
//                             const SizedBox(height: 4),
//                             Text(site['Project']['Location'] ?? '',
//                                 style: const TextStyle(
//                                     color: Colors.white60, fontSize: 12)),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final userProvider = Provider.of<UserProvider>(context);
//     final userProfile = userProvider.userProfile;

//     if (userProfile.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     final size = MediaQuery.of(context).size;
//     final paddingUnit = size.width * 0.05;
//     final iconSize = size.width * 0.06;
//     final logoSize = size.width * 0.4;

//     return Drawer(
//       width: size.width * 0.5,
//       child: Container(
//         color: const Color(0xFF161622),
//         child: Column(
//           children: [
//             Padding(
//               padding:
//                   EdgeInsets.only(top: paddingUnit * 3, bottom: paddingUnit),
//               child: Column(
//                 children: [
//                   GestureDetector(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => ManagerProfile(),
//                         ),
//                       );
//                     },
//                     child: const ProfileAvatar(editable: false),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}'
//                             .trim()
//                             .isEmpty
//                         ? 'No Name'
//                         : '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     userProfile['jobRole'] ?? 'No Position',
//                     style: TextStyle(
//                       color: Colors.grey,
//                       fontSize: 12,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   const Divider(color: Colors.white24, thickness: 1),
//                 ],
//               ),
//             ),

//             // Navigation Items
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.zero,
//                 children: [
//                   buildNavItem('Home', 'assets/Home.png', iconSize, () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const Bottomnavbar(
//                           selectedIndex: 0,
//                         ),
//                       ),
//                     );
//                   }),
//                   buildNavItem('Settings', 'assets/settings.png', iconSize, () {
//                     Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const ManagerSettings(),
//                           settings:
//                               const RouteSettings(name: 'ManagerSettings'),
//                         ));
//                   }, isActive: widget.currentScreen == 'ManagerSettings'),
//                   buildNavItem(
//                     'Reports',
//                     'assets/Report.png',
//                     iconSize,
//                     () {
//                       Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) =>
//                                 const ManagerEmployeeReports(),
//                             settings:
//                                 const RouteSettings(name: 'ManagerReports'),
//                           ));
//                     },
//                     isActive: widget.currentScreen == 'ManagerReports',
//                   ),
//                   buildNavItem(
//                     'Chat',
//                     'assets/Chat.png',
//                     iconSize,
//                     () {
//                       Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const Chatlist(),
//                             settings: const RouteSettings(name: 'Chat'),
//                           ));
//                     },
//                     isActive: widget.currentScreen == 'Chat',
//                   ),
//                   buildNavItem(
//                       'Location Tracking', 'assets/Location.png', iconSize, () {
//                     _showSitePicker(context);
//                   }),
//                   buildNavItem('Log out', 'assets/logout.png', iconSize, () {
//                     // Navigator.pushReplacement(context,
//                     //     MaterialPageRoute(builder: (_) => const Login()));
//                     _handleLogout();
//                   }),
//                   const Divider(color: Colors.white24, thickness: 1),
//                 ],
//               ),
//             ),

//             // Bottom Logo
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 20),
//               child: Image.asset(
//                 'assets/logo.png',
//                 height: logoSize,
//                 width: logoSize,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildNavItem(
//       String title, String iconPath, double iconSize, VoidCallback? onTap,
//       {bool isActive = false}) {
//     final textStyle = AppTextStyle.sidenavtext.copyWith(
//       fontSize: MediaQuery.of(context).size.width * 0.03,
//       color: isActive ? Colors.grey : Colors.white, // gray if current
//     );

//     return ListTile(
//       contentPadding: const EdgeInsets.symmetric(horizontal: 20),
//       title: Row(
//         children: [
//           Image.asset(iconPath,
//               height: iconSize, color: isActive ? Colors.grey : Colors.white),
//           const SizedBox(width: 10),
//           Text(title, style: textStyle),
//         ],
//       ),
//       onTap: isActive ? null : onTap,
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/screens/chats/chatlist.dart';
import 'package:shiftsmart/screens/login.dart';
import 'package:shiftsmart/screens/manager/ManagerEmployeeReports.dart';
import 'package:shiftsmart/screens/manager/managerLocationTracking.dart';
import 'package:shiftsmart/screens/manager/managerProfile.dart';
import 'package:shiftsmart/screens/manager/managerSettings.dart';
import 'package:shiftsmart/services/SiteService.dart'; // Import SiteService
import 'package:shiftsmart/services/auth_service.dart';
import 'package:shiftsmart/widgets/bottomnavbar.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';

class AppTextStyle {
  static const sidenavtext = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}

class Sidenav extends StatefulWidget {
  final String? currentScreen;
  const Sidenav({super.key, this.currentScreen});

  @override
  State<Sidenav> createState() => _SidenavState();
}

class _SidenavState extends State<Sidenav> {
  final AuthService _authService = AuthService();
  // 1. Initialize SiteService
  final SiteService _siteService = SiteService();

  late final userProfile;

  @override
  void initState() {
    super.initState();
    userProfile = Provider.of<UserProvider>(context, listen: false).userProfile;
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

  // 2. Use Service instead of Hardcoded URL
  Future<List<Site>> _fetchSites() async {
    return await _siteService.fetchAllSites();
  }

  void _showSitePicker(BuildContext context) async {
    // Show loading dialog if needed, or handle async in builder
    try {
      List<Site> sites = await _fetchSites();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2A3243), Color(0xFF222834)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select a Site",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sites.length,
                    itemBuilder: (context, index) {
                      var site = sites[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ManagerLocationTracking(siteId: site.siteId),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(site.siteName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              // Handle optional project
                              if (site.project != null)
                                Text(site.project!.name,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print("Error loading sites: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Keep existing build method logic for layout)
    // Copy the `build` method from your original code, it was fine.
    // Just ensure `_showSitePicker(context)` is called in the Location Tracking item.
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
                              builder: (context) => ManagerProfile()));
                    },
                    child: const ProfileAvatar(editable: false),
                  ),
                  const SizedBox(height: 10),
                  Text(
                      '${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}'
                          .trim(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(userProfile['jobRole'] ?? 'No Position',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24, thickness: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  buildNavItem('Home', 'assets/Home.png', iconSize, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const Bottomnavbar(selectedIndex: 0)));
                  }),
                  buildNavItem('Settings', 'assets/settings.png', iconSize, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ManagerSettings()));
                  }, isActive: widget.currentScreen == 'ManagerSettings'),
                  buildNavItem('Reports', 'assets/Report.png', iconSize, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ManagerEmployeeReports()));
                  }, isActive: widget.currentScreen == 'ManagerReports'),
                  buildNavItem('Chat', 'assets/Chat.png', iconSize, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Chatlist()));
                  }, isActive: widget.currentScreen == 'Chat'),

                  // 👇 Updated Call
                  buildNavItem(
                      'Location Tracking', 'assets/Location.png', iconSize, () {
                    _showSitePicker(context);
                  }),

                  buildNavItem('Log out', 'assets/logout.png', iconSize, () {
                    _handleLogout();
                  }),
                  const Divider(color: Colors.white24, thickness: 1),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Image.asset('assets/logo.png',
                  height: logoSize, width: logoSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavItem(
      String title, String iconPath, double iconSize, VoidCallback? onTap,
      {bool isActive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          Image.asset(iconPath,
              height: iconSize, color: isActive ? Colors.grey : Colors.white),
          const SizedBox(width: 10),
          Text(title,
              style: AppTextStyle.sidenavtext.copyWith(
                  fontSize: MediaQuery.of(context).size.width * 0.03,
                  color: isActive ? Colors.grey : Colors.white)),
        ],
      ),
      onTap: isActive ? null : onTap,
    );
  }
}
