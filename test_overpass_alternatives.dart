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
  
  String query = '''
    [out:json][timeout:15];
    (
      nwr["place"~"city|town|village|suburb"](around:5000, $coordsString);
    );
    out tags center;
  ''';

  print("Running lz4.overpass-api.de...");
  final stopwatch1 = Stopwatch()..start();
  try {
    final res = await http.post(
      Uri.parse('https://lz4.overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 5));
    stopwatch1.stop();
    print("lz4 Time: ${stopwatch1.elapsedMilliseconds} ms. Status: ${res.statusCode}");
  } catch (e) { print("lz4 Error: $e"); }

  print("Running z.overpass-api.de...");
  final stopwatch2 = Stopwatch()..start();
  try {
    final res = await http.post(
      Uri.parse('https://z.overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 5));
    stopwatch2.stop();
    print("z Time: ${stopwatch2.elapsedMilliseconds} ms. Status: ${res.statusCode}");
  } catch (e) { print("z Error: $e"); }
  
  print("Running overpass.kumi.systems...");
  final stopwatch3 = Stopwatch()..start();
  try {
    final res = await http.post(
      Uri.parse('https://overpass.kumi.systems/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
    ).timeout(const Duration(seconds: 5));
    stopwatch3.stop();
    print("kumi Time: ${stopwatch3.elapsedMilliseconds} ms. Status: ${res.statusCode}");
  } catch (e) { print("kumi Error: $e"); }
}
