import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';

class RouteMapScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  const RouteMapScreen({super.key, required this.rideData});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late LatLng _pickupLocation;
  late LatLng _dropLocation;
  late String _pickupName;
  late String _dropName;

  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _pickupLocation = LatLng(
      (widget.rideData['start_lat'] as num?)?.toDouble() ?? 13.0067,
      (widget.rideData['start_lng'] as num?)?.toDouble() ?? 80.2206,
    );
    _dropLocation = LatLng(
      (widget.rideData['end_lat'] as num?)?.toDouble() ?? 12.9249,
      (widget.rideData['end_lng'] as num?)?.toDouble() ?? 80.1000,
    );
    _pickupName = widget.rideData['start_location'] ?? 'Pickup';
    _dropName = widget.rideData['end_location'] ?? 'Drop-off';
    _setMapData();
  }

  void _setMapData() async {
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation,
        infoWindow: InfoWindow(title: 'Pickup Location', snippet: _pickupName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('drop'),
        position: _dropLocation,
        infoWindow: InfoWindow(title: 'Drop-off', snippet: _dropName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    List<LatLng> waypoints = [];
    if (widget.rideData['ride_stops'] != null) {
      final stops = widget.rideData['ride_stops'] as List;
      // Sort stops by stop_order just in case
      List<dynamic> sortedStops = List.from(stops);
      sortedStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));
      
      int index = 1;
      for (var stop in sortedStops) {
        if (stop['lat'] != null && stop['lng'] != null) {
          final lat = (stop['lat'] as num).toDouble();
          final lng = (stop['lng'] as num).toDouble();
          final name = stop['location_name'] ?? 'Stopover $index';
          waypoints.add(LatLng(lat, lng));
          
          _markers.add(
            Marker(
              markerId: MarkerId('stop_$index'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: name),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            ),
          );
          index++;
        }
      }
    }

    // Initial dashed line while loading
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_pickupLocation, ...waypoints, _dropLocation],
          color: const Color(0xFF00C6D2),
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)], // Optional: dashed line for approximate route
        ),
      );
    });

    try {
      final routes = await DirectionsService.getRoutes(_pickupLocation, _dropLocation, waypoints: waypoints);
      if (routes.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _polylines.removeWhere((p) => p.polylineId == const PolylineId('route'));
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route_real'),
              points: routes.first.points,
              color: const Color(0xFF00C6D2),
              width: 5,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    
    // Animate camera to fit both markers
    Future.delayed(const Duration(milliseconds: 500), () {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _dropLocation.latitude < _pickupLocation.latitude ? _dropLocation.latitude : _pickupLocation.latitude,
          _dropLocation.longitude < _pickupLocation.longitude ? _dropLocation.longitude : _pickupLocation.longitude,
        ),
        northeast: LatLng(
          _dropLocation.latitude > _pickupLocation.latitude ? _dropLocation.latitude : _pickupLocation.latitude,
          _dropLocation.longitude > _pickupLocation.longitude ? _dropLocation.longitude : _pickupLocation.longitude,
        ),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Color(0xFF00C6D2)),
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Route Map",
          style: TextStyle(
            color: Color(0xFF00C6D2),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _pickupLocation,
          zoom: 12.0,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          // Re-center logic
          mapController.animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation, 12.0));
        },
        child: const Icon(Icons.my_location, color: Color(0xFF00C6D2)),
      ),
    );
  }
}
