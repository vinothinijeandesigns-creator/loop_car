import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  String coordsString = "10.3833,78.8167,10.7833,79.1333";
  String query = '''
    [out:json][timeout:10];
    (
      nwr["place"~"city|town"](around:10000, $coordsString);
    );
    out tags center;
  ''';
  try {
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      body: {'data': query},
    );
    print(response.statusCode);
    print(response.body);
  } catch (e) {
    print(e);
  }
}
