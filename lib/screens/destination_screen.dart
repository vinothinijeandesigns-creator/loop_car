import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'post_ride_data.dart';
import '../services/location_service.dart';
import 'route_preview_screen.dart';

class DestinationScreen extends StatefulWidget {
  final PostRideData data;
  const DestinationScreen({super.key, required this.data});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  maps.LatLng _destinationLatLng = const maps.LatLng(12.9716, 77.5946);
  bool _isLoading = false;
  bool _isFetchingAddress = false;
  maps.GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  late final FlutterGooglePlacesSdk _placesSdk;
  List<AutocompletePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _isMoving = false;
  bool _tappedByUser = false;

  @override
  void initState() {
    super.initState();
    _placesSdk = FlutterGooglePlacesSdk(
      "AIzaSyCB4HB8C4J_4tE7L4ZeQK4rgQFf3671eM4",
    );
    // Initialize with current destination if available
    if (widget.data.destination != null) {
      _destinationLatLng = widget.data.destination!;
    } else {
      // Fetch the current user location if no destination is pre-selected
      _loadCurrentLocation();
    }
    if (widget.data.destinationAddress.isNotEmpty) {
      _searchController.text = widget.data.destinationAddress;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final latLng = await LocationService.getCurrentLatLng();
      if (mounted && latLng != null) {
        setState(() {
          _destinationLatLng = latLng;
          widget.data.destination = latLng;
          _tappedByUser = true;
        });

        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(latLng, 16),
        );

        await _updateDestination(latLng);
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final response = await _placesSdk.findAutocompletePredictions(query);
        if (mounted) {
          setState(() {
            _predictions = response.predictions;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint("Search error: $e");
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _performManualSearch(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _predictions = [];
    });

    try {
      final latLng = await LocationService.forwardGeocode(query);
      if (latLng != null && mounted) {
        setState(() {
          _destinationLatLng = latLng;
          _tappedByUser = true;
        });
        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(latLng, 16),
        );
        await _updateDestination(latLng);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Destination not found. Please try pinning it on the map."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Manual search error: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleSuggestionTap(AutocompletePrediction prediction) async {
    setState(() {
      _predictions = [];
      _searchController.text = prediction.fullText;
    });
    FocusScope.of(context).unfocus();

    try {
      final response = await _placesSdk.fetchPlace(
        prediction.placeId,
        fields: [PlaceField.Location],
      );
      final latLng = response.place?.latLng;
      if (latLng != null && mounted) {
        final newPos = maps.LatLng(latLng.lat, latLng.lng);
        setState(() {
          _destinationLatLng = newPos;
          _tappedByUser = true; // Prevent onCameraIdle from overwriting
        });
        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(newPos, 16),
        );
        // Canonicalize address and update UI
        await _updateDestination(newPos);
      }
    } catch (e) {
      debugPrint("Fetch Place Error: $e");
    }
  }

  Future<void> _updateDestination(maps.LatLng latLng) async {
    setState(() => _isFetchingAddress = true);
    try {
      final address = await LocationService.reverseGeocode(latLng);

      if (mounted) {
        widget.data.destination = latLng;
        if (address != null) {
          widget.data.destinationAddress = address;
          setState(() {
            _searchController.text = address;
            _predictions = [];
            _isFetchingAddress = false;
          });
        } else {
          setState(() {
            _isFetchingAddress = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Update Destination Error: $e");
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }

  void _onMapTap(maps.LatLng tappedLatLng) {
    setState(() {
      _destinationLatLng = tappedLatLng;
      _tappedByUser = true;
    });
    _mapController?.animateCamera(maps.CameraUpdate.newLatLng(tappedLatLng));
    _updateDestination(tappedLatLng);
  }

  void _goToRoutePreview() {
    widget.data.destination = _destinationLatLng;
    // Fallback: If address is empty but we have latlng, use coordinates
    if (widget.data.destinationAddress.isEmpty) {
      widget.data.destinationAddress =
          "${_destinationLatLng.latitude.toStringAsFixed(5)}, ${_destinationLatLng.longitude.toStringAsFixed(5)}";
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutePreviewScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF00C6D2);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Where are you going?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          maps.GoogleMap(
            initialCameraPosition: maps.CameraPosition(
              target: _destinationLatLng,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              setState(() {
                _destinationLatLng = position.target;
                _isMoving = true;
              });
            },
            onCameraIdle: () {
              setState(() => _isMoving = false);
              if (!_tappedByUser) {
                _updateDestination(_destinationLatLng);
              }
              _tappedByUser = false;
            },
            onTap: _onMapTap,
            markers: {},
          ),

          // Fixed Center Pin Overlay - wrapped in IgnorePointer
          IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 35),
                child: Icon(
                  Icons.location_on,
                  size: 45,
                  color:
                      _isMoving
                          ? primaryColor.withValues(alpha: 0.7)
                          : primaryColor,
                ),
              ),
            ),
          ),

          // Search UI
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Search Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _performManualSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Search for a destination",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      border: InputBorder.none,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFetchingAddress)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor,
                                    ),
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.search),
                                color: primaryColor,
                                onPressed: () => _performManualSearch(_searchController.text),
                              ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _predictions = [];
                                    widget.data.destinationAddress = '';
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Suggestions List
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _predictions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: primaryColor,
                          ),
                          title: Text(
                            p.fullText,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => _handleSuggestionTap(p),
                        );
                      },
                    ),
                  ),

                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),

          // Current Location Button
          Positioned(
            bottom: 110,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'locate_destination',
              mini: true,
              onPressed: _loadCurrentLocation,
              backgroundColor: Colors.white,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SizedBox(
          width: 70,
          height: 70,
          child: FloatingActionButton(
            heroTag: 'next_to_preview',
            onPressed: _goToRoutePreview,
            backgroundColor: const Color(0xFF80E8F0),
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
