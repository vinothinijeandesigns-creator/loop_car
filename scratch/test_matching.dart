import 'package:geolocator/geolocator.dart';

class RideWaypoint {
  final String locationName;
  final double lat;
  final double lng;
  final int order;

  RideWaypoint({
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.order,
  });
}

void main() {
  // Thanjavur
  double startLat = 10.7869;
  double startLng = 79.1378;
  
  // Mathur, Trichy
  double mathurLat = 10.7029;
  double mathurLng = 78.7562;
  
  // Trichy (Sangillyandapuram)
  double endLat = 10.8050;
  double endLng = 78.6856;
  
  // User Search: Mathur to Trichy
  double searchStartLat = 10.7029;
  double searchStartLng = 78.7562;
  double searchDropLat = 10.8050;
  double searchDropLng = 78.6856;

  List<RideWaypoint> waypoints = [
    RideWaypoint(locationName: 'Thanjavur', lat: startLat, lng: startLng, order: -1),
    RideWaypoint(locationName: 'Mathur', lat: mathurLat, lng: mathurLng, order: 1),
    RideWaypoint(locationName: 'Sangillyandapuram', lat: endLat, lng: endLng, order: 999),
  ];
  
  double maxRadiusKm = 15.0;
  
  RideWaypoint? matchedStart;
  for (var wp in waypoints) {
    double distanceInMeters = Geolocator.distanceBetween(
      searchStartLat, searchStartLng, wp.lat, wp.lng,
    );
    print('Start checking \${wp.locationName}: distance \${distanceInMeters/1000} km');
    if (distanceInMeters / 1000 <= maxRadiusKm) {
      matchedStart = wp;
      break;
    }
  }
  
  RideWaypoint? matchedDrop;
  for (var wp in waypoints.reversed) {
    double distanceInMeters = Geolocator.distanceBetween(
      searchDropLat, searchDropLng, wp.lat, wp.lng,
    );
    print('Drop checking \${wp.locationName}: distance \${distanceInMeters/1000} km');
    if (distanceInMeters / 1000 <= maxRadiusKm) {
      matchedDrop = wp;
      break;
    }
  }
  
  if (matchedStart != null && matchedDrop != null) {
    print('Matched: \${matchedStart.locationName} (\${matchedStart.order}) -> \${matchedDrop.locationName} (\${matchedDrop.order})');
    if (matchedStart.order < matchedDrop.order) {
      print('Valid Route!');
    } else {
      print('Invalid Route (Order incorrect)');
    }
  } else {
    print('Not matched');
  }
}
