import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'destination_screen.dart';
import '../services/location_service.dart';
import 'post_ride_data.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final PostRideData data = PostRideData();
  maps.LatLng _pickupLatLng = const maps.LatLng(
    12.9716,
    77.5946,
  ); // Default to a known city center
  bool _isLoading = false;
  bool _isFetchingAddress = false;
  maps.GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  late final FlutterGooglePlacesSdk _placesSdk;
  List<AutocompletePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;
  bool _isMoving = false;
  bool _tappedByUser = false; // Prevents onCameraIdle from racing with onTap

  @override
  void initState() {
    super.initState();
    _placesSdk = FlutterGooglePlacesSdk(
      "AIzaSyCB4HB8C4J_4tE7L4ZeQK4rgQFf3671eM4",
    );
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
          _pickupLatLng = latLng;
          data.pickup = latLng;
          _tappedByUser = true; // Prevent onCameraIdle from re-geocoding
        });

        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(latLng, 16),
        );

        // Fetch address for current location
        await _updatePickup(latLng);
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
          _pickupLatLng = latLng;
          _tappedByUser = true;
        });
        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(latLng, 16),
        );
        await _updatePickup(latLng);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location not found. Please try pinning it on the map."),
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
          _pickupLatLng = newPos;
          _tappedByUser = true; // Prevent onCameraIdle from overwriting
        });
        _mapController?.animateCamera(
          maps.CameraUpdate.newLatLngZoom(newPos, 16),
        );
        // Canonicalize address and update UI
        await _updatePickup(newPos);
      }
    } catch (e) {
      debugPrint("Fetch Place Error: $e");
    }
  }

  Future<void> _updatePickup(maps.LatLng latLng) async {
    setState(() => _isFetchingAddress = true);
    try {
      final address = await LocationService.reverseGeocode(latLng);

      if (mounted) {
        data.pickup = latLng;
        if (address != null) {
          data.pickupAddress = address;
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
      debugPrint("Update Pickup Error: $e");
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }

  void _onMapTap(maps.LatLng tappedLatLng) {
    setState(() {
      _pickupLatLng = tappedLatLng;
      _tappedByUser =
          true; // Prevent onCameraIdle from triggering another geocode
    });
    _mapController?.animateCamera(maps.CameraUpdate.newLatLng(tappedLatLng));
    _updatePickup(tappedLatLng);
  }

  void _goToDestinationScreen() {
    data.pickup = _pickupLatLng;
    // Fallback: If address is empty but we have latlng, use coordinates
    if (data.pickupAddress.isEmpty) {
      data.pickupAddress = "${_pickupLatLng.latitude.toStringAsFixed(5)}, ${_pickupLatLng.longitude.toStringAsFixed(5)}";
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DestinationScreen(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF00C6D2);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Where are you leaving from?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          maps.GoogleMap(
            initialCameraPosition: maps.CameraPosition(
              target: _pickupLatLng,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              // Reverse-geocode the initial position so address is available
              _updatePickup(_pickupLatLng);
              // Also try to move to the user's actual current location
              _loadCurrentLocation();
            },
            onCameraMove: (position) {
              setState(() {
                _pickupLatLng = position.target;
                _isMoving = true;
              });
            },
            onCameraIdle: () {
              setState(() => _isMoving = false);
              // Only reverse-geocode on camera idle if NOT triggered by a tap or search selection
              if (!_tappedByUser) {
                _updatePickup(_pickupLatLng);
              }
              _tappedByUser = false; // Reset the flag
            },
            onTap: _onMapTap,
            markers: {},
          ),

          // Fixed Center Pin Overlay - wrapped in IgnorePointer so taps pass through to the map
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
                      hintText: "Search for a location",
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
                                    data.pickupAddress = '';
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
              heroTag: 'locate_me',
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
            heroTag: 'next',
            onPressed: _goToDestinationScreen,
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
