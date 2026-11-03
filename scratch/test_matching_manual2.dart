import 'dart:math';

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

double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
  return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
}

void main() {
  // Database Start
  double startLat = 10.7877190427349;
  double startLng = 79.1384287923574;
  
  // Database Stop 0 (Thanjavur District)
  double stop0Lat = 10.7453;
  double stop0Lng = 79.1289;

  // Database Stop 1 (Tiruchirappalli District)
  double stop1Lat = 10.713;
  double stop1Lng = 78.761;
  
  // Database End
  double endLat = 10.7904832723281;
  double endLng = 78.7046723440289;
  
  // User Search: Mathur to Trichy
  double searchStartLat = 10.7029;
  double searchStartLng = 78.7562;
  double searchDropLat = 10.8050; // Trichy
  double searchDropLng = 78.6856;

  List<RideWaypoint> waypoints = [
    RideWaypoint(locationName: 'Start', lat: startLat, lng: startLng, order: -1),
    RideWaypoint(locationName: 'Stop0', lat: stop0Lat, lng: stop0Lng, order: 0),
    RideWaypoint(locationName: 'Stop1', lat: stop1Lat, lng: stop1Lng, order: 1),
    RideWaypoint(locationName: 'End', lat: endLat, lng: endLng, order: 999),
  ];
  
  double maxRadiusKm = 15.0;
  
  RideWaypoint? matchedStart;
  for (var wp in waypoints) {
    double distanceKm = distanceBetween(
      searchStartLat, searchStartLng, wp.lat, wp.lng,
    );
    print('Start checking ' + wp.locationName + ': distance ' + distanceKm.toString() + ' km');
    if (distanceKm <= maxRadiusKm) {
      matchedStart = wp;
      break;
    }
  }
  
  RideWaypoint? matchedDrop;
  for (var wp in waypoints.reversed) {
    double distanceKm = distanceBetween(
      searchDropLat, searchDropLng, wp.lat, wp.lng,
    );
    print('Drop checking ' + wp.locationName + ': distance ' + distanceKm.toString() + ' km');
    if (distanceKm <= maxRadiusKm) {
      matchedDrop = wp;
      break;
    }
  }
  
  if (matchedStart != null && matchedDrop != null) {
    print('Matched: ' + matchedStart.locationName + ' -> ' + matchedDrop.locationName);
    if (matchedStart.order < matchedDrop.order) {
      print('Valid Route!');
    } else {
      print('Invalid Route (Order incorrect)');
    }
  } else {
    print('Not matched');
  }
}
