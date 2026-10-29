import 'package:flutter/material.dart';
import 'package:shiftsmart/screens/manager/managerEmployee.dart';
import 'package:shiftsmart/screens/manager/managerLeave.dart';
import 'package:shiftsmart/screens/manager/managerJobs.dart';
import 'package:shiftsmart/screens/manager/managerProjects.dart';
import 'package:shiftsmart/screens/manager/managerdashboard.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
 
class Bottomnavbar extends StatefulWidget {
  final int selectedIndex;

  const Bottomnavbar({required this.selectedIndex, super.key});

  @override
  State<Bottomnavbar> createState() => _BottomnavbarState();
}

class _BottomnavbarState extends State<Bottomnavbar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex; // Set the initial selected index from the constructor
  }

  final List<Widget> _pages = [
    const Managerdashboard(),
    const Managerprojects(),
    const Managerjobs(),
    const Manageremployee(),
    const Managerleave(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<String> icons = [
    'assets/Home.png',
    'assets/projects.png',
    'assets/shifts.png',
    'assets/employee.png',
    'assets/request.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      drawer: const Sidenav(),
      appBar: const Uppernavbar(),
      body: _pages[_selectedIndex],
      extendBody: true,
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background with clipped shape
          ClipPath(
            clipper: RightCornerClipper(),
            child: Container(
              height: 90,
              color: const Color.fromARGB(252, 60, 82, 170),
            ),
          ),

          // Floating icons + active background
          Positioned(
            bottom: 15,
            left: 1,
            right: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(icons.length, (index) {
                final bool isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Active background
                      if (isSelected)
                        Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..multiply(Matrix4.skewX(-0.4))
                            ..rotateZ(-15 * 3.1415927 / 180),
                          alignment: Alignment.center,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(255, 32, 34, 36)
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Icon (floats with active bg)
                      Image.asset(
                        icons[index],
                        width: isSelected ? 30 : 25,
                        height: isSelected ? 30 : 25,
                        color: isSelected ? Colors.white : Colors.grey[400],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class RightCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.4); // Slant up from top-left
    path.lineTo(size.width, 0);       // Top-right
    path.lineTo(size.width, size.height); // Bottom-right
    path.lineTo(0, size.height);      // Bottom-left
    path.close();
    return path;
  }
 
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
 