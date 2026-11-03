import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  static Future<LatLng?> getCurrentLatLng() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions are denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions are permanently denied.");
      return null;
    }

    try {
      // 1. Try to get the last known position first (much faster)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint(
          "Using last known position: ${lastKnown.latitude}, ${lastKnown.longitude}",
        );
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }

      // 2. If no last known, try to get current position with a timeout
      debugPrint("Requesting current position...");
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }

  static Future<String?> reverseGeocode(LatLng latLng) async {
    try {
      debugPrint("Reverse geocoding: ${latLng.latitude}, ${latLng.longitude}");

      // Using the native geocoding package which is often more reliable on mobile
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;

        // Build a detailed formatted address
        List<String> parts = [];

        // 1. Street info (Thoroughfare)
        if (pm.street != null &&
            pm.street!.isNotEmpty &&
            !pm.street!.contains('+')) {
          parts.add(pm.street!);
        } else if (pm.thoroughfare != null && pm.thoroughfare!.isNotEmpty) {
          parts.add(pm.thoroughfare!);
          if (pm.subThoroughfare != null && pm.subThoroughfare!.isNotEmpty) {
            parts[parts.length - 1] =
                "${pm.subThoroughfare}, ${pm.thoroughfare}";
          }
        }

        // 2. Local area (SubLocality / Neighborhood)
        if (pm.subLocality != null && pm.subLocality!.isNotEmpty) {
          parts.add(pm.subLocality!);
        }

        // 3. City (Locality)
        if (pm.locality != null && pm.locality!.isNotEmpty) {
          parts.add(pm.locality!);
        }

        // 4. State (Administrative Area)
        if (pm.administrativeArea != null &&
            pm.administrativeArea!.isNotEmpty) {
          parts.add(pm.administrativeArea!);
        }

        // 5. Postal Code
        if (pm.postalCode != null && pm.postalCode!.isNotEmpty) {
          parts.add(pm.postalCode!);
        }

        // Filter out empty parts and duplicates, then join
        String address = parts.where((s) => s.isNotEmpty).toSet().join(", ");

        if (address.isNotEmpty) {
          debugPrint("Geocoding result: $address");
          return address;
        }
      }

      // If geocoding returns nothing, return a string with coordinates
      return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
    } catch (e) {
      debugPrint("Reverse geocode exception: $e");
      // Fallback to coordinates
      return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
    }
  }

  static Future<LatLng?> forwardGeocode(String address) async {
    try {
      debugPrint("Forward geocoding: $address");
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
      return null;
    } catch (e) {
      debugPrint("Forward geocode exception: $e");
      return null;
    }
  }
}
