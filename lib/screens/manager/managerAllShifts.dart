import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/Shift.dart';
import 'package:shiftsmart/screens/manager/managerCreateShift.dart';
import 'package:shiftsmart/screens/manager/managerShiftsView.dart';
import 'package:shiftsmart/services/ShiftService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Managerallshifts extends StatefulWidget {
  const Managerallshifts({super.key});

  @override
  State<Managerallshifts> createState() => _ManagerallshiftsState();
}

class _ManagerallshiftsState extends State<Managerallshifts> {
  // State Variables
  bool _isLoading = true;
  List<Shift> allShifts = [];
  List<Shift> filteredShifts = [];

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadData();
  }

  // Fetch all shifts from backend
  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final shifts = await ShiftService().fetchAllShifts();
      if (mounted) {
        setState(() {
          allShifts = shifts;
          filteredShifts = List.from(allShifts);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data.')),
        );
      }
    }
  }

  // Filter list based on search query
  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredShifts = List.from(allShifts);
      } else {
        filteredShifts = allShifts.where((shift) {
          return shift.taskName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // Helper: Navigate to a screen and refresh list on return
  // Returns 'true' if data was modified
  Future<void> _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    // If result is true (meaning a shift was added/edited), refresh list
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Search(onQueryChanged: onQueryChanged),

                  // "Create Shift" Button Area
                  _createShift(),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "SHIFT LIST",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Shift List
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF724584)))
                        : _shiftList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for "Create Shift" Header
  Widget _createShift() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(180, 42, 50, 67),
            Color.fromARGB(180, 34, 40, 52)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Image.asset('assets/cShift.png', height: 30),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    "CREATE SHIFT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Add Button
          GestureDetector(
            onTap: () => _navigateAndRefresh(const Managercreateshift()),
            child: const Icon(Icons.add_box_outlined,
                color: Colors.blueAccent, size: 32),
          ),
        ],
      ),
    );
  }

  // Widget for the list of shifts
  Widget _shiftList() {
    if (filteredShifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/cShift.png', height: 30, color: Colors.grey),
            const SizedBox(height: 16),
            Text("No shifts found",
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        itemCount: filteredShifts.length,
        itemBuilder: (context, index) {
          final shift = filteredShifts[index];
          return _buildStyledJobCard(context, shift);
        },
      ),
    );
  }

  // Individual Shift Card
  Widget _buildStyledJobCard(BuildContext context, Shift shift) {
    String formattedStart = shift.startTime;
    String formattedEnd = shift.endTime;

    // Attempt to format time nicely (e.g., 14:00:00 -> 2:00 PM)
    try {
      final inputFormat = DateFormat("HH:mm:ss");
      final displayFormat = DateFormat.jm();
      if (shift.startTime.contains(":")) {
        formattedStart =
            displayFormat.format(inputFormat.parse(shift.startTime));
      }
      if (shift.endTime.contains(":")) {
        formattedEnd = displayFormat.format(inputFormat.parse(shift.endTime));
      }
    } catch (e) {
      // Keep original string if parse fails
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF363E51), Color(0xFF191E26)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.swap_horizontal_circle_sharp,
                color: Colors.grey[600], size: 24),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.taskName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text("Start: $formattedStart",
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text("End: $formattedEnd",
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),

          // Status & Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shift.status,
                style: TextStyle(
                    color: shift.status == "Active"
                        ? Colors.greenAccent
                        : const Color(0xFFEBCC46),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Edit Button
                  GestureDetector(
                    onTap: () =>
                        _navigateAndRefresh(Managercreateshift(shift: shift)),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // View Details Button
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ManagerShiftsView(shift: shift))),
                    child: const Icon(Icons.arrow_forward_ios_sharp,
                        color: Colors.blueAccent, size: 18),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
