import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shiftsmart/models/Site.dart';
import 'package:shiftsmart/services/LocationService.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class EmployeeTrackingScreen extends StatefulWidget {
  final Site currentSite;
  final int employeeId;

  const EmployeeTrackingScreen({
    super.key,
    required this.currentSite,
    required this.employeeId,
  });

  @override
  State<EmployeeTrackingScreen> createState() => _EmployeeTrackingScreenState();
}

class _EmployeeTrackingScreenState extends State<EmployeeTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = RealLocationService();

  // Stream to listen to location updates
  StreamSubscription<Position>? _positionStream;

  // Markers & Circles
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // State
  bool _isInside = false;
  CameraPosition? _initialPosition;
  Position? _currentPosition;
  bool _isLoading = true;

  // Dark Map Style (Defined locally so it doesn't affect other files)
  final String _mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#746855"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#38414e"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [{"color": "#212a37"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#17263c"}]
      }
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _setupGeofence();
    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // 1. Draw the Site Geofence (Circle)
  void _setupGeofence() {
    final double lat = double.tryParse(widget.currentSite.latitude ?? '0') ?? 0;
    final double lng =
        double.tryParse(widget.currentSite.longitude ?? '0') ?? 0;
    final double radius = (widget.currentSite.radius ?? 150).toDouble();

    setState(() {
      _initialPosition = CameraPosition(
        target: LatLng(lat, lng),
        zoom: 16,
      );

      _circles.add(
        Circle(
          circleId: const CircleId('site_geofence'),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: Colors.blue
              .withOpacity(0.15), // Slightly transparent for dark map
          strokeColor: Colors.blueAccent,
          strokeWidth: 2,
        ),
      );

      // Add marker for the Site Center
      _markers.add(
        Marker(
          markerId: const MarkerId('site_center'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: widget.currentSite.siteName),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  // 2. Start Live Tracking
  void _startTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    try {
      Position initialPos = await Geolocator.getCurrentPosition();
      _updateMyLocation(initialPos);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error getting initial location: $e");
    }

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _updateMyLocation(position);
      _locationService.sendLocation(position, widget.employeeId);
    });
  }

  // 3. Update UI Marker
  void _updateMyLocation(Position position) async {
    final double siteLat =
        double.tryParse(widget.currentSite.latitude ?? '0') ?? 0;
    final double siteLng =
        double.tryParse(widget.currentSite.longitude ?? '0') ?? 0;
    final double radius = (widget.currentSite.radius ?? 150).toDouble();

    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      siteLat,
      siteLng,
    );

    bool isInside = distance <= radius;

    if (mounted) {
      setState(() {
        _isInside = isInside;
        _currentPosition = position;

        _markers.removeWhere((m) => m.markerId.value == 'me');
        _markers.add(
          Marker(
            markerId: const MarkerId('me'),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                isInside ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: "You",
              snippet: isInside ? "Inside Site" : "Outside Site",
            ),
          ),
        );
      });
    }
  }

  Future<void> _recenterMap() async {
    if (_currentPosition != null) {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 17),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialPosition == null || _isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1C2230),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      extendBodyBehindAppBar: true, // Allows map to fill screen behind navbar

      // 1. Hide the standard back button in Uppernavbar so we can add our own
      appBar: const Uppernavbar(showBackButton: false),

      body: Stack(
        children: [
          // 2. Map Layer
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition!,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_mapStyle); // Apply dark style locally
            },
            // Add padding so Google logo isn't hidden by bottom card
            padding: const EdgeInsets.only(bottom: 100, top: 80),
          ),

          // 3. CUSTOM BACK BUTTON (The Fix)
          // We manually place this over the map so it's always visible
          Positioned(
            top: 50, // Adjusts to align with AppBar height
            left: 15,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2230)
                        .withOpacity(0.85), // Dark bubble background
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
                    color: Colors.white, // High contrast white arrow
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // 4. Recenter Button
          Positioned(
            bottom: 140,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              onPressed: _recenterMap,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // 5. Stylish Status Card at the Bottom
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Dynamic gradient background based on status
                gradient: LinearGradient(
                  colors: _isInside
                      ? [
                          Colors.green.shade900.withOpacity(0.95),
                          Colors.green.shade800.withOpacity(0.9)
                        ]
                      : [
                          const Color(0xFF2C1F1F).withOpacity(0.95),
                          Colors.red.shade900.withOpacity(0.9)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
                border: Border.all(
                  color: _isInside
                      ? Colors.greenAccent.withOpacity(0.5)
                      : Colors.redAccent.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isInside
                          ? Icons.verified_user
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isInside ? "You are On Site" : "You are Off Site",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isInside
                              ? "Ready to clock in/out"
                              : "Please move inside the site zone",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13),
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
}
