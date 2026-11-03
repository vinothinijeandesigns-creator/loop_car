import 'package:flutter/foundation.dart';
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

/// Core Matching Engine Logic for Stopovers
class RideMatchingEngine {
  /// Extract all waypoints (Start, Stops, End) from a ride map
  static List<RideWaypoint> getWaypoints(Map<String, dynamic> ride) {
    List<RideWaypoint> waypoints = [];

    // 1. Start Location
    if (ride['start_lat'] != null && ride['start_lng'] != null) {
      waypoints.add(RideWaypoint(
        locationName: ride['start_location']?.toString() ?? 'Start',
        lat: (ride['start_lat'] as num).toDouble(),
        lng: (ride['start_lng'] as num).toDouble(),
        order: -1,
      ));
    }

    // 2. Stopovers
    if (ride['ride_stops'] != null && ride['ride_stops'] is List) {
      List stops = ride['ride_stops'] as List;
      stops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));
      
      for (var stop in stops) {
        if (stop['lat'] != null && stop['lng'] != null) {
          waypoints.add(RideWaypoint(
            locationName: stop['location_name']?.toString() ?? 'Stop',
            lat: (stop['lat'] as num).toDouble(),
            lng: (stop['lng'] as num).toDouble(),
            order: stop['stop_order'] ?? 0,
          ));
        }
      }
    }

    // 3. End Location
    if (ride['end_lat'] != null && ride['end_lng'] != null) {
      waypoints.add(RideWaypoint(
        locationName: ride['end_location']?.toString() ?? 'End',
        lat: (ride['end_lat'] as num).toDouble(),
        lng: (ride['end_lng'] as num).toDouble(),
        order: 999,
      ));
    }

    return waypoints;
  }

  /// Checks if a single ride matches the search criteria (Radius Match).
  static bool checkRouteMatch({
    required Map<String, dynamic> ride,
    double? startLat,
    double? startLng,
    double? dropLat,
    double? dropLng,
    String? startQuery,
    String? dropQuery,
    int requiredSeats = 1,
    double maxRadiusKm = 15.0,
  }) {
    // 1. Check Seats
    int availableSeats = 
        ride['available_seats'] ?? 
        ride['available_seat'] ?? 
        ride['seats'] ?? 0;
        
    if (availableSeats < requiredSeats) {
      return false; // Not enough seats
    }

    // If coordinates are missing, fallback
    if (startLat == null || startLng == null || dropLat == null || dropLng == null) {
      return false; 
    }

    // 2. Check Route via Geographical Distance
    List<RideWaypoint> waypoints = getWaypoints(ride);
    
    RideWaypoint? matchedStart;
    RideWaypoint? matchedDrop;

    // Helper for string matching
    bool isStringMatch(String? query, String locationName) {
      if (query == null || query.trim().length < 3) return false;
      final q = query.trim().toLowerCase();
      final l = locationName.toLowerCase();
      return l.contains(q) || q.contains(l);
    }

    // Find the first waypoint within radius of start location OR matching string
    for (var wp in waypoints) {
      bool isMatch = false;
      if (startLat != null && startLng != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          startLat, startLng, wp.lat, wp.lng,
        );
        if (distanceInMeters / 1000 <= maxRadiusKm) {
          isMatch = true;
        }
      }
      
      if (!isMatch && isStringMatch(startQuery, wp.locationName)) {
        isMatch = true;
      }
      
      if (isMatch) {
        matchedStart = wp;
        break;
      }
    }

    // Find the latest waypoint within radius of drop location OR matching string
    // Iterate backwards to find the last drop point if multiple match
    for (var wp in waypoints.reversed) {
      bool isMatch = false;
      if (dropLat != null && dropLng != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          dropLat, dropLng, wp.lat, wp.lng,
        );
        if (distanceInMeters / 1000 <= maxRadiusKm) {
          isMatch = true;
        }
      }
      
      if (!isMatch && isStringMatch(dropQuery, wp.locationName)) {
        isMatch = true;
      }
      
      if (isMatch) {
        matchedDrop = wp;
        break;
      }
    }

    // Both locations must be near a waypoint, AND drop must happen AFTER start
    if (matchedStart != null && matchedDrop != null && matchedStart.order < matchedDrop.order) {
      // Inject matched locations into the ride object for the UI
      ride['matched_start_location'] = matchedStart.locationName;
      ride['matched_end_location'] = matchedDrop.locationName;
      return true;
    }

    return false;
  }

  /// Filters a list of available rides based on search criteria.
  static List<Map<String, dynamic>> filterMatchingRides({
    required List<Map<String, dynamic>> availableRides,
    double? startLat,
    double? startLng,
    double? dropLat,
    double? dropLng,
    String? startQuery,
    String? dropQuery,
    required int requiredSeats,
  }) {
    return availableRides.where((ride) {
      return checkRouteMatch(
        ride: ride,
        startLat: startLat,
        startLng: startLng,
        dropLat: dropLat,
        dropLng: dropLng,
        startQuery: startQuery,
        dropQuery: dropQuery,
        requiredSeats: requiredSeats,
      );
    }).toList();
  }
}
