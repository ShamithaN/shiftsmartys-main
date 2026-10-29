import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:flutter/foundation.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/models/SiteEmployee.dart';
import 'package:shiftsmart/services/SiteService.dart';

class ManagerLocationTracking extends StatefulWidget {
  final int siteId;

  const ManagerLocationTracking({super.key, required this.siteId});

  @override
  State<ManagerLocationTracking> createState() =>
      _ManagerLocationTrackingState();
}

class _ManagerLocationTrackingState extends State<ManagerLocationTracking> {
  Site? currentSite;
  List<SiteEmployee> employees = [];
  bool isLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  LatLng? _mapCenter;
  final double _mapZoom = 15.0;
  List<SiteEmployee> filteredEmployees = [];
  final SiteService _siteService = SiteService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadSiteData();

    // Auto-refresh locations every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshEmployeeLocations();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSiteData() async {
    try {
      final site = await _fetchSiteDetails(widget.siteId);

      setState(() {
        currentSite = site;
        _mapCenter = LatLng(
          double.tryParse(site.latitude ?? '') ?? 0.0,
          double.tryParse(site.longitude ?? '') ?? 0.0,
        );
      });

      await _refreshEmployeeLocations();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _refreshEmployeeLocations() async {
    if (currentSite == null) return;

    try {
      final siteEmployees =
          await _siteService.fetchEmployeesInSite(widget.siteId, currentSite!);

      if (mounted) {
        setState(() {
          employees = siteEmployees;
          filteredEmployees = List.from(siteEmployees);
          isLoading = false;
          _createMarkers(currentSite!, siteEmployees);
        });
      }
    } catch (e) {
      debugPrint("Error refreshing locations: $e");
    }
  }

  void _createMarkers(Site site, List<SiteEmployee> employees) {
    final markers = <Marker>{};
    final lat = double.tryParse(site.latitude ?? '') ?? 0.0;
    final lng = double.tryParse(site.longitude ?? '') ?? 0.0;

    // 1. Site Marker
    markers.add(Marker(
      markerId: MarkerId('site_${site.siteId}'),
      position: LatLng(lat, lng),
      infoWindow:
          InfoWindow(title: site.siteName, snippet: "Radius: ${site.radius}m"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));

    // 2. Employee Markers
    for (final employee in employees) {
      if (employee.clockInLat != null && employee.clockInLng != null) {
        final double markerHue = employee.isInside
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed;

        markers.add(Marker(
          markerId: MarkerId('employee_${employee.employeeId}'),
          position: LatLng(employee.clockInLat!, employee.clockInLng!),
          infoWindow: InfoWindow(
            title: employee.name,
            snippet: employee.isInside
                ? 'Inside Fence'
                : 'Outside (${(employee.distance! * 1000).toStringAsFixed(0)}m away)',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        ));
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController.complete(controller);
    if (kIsWeb || !mounted) return;
    try {
      final darkMapStyle = await DefaultAssetBundle.of(context)
          .loadString('assets/map_styles/dark.json');
      controller.setMapStyle(darkMapStyle);
    } catch (e) {
      debugPrint('Error loading map style: $e');
    }
  }

  Future<Site> _fetchSiteDetails(int siteId) async {
    final site = await _siteService.fetchSiteById(siteId);
    if (site != null) {
      return site;
    } else {
      throw Exception('Site not found');
    }
  }

  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = List.from(employees);
      } else {
        filteredEmployees = employees
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidenav(),
      backgroundColor: const Color(0xFF1C2230),
      // 1. Extend body to allow content under the transparent navbar
      extendBodyBehindAppBar: true,
      // 2. Hide default back button (we add our own below)
      appBar: const Uppernavbar(showBackButton: false),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                // 3. Add spacing for the transparent AppBar
                const SizedBox(height: 70),
                Search(onQueryChanged: onQueryChanged),
                Expanded(
                  flex: 2,
                  child: _buildMapSection(),
                ),
                Expanded(
                  flex: 1,
                  child: _buildEmployeeListSection(),
                ),
              ],
            ),
          ),

          // 4. THE CUSTOM BACK BUTTON (Bubble Style)
          Positioned(
            top: 50, // Aligns with the AppBar area
            left: 15,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2230).withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mapCenter == null) {
      return const Center(
          child: Text("No location data available",
              style: TextStyle(color: Colors.white)));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _mapCenter!,
            zoom: _mapZoom,
          ),
          markers: _markers,
          mapType: MapType.normal,
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          circles: currentSite != null
              ? {
                  Circle(
                    circleId: CircleId('geofence_${currentSite!.siteId}'),
                    center: LatLng(
                      double.tryParse(currentSite!.latitude ?? '') ?? 0.0,
                      double.tryParse(currentSite!.longitude ?? '') ?? 0.0,
                    ),
                    radius: currentSite!.radius ?? 0.0,
                    strokeWidth: 2,
                    strokeColor: Colors.blueAccent.withOpacity(0.6),
                    fillColor: Colors.blue.withOpacity(0.15),
                  )
                }
              : {},
        ),
      ),
    );
  }

  Widget _buildEmployeeListSection() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Tracking',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${employees.length} Active',
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildEmployeeList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    filteredEmployees.sort((a, b) {
      if (a.isInside == b.isInside) return 0;
      return a.isInside ? 1 : -1; // Outside First
    });

    if (filteredEmployees.isEmpty) {
      return const Center(
        child: Text("No employees currently active",
            style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      itemCount: filteredEmployees.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final employee = filteredEmployees[index];
        return _buildEmployeeCard(employee);
      },
    );
  }

  Widget _buildEmployeeCard(SiteEmployee employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3243),
        borderRadius: BorderRadius.circular(15),
        border: employee.isInside
            ? null
            : Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade700,
              border: Border.all(color: Colors.white24),
              image: employee.profilePicture != null
                  ? DecorationImage(
                      image: NetworkImage(employee.profilePicture!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: employee.profilePicture == null
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      employee.isInside ? Icons.verified_user : Icons.warning,
                      color: employee.isInside
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      employee.isInside ? "Inside Fence" : "Outside Fence",
                      style: TextStyle(
                          color: employee.isInside
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (employee.distance != null)
                Text(
                  '${(employee.distance! * 1000).toStringAsFixed(0)}m',
                  style: TextStyle(
                      color:
                          employee.isInside ? Colors.white70 : Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              if (employee.clockInTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatClockInTime(employee.clockInTime!),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatClockInTime(String clockInTime) {
    try {
      final dateTime = DateTime.parse(clockInTime);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return clockInTime;
    }
  }
}
