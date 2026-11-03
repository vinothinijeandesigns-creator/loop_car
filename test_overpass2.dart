import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  String query = '''
    [out:json];
    node(around:5000, 10.3833, 78.8167)["place"~"city|town|village|suburb"];
    out tags center;
  ''';

  print("Running single point query...");
  final res1 = await http.post(
    Uri.parse('https://overpass-api.de/api/interpreter'),
    body: {'data': query}
  );
  if (res1.statusCode != 200) {
     print(res1.body);
  } else {
     print("Success! found ${jsonDecode(res1.body)['elements'].length}");
  }

  String query2 = '''
    [out:json];
    node(around:5000, 10.3833, 78.8167, 10.5333, 79.0167)["place"~"city|town|village|suburb"];
    out tags center;
  ''';

  print("Running polyline query...");
  final res2 = await http.post(
    Uri.parse('https://overpass-api.de/api/interpreter'),
    body: {'data': query2}
  );
  if (res2.statusCode != 200) {
     print("Failed with status ${res2.statusCode}");
     print(res2.body);
  } else {
     print("Success! found ${jsonDecode(res2.body)['elements'].length}");
  }
}
