import 'dart:math';

double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
  return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
}

void main() {
  double stop1Lat = 10.713;
  double stop1Lng = 78.761;
  double searchDropLat = 10.8050; // Trichy
  double searchDropLng = 78.6856;

  double distanceKm = distanceBetween(searchDropLat, searchDropLng, stop1Lat, stop1Lng);
  print('Distance between Stop1 and Search Drop (Trichy): ' + distanceKm.toString() + ' km');
}
