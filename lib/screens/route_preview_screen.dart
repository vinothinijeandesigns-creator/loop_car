import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'post_ride_data.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';
import 'postcalendar.dart';

class RoutePreviewScreen extends StatefulWidget {
  final PostRideData data;
  const RoutePreviewScreen({super.key, required this.data});

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final Set<Polyline> polylines = {};
  int _currentStep = 0;
  int _selectedRouteIndex = 0;
  List<RouteInfo> _availableRoutes = [];
  GoogleMapController? _mapController;
  bool _isLoading = true;
  final Set<int> _checkedDistrictIndices = {};
  final Set<Marker> _routeMarkers = {};
  Map<int, Offset> _labelPositions = {};

  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _endIcon;

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
    _loadRoute();
  }

  Future<void> _initCustomMarkers() async {
    _startIcon = await _getCustomPinMarker(const Color(0xFF0D1B2A), isStart: true);
    _endIcon = await _getCustomPinMarker(const Color(0xFF007AFF), isStart: false);
    if (mounted) _updateMarkers();
  }

  Future<BitmapDescriptor> _getCustomPinMarker(Color color, {bool isStart = true}) async {
    final int size = 90;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    if (isStart) {
      // Draw a circular marker for start
      final Paint borderPaint = Paint()..color = Colors.white;
      final Paint innerPaint = Paint()..color = color;
      
      // Shadow
      canvas.drawCircle(Offset(size/2, size/2), size/2.5, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));
      // White border
      canvas.drawCircle(Offset(size/2, size/2), size/2.5, borderPaint);
      // Inner color
      canvas.drawCircle(Offset(size/2, size/2), size/4, innerPaint);
    } else {
      // Draw a pin marker for end
      final Paint paint = Paint()..color = color;
      final Paint whitePaint = Paint()..color = Colors.white;
      
      Path path = Path();
      path.moveTo(size / 2, size.toDouble() - 10); // Bottom point
      path.quadraticBezierTo(size / 2 - size / 3, size / 1.5, size / 2 - size / 3, size / 3);
      path.arcToPoint(
        Offset(size / 2 + size / 3, size / 3),
        radius: Radius.circular(size / 3),
        clockwise: true,
      );
      path.quadraticBezierTo(size / 2 + size / 3, size / 1.5, size / 2, size.toDouble() - 10);
      
      canvas.drawPath(path, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));
      canvas.drawPath(path, paint);
      
      // Inner white circle
      canvas.drawCircle(Offset(size / 2, size / 3), size / 8, whitePaint);
    }

    final ui.Image image = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadRoute() async {
    setState(() => _isLoading = true);
    try {
      final routes = await DirectionsService.getRoutes(
        widget.data.pickup!,
        widget.data.destination!,
      );

      if (routes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No routes found')));
        return;
      }

      if (!mounted) return;

      setState(() {
        _availableRoutes = routes;
        _isLoading = false;
      });
      _updateSelectedRoute(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading routes: $e')));
    }
  }

  bool _isDistrictsLoading = false;

  void _updateSelectedRoute(int index) async {
    // Immediate UI feedback for selection and polyline
    setState(() {
      _selectedRouteIndex = index;
      _isDistrictsLoading = true;
      _checkedDistrictIndices.clear(); // Clear old indices while loading
      
      polylines.clear();
      // Add alternative routes first (lower z-index)
      for (int i = 0; i < _availableRoutes.length; i++) {
        if (i == index) continue;
        polylines.add(
          Polyline(
            polylineId: PolylineId("route_$i"),
            points: _availableRoutes[i].points,
            color: const Color(0xFF8B9CB5), // Greyish-blue for unselected routes
            width: 5,
            zIndex: 0,
            onTap: () => _updateSelectedRoute(i),
            consumeTapEvents: true,
          ),
        );
      }

      // Add selected route LAST so it draws on top
      polylines.add(
        Polyline(
          polylineId: PolylineId("route_$index"),
          points: _availableRoutes[index].points,
          color: const Color(0xFF007AFF), // Vivid Blue
          width: 6,
          zIndex: 1,
          onTap: () => _updateSelectedRoute(index),
          consumeTapEvents: true,
        ),
      );
      
      _updateMarkers();
    });

    final selectedRoute = _availableRoutes[index];
    widget.data.distance = selectedRoute.distanceKm;

    // Load districts for this specific route if not already loaded
    if (selectedRoute.suggestedDistricts.isEmpty) {
      try {
        List<StopoverDistrict> districts = await DirectionsService.findMajorDistrictsLocal(
          selectedRoute.points,
        );

        // Fallback to backend if local extraction yields nothing
        if (districts.isEmpty) {
          districts = await DirectionsService.findMajorDistricts(
            selectedRoute.encodedPolyline,
          );
        }
        // Ensure we only update if the user hasn't switched routes again
        if (_selectedRouteIndex == index) {
          selectedRoute.suggestedDistricts = districts;
        }
      } catch (e) {
        debugPrint("Error loading districts: $e");
      }
    }

    if (!mounted || _selectedRouteIndex != index) return;

    setState(() {
      _isDistrictsLoading = false;
      // Reset selection to include all detected districts by default
      _checkedDistrictIndices.clear();
      for (int i = 0; i < selectedRoute.suggestedDistricts.length; i++) {
        _checkedDistrictIndices.add(i);
      }
      
      _fitRoute();
      _updateLabelPositions();
    });
  }

  void _updateMarkers() {
    _routeMarkers.clear();

    // Start Marker
    _routeMarkers.add(
      Marker(
        markerId: const MarkerId("pickup"),
        position: widget.data.pickup!,
        icon: _startIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: const Offset(0.5, 0.5), // Center for circle
      ),
    );

    // End Marker
    _routeMarkers.add(
      Marker(
        markerId: const MarkerId("drop"),
        position: widget.data.destination!,
        icon: _endIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0), // Bottom center for pin
      ),
    );
  }

  Future<void> _updateLabelPositions() async {
    if (_mapController == null || _availableRoutes.isEmpty) return;

    final Map<int, Offset> newPositions = {};

    for (int i = 0; i < _availableRoutes.length; i++) {
      final route = _availableRoutes[i];
      // Distribute labels along the routes to match the visual variety in Google Maps
      int pointIndex;
      if (i == 0) {
        pointIndex = (route.points.length * 0.4).toInt();
      } else if (i == 1) {
        pointIndex = (route.points.length * 0.6).toInt();
      } else {
        pointIndex = (route.points.length * 0.3).toInt();
      }

      if (pointIndex >= route.points.length) {
        pointIndex = route.points.length - 1;
      }

      final latLng = route.points[pointIndex];
      final screenPos = await _mapController!.getScreenCoordinate(latLng);

      newPositions[i] = Offset(screenPos.x.toDouble(), screenPos.y.toDouble());
    }

    if (mounted) {
      setState(() {
        _labelPositions = newPositions;
      });
    }
  }

  void _fitRoute() {
    if (_mapController == null || _availableRoutes.isEmpty) return;
    final points = _availableRoutes[_selectedRouteIndex].points;
    if (points.isEmpty) return;

    final bounds = _getBounds(points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _nextStep() {
    if (_currentStep == 1) {
      // Save selected stopovers chronologically
      final route = _availableRoutes[_selectedRouteIndex];
      final sortedIndices = _checkedDistrictIndices.toList()..sort();
      widget.data.selectedStopovers =
          sortedIndices
              .map((idx) => route.suggestedDistricts[idx])
              .toList();
    }

    if (_currentStep < 1) { // Changed from 2 to 1 to skip redundant confirmation
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SelectDateScreen(data: widget.data)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentStep == 0) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF007AFF))),
      );
    }

    if (_currentStep == 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildRouteSelection(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Back button and Tagline
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep--);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF455A64),
                      size: 28,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Ride, Laugh, Repeat, For Less!",
                        style: TextStyle(
                          color: Color(0xFF546E7A),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  // Spacer to balance the back icon for centering
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // Main content
            Expanded(child: _buildStepContent()),

            // Custom Bottom Navigation Bar with FAB Overlap
            _buildCustomBottomRegion(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomRegion() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBottomBar(),
        Positioned(
          top: -30,
          right: 30,
          child: GestureDetector(
            onTap: _nextStep,
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFF80E8F0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildRouteSelection();
      case 1:
        return _buildAddStopovers();
      case 2:
        return _buildConfirmStops();
      default:
        return Container();
    }
  }

  Widget _buildRouteSelection() {
    final mapHeight = MediaQuery.of(context).size.height * 0.55;

    return Stack(
      children: [
        // Map Container
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: mapHeight,
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitRoute();
                  _updateLabelPositions();
                },
                onCameraMove: (position) => _updateLabelPositions(),
                initialCameraPosition: CameraPosition(
                  target: widget.data.pickup!,
                  zoom: 10,
                ),
                markers: _routeMarkers,
                polylines: polylines,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
              ..._buildRouteLabels(),
            ],
          ),
        ),

        // Floating Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),
        ),

        // Bottom Sheet Style Content
        Positioned(
          top: mapHeight - 24,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "What is your route?",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: _availableRoutes.length,
                    itemBuilder: (context, index) {
                      final route = _availableRoutes[index];
                      bool isSelected = _selectedRouteIndex == index;
                      return InkWell(
                        onTap: () => _updateSelectedRoute(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF007AFF),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${route.durationText} - ${route.hasTolls ? 'Tolls' : 'No tolls'}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF0D1B2A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${route.distanceKm.toStringAsFixed(0)} km - ${route.summary.isNotEmpty ? route.summary : 'Fastest route'}",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // FAB Next Button
        Positioned(
          bottom: 24,
          right: 24,
          child: GestureDetector(
            onTap: _nextStep,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRouteLabels() {
    return _labelPositions.entries.map((entry) {
      final index = entry.key;
      final offset = entry.value;
      final route = _availableRoutes[index];
      bool isSelected = _selectedRouteIndex == index;

      return Positioned(
        left: offset.dx - 60,
        top: offset.dy - 60,
        child: GestureDetector(
          onTap: () => _updateSelectedRoute(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: isSelected ? Colors.black26 : Colors.black12,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_bike,
                      size: 18,
                      color: isSelected ? Colors.black54 : Colors.black38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      route.durationText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${route.distanceKm.toStringAsFixed(0)} km",
                  style: const TextStyle(
                    fontSize: 14, 
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAddStopovers() {
    final suggested = _availableRoutes[_selectedRouteIndex].suggestedDistricts;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            "Add stopovers to get\nmore passengers",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D47A1),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 32),
          if (_isDistrictsLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00C6D2)),
                    SizedBox(height: 16),
                    Text(
                      "Detecting districts...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (suggested.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "No major districts detected along this exact route.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: suggested.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final district = suggested[index];
                  bool isChecked = _checkedDistrictIndices.contains(index);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (_checkedDistrictIndices.contains(index)) {
                          _checkedDistrictIndices.remove(index);
                        } else {
                          _checkedDistrictIndices.add(index);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF00C6D2),
                                width: 2,
                              ),
                            ),
                            child:
                                isChecked
                                    ? const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Color(0xFF00C6D2),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  district.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isChecked
                                            ? const Color(0xFF0D47A1)
                                            : Colors.blueGrey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "Add city",
              style: TextStyle(
                color: Color(0xFF00C6D2),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 80), // Space for button overlap
        ],
      ),
    );
  }

  Widget _buildConfirmStops() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            "These are the best places\nto stop. OK for you?",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D47A1),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: SingleChildScrollView(child: _buildStopsTimeline())),
        ],
      ),
    );
  }

  Widget _buildStopsTimeline() {
    final route = _availableRoutes[_selectedRouteIndex];
    final List<Map<String, dynamic>> stops = [
      {
        "name":
            widget.data.pickupAddress.isNotEmpty
                ? widget.data.pickupAddress
                : "Start Location",
        "isStart": true,
      },
    ];

    // Add selected districts in the order they appear along the route
    for (int i = 0; i < route.suggestedDistricts.length; i++) {
      if (_checkedDistrictIndices.contains(i)) {
        final d = route.suggestedDistricts[i];
        if (d.majorStops.isNotEmpty) {
          for (var stop in d.majorStops) {
            // Remove the word 'District' for the subtitle if present to match BlaBlaCar style
            String districtClean = d.name.replaceAll(RegExp(r'\s*District\s*'), '');
            String? subtitle = stop.name == districtClean ? null : districtClean;
            stops.add({"name": stop.name, "district": subtitle, "isStop": true});
          }
        } else {
          String districtClean = d.name.replaceAll(RegExp(r'\s*District\s*'), '');
          String? subtitle = d.bestPlace == districtClean ? null : districtClean;
          stops.add({"name": d.bestPlace, "district": subtitle, "isStop": true});
        }
      }
    }

    stops.add({
      "name":
          widget.data.destinationAddress.isNotEmpty
              ? widget.data.destinationAddress
              : "Destination",
      "isEnd": true,
    });

    return Column(
      children: List.generate(stops.length, (index) {
        final stop = stops[index];
        bool isMidStop = stop['isStop'] == true;
        bool isFirst = index == 0;
        bool isLast = index == stops.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline vertical line and indicators
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 10,
                      color: isFirst ? Colors.transparent : Colors.grey[300],
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isMidStop
                                  ? const Color(0xFF00C6D2)
                                  : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isMidStop ? Colors.transparent : Colors.white,
                      ),
                      child:
                          !isMidStop
                              ? Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                              : null,
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Stop Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop["name"],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blueGrey[800],
                                fontWeight:
                                    isMidStop
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            if (stop['district'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                stop['district'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey[300],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isMidStop)
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[300],
                          size: 28,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 85,
      decoration: const BoxDecoration(
        color: Color(0xFF00C6D2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(Icons.search, "Search"),
          _navItem(Icons.add, "Post", isSelected: true),
          _navItem(Icons.directions_car, "Ride History"),
          _navItem(Icons.chat_bubble_outline, "Chat"),
          _navItem(Icons.person_outline, "Profile"),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool isSelected = false}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class Position8d extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Widget child;

  const Position8d({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: child,
    );
  }
}
