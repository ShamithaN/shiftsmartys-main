import 'package:shiftsmart/models/Project.dart';

class Site {
  final int siteId;
  final String siteName;
  // We keep these as String? so the rest of your app doesn't break
  final String? latitude;
  final String? longitude;
  final String? geoFenceType;
  final String? geoCoordinates;
  final double? radius;
  final int? projectId;
  final Project? project;

  Site({
    required this.siteId,
    required this.siteName,
    this.latitude,
    this.longitude,
    this.geoFenceType,
    this.geoCoordinates,
    this.radius,
    this.projectId,
    this.project,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      siteId: json['SiteId'] ?? 0,
      siteName: json['SiteName'] ?? '',

      // --- THIS IS THE FIX ---
      // The server sends a number (double), but your app wants a String.
      // We convert the number to a String here.
      // The ?.toString() safely handles nulls.
      latitude: json['Latitude']?.toString(),
      longitude: json['Longitude']?.toString(),
      // --- END OF FIX ---

      geoFenceType: json['GeoFenceType'] ?? '',
      geoCoordinates: json['GeoCoordinates'] ?? '',
      // This logic was also made safer to prevent crashes
      radius: (json['Radius'] as num?)?.toDouble(),
      projectId: json['ProjectId'] ?? 0,
      project:
          json['Project'] != null ? Project.fromJson(json['Project']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "projectId": projectId,
      "siteName": siteName,
      // Your app already stores these as Strings, so this is correct
      "latitude": latitude,
      "longitude": longitude,
      "geoFenceType": geoFenceType,
      "geoCoordinates": geoCoordinates,
      "radius": radius,
    };
  }
}
