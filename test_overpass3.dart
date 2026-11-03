import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  String coordsString = "10.3833,78.8167, 10.5333,79.0167, 10.7833,79.1333";
  
  String query = '''
    [out:json][timeout:15];
    (
      node(around:5000, $coordsString)["place"~"city|town|village|suburb"];
    );
    out tags center;
  ''';

  print("Running node query...");
  final res1 = await http.post(
    Uri.parse('https://overpass-api.de/api/interpreter'),
    body: {'data': query},
    headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
  );
  if (res1.statusCode != 200) {
     print(res1.body);
  } else {
     print("Node returned ${jsonDecode(res1.body)['elements'].length} elements");
  }

  String query2 = '''
    [out:json][timeout:15];
    (
      nwr(around:5000, $coordsString)["place"~"city|town|village|suburb"];
    );
    out tags center;
  ''';

  print("Running nwr query...");
  final res2 = await http.post(
    Uri.parse('https://overpass-api.de/api/interpreter'),
    body: {'data': query2},
    headers: {'User-Agent': 'LoopCarApp/1.0', 'Accept': '*/*'}
  );
  if (res2.statusCode != 200) {
     print(res2.body);
  } else {
     print("NWR returned ${jsonDecode(res2.body)['elements'].length} elements");
  }
}
