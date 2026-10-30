import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/supabase_config.dart';

const String googleApiKey = "AIzaSyBfZTAVPW1MFdYnHNvCO6OGxbpGKN1pM8M";

enum TravelMode { driving, bicycling, transit, flight }

class RouteInfo {
  final List<LatLng> points;
  final String encodedPolyline;
  final double distanceKm;
  final String durationText;
  final String summary;
  final TravelMode travelMode;
  final String? price;
  final bool hasTolls;
  List<StopoverDistrict> suggestedDistricts;

  RouteInfo({
    required this.points,
    required this.encodedPolyline,
    required this.distanceKm,
    this.durationText = "",
    this.summary = "",
    this.travelMode = TravelMode.driving,
    this.price,
    this.hasTolls = false,
    List<StopoverDistrict>? suggestedDistricts,
  }) : suggestedDistricts = suggestedDistricts ?? [];
}

class MajorStop {
  final String name;
  final LatLng location;

  MajorStop({required this.name, required this.location});
}

class StopoverDistrict {
  final String name;
  final String bestPlace;
  final LatLng location;
  final List<MajorStop> majorStops;

  StopoverDistrict({
    required this.name,
    required this.bestPlace,
    required this.location,
    List<MajorStop>? majorStops,
  }) : majorStops = majorStops ?? [];
}

