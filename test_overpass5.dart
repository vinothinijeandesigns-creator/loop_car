import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Generate 25 points between Pudukkottai and Thanjavur
  double startLat = 10.3833;
  double startLng = 78.8167;
  double endLat = 10.7833;
  double endLng = 79.1333;
  
  List<String> points = [];
  for (int i = 0; i < 25; i++) {
    double fraction = i / 24;
    double lat = startLat + (endLat - startLat) * fraction;
    double lng = startLng + (endLng - startLng) * fraction;
    points.add("$lat,$lng");
  }
  String coordsString = points.join(',');
  
  // Notice the tag filter is BEFORE the (around) filter
  String query = '''
    [out:json][timeout:15];
    (
      nwr["place"~"city|town|village|suburb"](around:5000, $coordsString);
    );
    out tags center;
  ''';

  print("Running optimized nwr query with 25 points...");
  final stopwatch = Stopwatch()..start();
  
  try {
    final res = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 10));
    
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
