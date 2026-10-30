import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Generate 15 points
  double startLat = 10.3833;
  double startLng = 78.8167;
  double endLat = 10.7833;
  double endLng = 79.1333;
  
  List<String> points = [];
  for (int i = 0; i < 15; i++) {
    double fraction = i / 14;
    double lat = startLat + (endLat - startLat) * fraction;
    double lng = startLng + (endLng - startLng) * fraction;
    points.add("$lat,$lng");
  }
  String coordsString = points.join(',');
  
  String query = '''
    [out:json][timeout:25];
    (
      nwr["place"~"city|town|village|suburb"](around:4000, $coordsString);
    );
    out tags center;
  ''';

  print("Running optimized nwr query with 15 points, wait up to 25s...");
  final stopwatch = Stopwatch()..start();
  
  try {
    final res = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 25)); // High timeout
    
    stopwatch.stop();
    print("Time: ${stopwatch.elapsedMilliseconds} ms");
    
    if (res.statusCode != 200) {
       print("Failed: ${res.statusCode}");
       print(res.body);
    } else {
       print("NWR returned ${jsonDecode(res.body)['elements'].length} elements");
    }
  } catch (e) {
    stopwatch.stop();
    print("Error: $e. Time: ${stopwatch.elapsedMilliseconds} ms");
  }
}
