import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

void main() async {
  double startLat = 10.3797;
  double startLng = 78.8208;
  double endLat = 10.7870;
  double endLng = 79.1378;
  
  double midLat = (startLat + endLat) / 2;
  double midLng = (startLng + endLng) / 2;
  
  double angle = math.atan2(endLat - startLat, endLng - startLng);
  double perpAngle = angle + math.pi / 2;
  
  double offset = 0.09; // ~10km
  double offsetLat = midLat + math.sin(perpAngle) * offset;
  double offsetLng = midLng + math.cos(perpAngle) * offset;
  
  print('Midpoint offset: $offsetLat, $offsetLng');
  
  final url =
    'https://router.project-osrm.org/route/v1/driving/'
    '$startLng,$startLat;$offsetLng,$offsetLat;$endLng,$endLat'
    '?overview=full&geometries=polyline';
    
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['code'] == 'Ok') {
        final routes = data['routes'] as List;
        final route = routes[0];
        print('Success! Alternative route distance: ${route['distance']} meters');
      }
    } else {
      print('Failed: ${res.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