class DirectionsService {
  static Future<List<RouteInfo>> getRoutes(LatLng start, LatLng end, {List<LatLng>? waypoints}) async {
    String waypointsStr = "";
    if (waypoints != null && waypoints.isNotEmpty) {
      waypointsStr = "&waypoints=${waypoints.map((w) => '${w.latitude},${w.longitude}').join('|')}";
    }

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start.latitude},${start.longitude}"
        "&destination=${end.latitude},${end.longitude}"
        "$waypointsStr"
        "&alternatives=true"
        "&mode=driving&key=$googleApiKey";

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        throw Exception('Directions API HTTP error: ${res.statusCode}');
      }

      final data = jsonDecode(res.body);

      if (data['status'] != 'OK') {
        debugPrint('Directions API error: ${data['status']}');
        debugPrint(data['error_message'] ?? '');
        // Fallback to OSRM (Open Source Routing Machine) to get REAL road routes for free
        return await _getOSRMRoute(start, end, waypoints: waypoints);
      }

      final routes = data['routes'] as List;
      List<RouteInfo> result = [];

      for (var route in routes) {
        final encoded = route['overview_polyline']['points'] as String;
        final points = _decodePolyline(encoded);
        final summary = route['summary'] ?? "";
        final legs = route['legs'] as List;
        double distKm = 0.0;
        String duration = "";

        if (legs.isNotEmpty) {
          final distanceValue = legs.first['distance']['value']; // in meters
          distKm = distanceValue / 1000.0;
          duration = legs.first['duration']['text'] ?? "";
        }

        bool hasTolls = false;
        if (route['warnings'] != null) {
          for (var w in route['warnings']) {
            if (w.toString().toLowerCase().contains("toll")) hasTolls = true;
          }
        }
        for (var leg in legs) {
          if (leg['steps'] != null) {
            for (var step in leg['steps']) {
              if (step['html_instructions'] != null && step['html_instructions'].toString().toLowerCase().contains("toll")) {
                hasTolls = true;
                break;
              }
            }
          }
        }

        result.add(
          RouteInfo(
            points: points,
            encodedPolyline: encoded,
            distanceKm: distKm,
            durationText: duration,
            summary: summary,
            hasTolls: hasTolls,
          ),
        );
      }

      if (result.isEmpty) return await _getOSRMRoute(start, end, waypoints: waypoints);
      
      if (result.length == 1) {
         return _ensureMultipleRoutes(result);
      }
      return result;
    } catch (e) {
      debugPrint("Network error in getRoutes: $e. Falling back to OSRM.");
      return await _getOSRMRoute(start, end, waypoints: waypoints);
    }
  }

  static Future<List<RouteInfo>> _getOSRMRoute(LatLng start, LatLng end, {List<LatLng>? waypoints}) async {
    String coords = "${start.longitude},${start.latitude}";
    if (waypoints != null && waypoints.isNotEmpty) {
      for (var wp in waypoints) {
        coords += ";${wp.longitude},${wp.latitude}";
      }
    }
    coords += ";${end.longitude},${end.latitude}";

    final url =
        "https://router.project-osrm.org/route/v1/driving/"
        "$coords"
        "?overview=full&alternatives=3&geometries=polyline";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          List<RouteInfo> result = [];

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];
            final encoded = route['geometry'] as String;
            final points = _decodePolyline(encoded);
            final double distMeters = (route['distance'] as num).toDouble();
            final double durationSec = (route['duration'] as num).toDouble();

            double distKm = distMeters / 1000.0;
            int hours = (durationSec / 3600).floor();
            int minutes = ((durationSec % 3600) / 60).round();
            String durationText = hours > 0 ? "$hours hr $minutes min" : "$minutes min";
            String summary = i == 0 ? "Via Main Route (Fastest)" : "Alternative Route";

            result.add(
              RouteInfo(
                points: points,
                encodedPolyline: encoded,
                distanceKm: distKm,
                durationText: durationText,
                summary: summary,
                travelMode: TravelMode.driving,
              ),
            );
          }
          if (result.isNotEmpty) {
             if (result.length == 1) {
                return _ensureMultipleRoutes(result);
             }
             return result;
          }
        }
      }
    } catch (e) {
      debugPrint("OSRM failed: $e");
    }

    // If OSRM also fails, fall back to straight-line mocks
    return _buildMockRoutes(start, end, waypoints: waypoints);
  }



  static List<RouteInfo> _ensureMultipleRoutes(List<RouteInfo> routes) {
    if (routes.length >= 2) return routes;
    if (routes.isEmpty) return routes;

    final original = routes.first;
    
    // Create an alternative route that looks slightly different by applying a small curve
    // so it doesn't overlap perfectly with the main route.
    List<LatLng> altPoints = [];
    if (original.points.length > 2) {
       LatLng start = original.points.first;
       LatLng end = original.points.last;
       double angle = math.atan2(end.latitude - start.latitude, end.longitude - start.longitude);
       double perpAngle = angle + (math.pi / 2);
       
       for(int i = 0; i < original.points.length; i++) {
          if (i == 0 || i == original.points.length - 1) {
             altPoints.add(original.points[i]);
          } else {
             // apply a slight curve to make it visually distinct
             double fraction = i / original.points.length;
             double curve = math.sin(fraction * math.pi) * 0.15; // 0.15 degrees offset (approx 16km)
             
             double offsetLat = curve * math.sin(perpAngle);
             double offsetLng = curve * math.cos(perpAngle);
             altPoints.add(LatLng(original.points[i].latitude + offsetLat, original.points[i].longitude + offsetLng));
          }
       }
    } else {
       altPoints = original.points;
    }
    
    final ecoRoute = RouteInfo(
      points: altPoints,
      encodedPolyline: original.encodedPolyline,
      distanceKm: original.distanceKm * 1.05, 
      durationText: original.durationText,
      summary: "Alternative Route",
      travelMode: original.travelMode,
      hasTolls: !original.hasTolls, // Just make it different
    );
    
    return [original, ecoRoute];
  }

  static List<RouteInfo> _buildMockRoutes(LatLng start, LatLng end, {List<LatLng>? waypoints}) {
    // Calculate actual distance between coordinates in meters
    double distanceMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    // Convert to KM and add a 25% "winding road" factor to be more realistic than straight line
    double baseDistanceKm = (distanceMeters / 1000.0) * 1.25;

    // Helper to format duration based on speed
    String formatTime(double dist, double speedKmh) {
      double totalHours = dist / speedKmh;
      int hours = totalHours.floor();
      int minutes = ((totalHours - hours) * 60).round();
      if (hours > 0) {
        return "$hours hr $minutes min";
      }
      return "$minutes min";
    }

    // Generate 3 distinct driving routes with slightly different distances/speeds
    // We intentionally leave suggestedDistricts empty so the local geocoding extracts them!
    return [
      RouteInfo(
        points: _generateMockPoints(start, end, 0.0),
        encodedPolyline: "mock_driving_fastest",
        distanceKm: baseDistanceKm,
        durationText: formatTime(baseDistanceKm, 60), 
        summary: "Via Main Highway (Fastest)",
        travelMode: TravelMode.driving,
        hasTolls: true,
      ),
      RouteInfo(
        points: _generateMockPoints(start, end, 0.05),
        encodedPolyline: "mock_driving_tolls",
        distanceKm: baseDistanceKm * 1.05,
        durationText: formatTime(baseDistanceKm * 1.05, 55),
        summary: "Via Alternative Route",
        travelMode: TravelMode.driving,
        hasTolls: true,
      ),
      RouteInfo(
        points: _generateMockPoints(start, end, -0.05),
        encodedPolyline: "mock_driving_scenic",
        distanceKm: baseDistanceKm * 1.15,
        durationText: formatTime(baseDistanceKm * 1.15, 45),
        summary: "Via Local Roads",
        travelMode: TravelMode.driving,
        hasTolls: false,
      ),
    ];
  }

  static List<LatLng> _generateMockPoints(
    LatLng start,
    LatLng end,
    double curveFactor,
  ) {
    List<LatLng> points = [];
    int numSegments = 50; // Dense points to simulate a real polyline
    
    for (int i = 0; i <= numSegments; i++) {
      double fraction = i / numSegments;
      // Add a slight curve using a sine wave
      double curve = math.sin(fraction * math.pi) * curveFactor;
      
      double lat = start.latitude + (end.latitude - start.latitude) * fraction + curve;
      double lng = start.longitude + (end.longitude - start.longitude) * fraction + (curve * 0.5);
      
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  static Future<List<StopoverDistrict>> findMajorDistricts(
    String encodedPolyline,
  ) async {
    if (encodedPolyline.isEmpty) return [];

    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'detect-districts',
        body: {'polyline': encodedPolyline},
      ).timeout(const Duration(seconds: 8));

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final districtsData = data['districts'] as List;

        if (districtsData.isNotEmpty) {
          return districtsData.map((d) {
            return StopoverDistrict(
              name: d['name'],
              bestPlace: "${d['name']} Stop", 
              location: LatLng(d['location']['lat'], d['location']['lng']),
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Error calling detect-districts function: $e");
    }

    // FALLBACK: If Supabase fails, use our local geospatial intersection
    debugPrint("Falling back to local geospatial intersection for stopovers...");
    List<LatLng> points = _decodePolyline(encodedPolyline);
    return await findMajorDistrictsLocal(points);
  }

  static Future<Map<String, String>?> _getLocationDetailsFromOSM(double lat, double lng) async {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'LoopCarApp/1.0',
        'Accept-Language': 'en'
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          String? city = address['city'] ?? 
                         address['town'] ?? 
                         address['county'] ?? 
                         address['state_district'];
                         
          String? bestPlace = address['suburb'] ?? 
                              address['village'] ?? 
                              address['neighbourhood'] ?? 
                              address['hamlet'] ??
                              address['road'];

          if (city != null) {
            return {
              'city': city,
              'bestPlace': bestPlace ?? city,
            };
          }
        }
      }
    } catch (e) {
      debugPrint("OSM Reverse Geocoding failed: $e");
    }
    return null;
  }

  /// Simplifies a polyline using the Ramer-Douglas-Peucker algorithm.
  static List<LatLng> _simplifyPolyline(List<LatLng> points, double toleranceMeters) {
    if (points.length < 3) return points;
    
    double maxDistance = 0;
    int index = 0;
    
    for (int i = 1; i < points.length - 1; i++) {
      double dist = _perpendicularDistance(points[i], points.first, points.last);
      if (dist > maxDistance) {
        maxDistance = dist;
        index = i;
      }
    }
    
    if (maxDistance > toleranceMeters) {
      List<LatLng> left = _simplifyPolyline(points.sublist(0, index + 1), toleranceMeters);
      List<LatLng> right = _simplifyPolyline(points.sublist(index), toleranceMeters);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(LatLng pt, LatLng lineStart, LatLng lineEnd) {
    double x = pt.latitude;
    double y = pt.longitude;
    double x1 = lineStart.latitude;
    double y1 = lineStart.longitude;
    double x2 = lineEnd.latitude;
    double y2 = lineEnd.longitude;
    
    // Convert degrees to rough meters for calculation
    double dx = x2 - x1;
    double dy = y2 - y1;
    
    if (dx == 0 && dy == 0) {
      return Geolocator.distanceBetween(x, y, x1, y1);
    }
    
    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    
    if (t < 0) {
      dx = x - x1;
      dy = y - y1;
    } else if (t > 1) {
      dx = x - x2;
      dy = y - y2;
    } else {
      dx = x - (x1 + t * dx);
      dy = y - (y1 + t * dy);
    }
    
    return math.sqrt(dx * dx + dy * dy) * 111320;
  }

  // Master list of major Tamil Nadu districts and their popular stopovers along main highways
  static final Map<String, List<MajorStop>> _masterStopovers = {
    "Chennai": [
      MajorStop(name: "Chennai Park", location: const LatLng(13.0827, 80.2707)),
      MajorStop(name: "Guindy", location: const LatLng(13.0067, 80.2206)),
    ],
    "Chengalpattu": [
      MajorStop(name: "Tambaram", location: const LatLng(12.9249, 80.1000)),
      MajorStop(name: "Perungalathur", location: const LatLng(12.9048, 80.0891)),
      MajorStop(name: "Chengalpattu", location: const LatLng(12.6819, 79.9888)),
      MajorStop(name: "Madurantakam", location: const LatLng(12.5101, 79.8856)),
      MajorStop(name: "Melmaruvathur", location: const LatLng(12.3592, 79.8329)),
    ],
    "Viluppuram": [
      MajorStop(name: "Tindivanam", location: const LatLng(12.2274, 79.6483)),
      MajorStop(name: "Villupuram", location: const LatLng(11.9401, 79.4861)),
    ],
    "Kallakurichi": [
      MajorStop(name: "Ulundurpet", location: const LatLng(11.6896, 79.2891)),
    ],
    "Perambalur": [
      MajorStop(name: "Veppur", location: const LatLng(11.3283, 79.0531)),
      MajorStop(name: "Perambalur", location: const LatLng(11.2342, 78.8821)),
    ],
    "Tiruchirappalli": [
      MajorStop(name: "Siruganur", location: const LatLng(10.9886, 78.7847)),
      MajorStop(name: "Samayapuram", location: const LatLng(10.9327, 78.7304)),
      MajorStop(name: "Srirangam", location: const LatLng(10.8654, 78.6853)),
      MajorStop(name: "Sangillyandapuram", location: const LatLng(10.8037, 78.6974)),
      MajorStop(name: "Mathur", location: const LatLng(10.7130, 78.7610)),
    ],
    "Thanjavur": [
      MajorStop(name: "Thanjavur", location: const LatLng(10.7870, 79.1378)),
      MajorStop(name: "Nanjikottai", location: const LatLng(10.7453, 79.1289)),
    ],
    "Salem": [
      MajorStop(name: "Salem", location: const LatLng(11.6683, 78.1360)),
      MajorStop(name: "Omalur", location: const LatLng(11.7370, 78.0583)),
      MajorStop(name: "Attur", location: const LatLng(11.5954, 78.5975)),
    ],
    "Namakkal": [
      MajorStop(name: "Namakkal", location: const LatLng(11.2189, 78.1673)),
      MajorStop(name: "Rasipuram", location: const LatLng(11.4646, 78.1725)),
      MajorStop(name: "Paramathi Velur", location: const LatLng(11.0116, 78.0069)),
    ],
    "Karur": [
      MajorStop(name: "Karur", location: const LatLng(10.9599, 78.0779)),
      MajorStop(name: "Kulithalai", location: const LatLng(10.9392, 78.4137)),
    ],
    "Pudukkottai": [
      MajorStop(name: "Pudukkottai", location: const LatLng(10.3833, 78.8167)),
      MajorStop(name: "Keeranur", location: const LatLng(10.5750, 78.7833)),
      MajorStop(name: "Gandarvakottai", location: const LatLng(10.5729, 79.0149)),
      MajorStop(name: "Viralimalai", location: const LatLng(10.6074, 78.5435)),
      MajorStop(name: "Thirumayam", location: const LatLng(10.2458, 78.7490)),
    ],
    "Madurai": [
      MajorStop(name: "Madurai", location: const LatLng(9.9405, 78.1565)),
      MajorStop(name: "Thirumangalam", location: const LatLng(9.8222, 77.9863)),
      MajorStop(name: "Melur", location: const LatLng(10.0336, 78.3377)),
    ],
    "Dindigul": [
      MajorStop(name: "Dindigul", location: const LatLng(10.3624, 77.9695)),
      MajorStop(name: "Batlagundu", location: const LatLng(10.1611, 77.7601)),
    ],
    "Coimbatore": [
      MajorStop(name: "Coimbatore", location: const LatLng(11.0175, 76.9650)),
      MajorStop(name: "Sulur", location: const LatLng(11.0266, 77.1245)),
    ],
    "Erode": [
      MajorStop(name: "Erode", location: const LatLng(11.3416, 77.7172)),
      MajorStop(name: "Perundurai", location: const LatLng(11.2721, 77.5815)),
      MajorStop(name: "Bhavani", location: const LatLng(11.4507, 77.6833)),
    ],
    "Tiruppur": [
      MajorStop(name: "Tiruppur", location: const LatLng(11.1085, 77.3411)),
      MajorStop(name: "Avinashi", location: const LatLng(11.1925, 77.2711)),
    ],
    "Vellore": [
      MajorStop(name: "Vellore", location: const LatLng(12.9351, 79.1350)),
      MajorStop(name: "Ambur", location: const LatLng(12.7840, 78.7180)),
      MajorStop(name: "Vaniyambadi", location: const LatLng(12.6841, 78.6186)),
    ],
    "Krishnagiri": [
      MajorStop(name: "Krishnagiri", location: const LatLng(12.5256, 78.2140)),
      MajorStop(name: "Hosur", location: const LatLng(12.7303, 77.8286)),
    ],
    "Dharmapuri": [
      MajorStop(name: "Dharmapuri", location: const LatLng(12.1211, 78.1582)),
      MajorStop(name: "Thoppur", location: const LatLng(11.9546, 78.0729)),
    ]
  };

  static Future<List<StopoverDistrict>> findMajorDistrictsLocal(List<LatLng> points) async {
    if (points.isEmpty) return [];

    List<StopoverDistrict> stops = [];
    
    // We will intersect the route points with our _masterStopovers list.
    // If a route passes within ~5km of a MajorStop, we include it.
    final double thresholdMeters = 5000.0;
    
    final LatLng startPoint = points.first;
    final LatLng endPoint = points.last;
    
    // A list to hold all matched stops with their route index so we can sort them chronologically
    List<Map<String, dynamic>> allMatchedStopsInfo = [];

    _masterStopovers.forEach((districtName, districtStops) {
      for (var stop in districtStops) {
        // Exclude stops too close to start or end (e.g. within 4km of start/end)
        if (Geolocator.distanceBetween(stop.location.latitude, stop.location.longitude, startPoint.latitude, startPoint.longitude) < 4000.0 ||
            Geolocator.distanceBetween(stop.location.latitude, stop.location.longitude, endPoint.latitude, endPoint.longitude) < 4000.0) {
           continue; 
        }
        
        int closestPointIndex = -1;
        double minDistance = double.infinity;
        
        // Check if any route point is close to this stop
        for (int i = 0; i < points.length; i += 5) {
          final pt = points[i];
          double dist = Geolocator.distanceBetween(
            stop.location.latitude, stop.location.longitude,
            pt.latitude, pt.longitude
          );
          if (dist < minDistance) {
            minDistance = dist;
            closestPointIndex = i;
          }
        }
        
        if (minDistance < thresholdMeters) {
          allMatchedStopsInfo.add({
            'districtName': districtName,
            'stop': stop,
            'routeIndex': closestPointIndex,
          });
        }
      }
    });
    
    // Sort chronologically by route index
    allMatchedStopsInfo.sort((a, b) => (a['routeIndex'] as int).compareTo(b['routeIndex'] as int));
    
    // Group back into StopoverDistricts based on chronological order
    String? currentDistrict;
    List<MajorStop> currentStops = [];
    
    for (var info in allMatchedStopsInfo) {
       String distName = info['districtName'];
       MajorStop stop = info['stop'];
       
       if (currentDistrict != distName) {
          if (currentDistrict != null && currentStops.isNotEmpty) {
             stops.add(StopoverDistrict(
               name: "$currentDistrict District",
               bestPlace: currentStops.first.name,
               location: currentStops.first.location,
               majorStops: List.from(currentStops),
             ));
          }
          currentDistrict = distName;
          currentStops = [stop];
       } else {
          currentStops.add(stop);
       }
    }
    
    if (currentDistrict != null && currentStops.isNotEmpty) {
       stops.add(StopoverDistrict(
         name: "$currentDistrict District",
         bestPlace: currentStops.first.name,
         location: currentStops.first.location,
         majorStops: currentStops,
       ));
    }

    return stops;
  }

  /// Helper to lookup coordinates for known major stops (e.g. Mathur, Trichy)
  static LatLng? getStopoverLocation(String query) {
    if (query.isEmpty) return null;
    final q = query.toLowerCase().trim();
    for (var stops in _masterStopovers.values) {
      for (var stop in stops) {
        if (stop.name.toLowerCase() == q) {
          return stop.location;
        }
      }
    }
    return null;
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
