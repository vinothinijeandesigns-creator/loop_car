import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class StopoverDistrict {
  final String name;
  final String bestPlace;
  final LatLng location;
  StopoverDistrict({required this.name, required this.bestPlace, required this.location});
}

List<LatLng> _decodePolyline(String encoded) {
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

double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371e3; // metres
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final deltaPhi = (lat2 - lat1) * math.pi / 180;
  final deltaLambda = (lon2 - lon1) * math.pi / 180;

  final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
            math.cos(phi1) * math.cos(phi2) *
            math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c;
}

Future<String?> _getCityNameFromOSM(double lat, double lng) async {
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
                       address['municipality'] ??
                       address['village'] ??
                       address['hamlet'] ??
                       address['county'] ?? 
                       address['state_district'];
        return city;
      }
    }
  } catch (e) {
    print("OSM Reverse Geocoding failed: $e");
  }
  return null;
}

void main() async {
  double startLat = 12.2289;
  double startLng = 79.0664; // Tiruvannamalai
  double endLat = 9.9252;
  double endLng = 78.1198; // Madurai

  final url = "https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&alternatives=true&geometries=polyline";

  final res = await http.get(Uri.parse(url));
  print("OSRM Status: ${res.statusCode}");
  final data = jsonDecode(res.body);
  final routes = data['routes'] as List;
  final encoded = routes[0]['geometry'] as String;
  
  final points = _decodePolyline(encoded);
  print("Total decoded points: ${points.length}");

  List<StopoverDistrict> detectedDistricts = [];
  Set<String> seenCities = {};

  double totalDistance = 0.0;
  List<double> accumulatedDistances = [0.0];
  
  for (int i = 1; i < points.length; i++) {
    double dist = _haversineDistance(
      points[i - 1].latitude, points[i - 1].longitude,
      points[i].latitude, points[i].longitude,
    );
    totalDistance += dist;
    accumulatedDistances.add(totalDistance);
  }

  print("Total distance: $totalDistance meters");

  double interval = 35000.0;
  double nextTarget = interval;

  for (int i = 0; i < points.length; i++) {
    if (accumulatedDistances[i] >= nextTarget && accumulatedDistances[i] < totalDistance - 15000) {
      print("Hit target at index $i, distance: ${accumulatedDistances[i]}");
      nextTarget += interval;
      
      String? finalCityName = await _getCityNameFromOSM(points[i].latitude, points[i].longitude);
      
      if (finalCityName != null && finalCityName.isNotEmpty) {
        String cleanName = finalCityName.replaceAll(RegExp(r'(?i)\s+(district|taluk|city)$'), '').trim();
        if (!seenCities.contains(cleanName.toLowerCase())) {
          seenCities.add(cleanName.toLowerCase());
          detectedDistricts.add(
            StopoverDistrict(
              name: cleanName,
              bestPlace: cleanName,
              location: points[i],
            ),
          );
          print("Added district: $cleanName");
        } else {
           print("Skipped duplicate: $cleanName");
        }
      } else {
         print("OSM returned null for ${points[i].latitude}, ${points[i].longitude}");
      }
    }
  }
  
  print("Final detected: ${detectedDistricts.map((e) => e.name).toList()}");
}
