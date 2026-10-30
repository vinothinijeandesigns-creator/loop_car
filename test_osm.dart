import 'dart:convert';
import 'package:http/http.dart' as http;

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

void main() async {
  List<LatLng> points = [
    LatLng(13.0827, 80.2707),
    LatLng(12.6819, 79.9888),
    LatLng(12.2393, 79.6469),
    LatLng(11.9401, 79.4861),
    LatLng(11.2330, 78.8576),
    LatLng(10.7905, 78.7047),
  ];

  String coords = points.map((p) => '${p.latitude},${p.longitude}').join(',');
  
  String query = '''
    [out:json][timeout:25];
    (
      node(around:5000, $coords)["place"~"city|town"];
    );
    out center;
  ''';

  print('Query:\\n$query');
  
  try {
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
      headers: {'User-Agent': 'LoopCarTest/1.0'}
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final elements = data['elements'] as List;
      
      print('Found \${elements.length} places.');
      for (var e in elements) {
        String name = e['tags']?['name'] ?? 'Unknown';
        String placeType = e['tags']?['place'] ?? 'unknown';
        print('- $name ($placeType)');
      }
    } else {
      print('Error: \${response.statusCode} - \${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
