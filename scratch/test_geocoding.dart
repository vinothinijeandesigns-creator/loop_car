import 'package:geocoding/geocoding.dart';

void main() async {
  try {
    List<Location> locations = await locationFromAddress("mathur");
    for (var loc in locations) {
      print('Mathur -> Lat: ${loc.latitude}, Lng: ${loc.longitude}');
    }
    
    List<Location> locations2 = await locationFromAddress("trichy");
    for (var loc in locations2) {
      print('Trichy -> Lat: ${loc.latitude}, Lng: ${loc.longitude}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
