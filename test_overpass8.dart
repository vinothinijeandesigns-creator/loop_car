import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

void main() async {
  double startLat = 10.3833;
  double startLng = 78.8167;
  double endLat = 10.7833;
  double endLng = 79.1333;
  
  // Create a bounding box around the route with a 0.05 degree margin (~5km)
  double minLat = math.min(startLat, endLat) - 0.05;
  double maxLat = math.max(startLat, endLat) + 0.05;
  double minLng = math.min(startLng, endLng) - 0.05;
  double maxLng = math.max(startLng, endLng) + 0.05;
  
  String query = '''
    [out:json][timeout:5];
    (
      nwr["place"~"city|town|village|suburb"]($minLat, $minLng, $maxLat, $maxLng);
    );
    out tags center;
  ''';

  print("Running BBox nwr query...");
  final stopwatch = Stopwatch()..start();
  
  try {
    final res = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 5));
    
    stopwatch.stop();
    print("Time: ${stopwatch.elapsedMilliseconds} ms. Status: ${res.statusCode}");
    
    if (res.statusCode == 200) {
       var data = jsonDecode(res.body);
       print("BBox returned ${data['elements'].length} elements");
    } else {
       print(res.body);
    }
  } catch (e) {
    stopwatch.stop();
    print("Error: $e. Time: ${stopwatch.elapsedMilliseconds} ms");
  }
}
