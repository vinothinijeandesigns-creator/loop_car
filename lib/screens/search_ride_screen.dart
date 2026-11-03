import 'package:flutter/material.dart';
import 'available_rides_page.dart';
import '../services/ride_service.dart';
import '../services/ride_matching_engine.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import '../services/directions_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const RideApp());
}

enum ActiveField { start, drop }

class RideApp extends StatelessWidget {
  const RideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SearchRidePage(),
    );
  }
}

class SearchRidePage extends StatefulWidget {
  const SearchRidePage({super.key});

  @override
  State<SearchRidePage> createState() => _SearchRidePageState();
}

class _SearchRidePageState extends State<SearchRidePage> {
  Timer? _debounce;

  String? _startPlaceId;
  String? _dropPlaceId;

  maps.LatLng? _startLatLng;
  maps.LatLng? _dropLatLng;

  late final TextEditingController startController;
  late final TextEditingController dropController;
  late final TextEditingController timeController;

  late final FlutterGooglePlacesSdk placesSdk;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  int passengers = 1;
  ActiveField? _activeField;
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    startController = TextEditingController();
    dropController = TextEditingController();
    timeController = TextEditingController();
    // Correct initialization with your Android Places API key
    placesSdk = FlutterGooglePlacesSdk(
      "AIzaSyBCpxsn76dUIKuuENr4cIhjHsTCEcpG2ZA",
    );
    // Request location permission on startup after layout is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    startController.dispose();
    dropController.dispose();
    timeController.dispose();

    super.dispose();
  }

  Future<maps.LatLng?> _getLatLngFromPlaceId(String? placeId) async {
    if (placeId == null) return null;

    final response = await placesSdk.fetchPlace(
      placeId,
      fields: [PlaceField.Location],
    );

    final location = response.place?.latLng;
    if (location == null) return null;

    // ✅ Convert Places LatLng → Google Maps LatLng
    return maps.LatLng(location.lat, location.lng);
  }

  Future<void> _updateFromLatLng(
    maps.LatLng latLng,
    TextEditingController controller,
    ActiveField field,
  ) async {
    final placemarks = await placemarkFromCoordinates(
      latLng.latitude,
      latLng.longitude,
    );

    String address;

    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      
      // Prioritize readable location names
      List<String> parts = [];
      
      // 1. Neighborhood or specific place
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        parts.add(p.subLocality!);
      } else if (p.name != null && p.name!.isNotEmpty && !p.name!.contains('+')) {
        parts.add(p.name!);
      }
      
      // 2. City / District
      if (p.locality != null && p.locality!.isNotEmpty) {
        parts.add(p.locality!);
      } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
        parts.add(p.subAdministrativeArea!);
      }
      
      // 3. State
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }

      // Remove duplicates
      final uniqueParts = parts.toSet().toList();
      
      address = uniqueParts.join(', ');
      
      // Fallback if everything was filtered out
      if (address.isEmpty) {
        address =
            "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
      }
    } else {
      address =
          "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
    }

    controller.value = TextEditingValue(
      text: address,
      selection: const TextSelection.collapsed(offset: 0),
    );

    if (field == ActiveField.start) {
      _startLatLng = latLng;
      _startPlaceId = null;
    } else {
      _dropLatLng = latLng;
      _dropPlaceId = null;
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
      final now = DateTime.now();
      final dateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      timeController.text = DateFormat('hh:mm a').format(dateTime);
    }
  }

  void _onPlaceChanged(TextEditingController controller) {
    if (_activeField == null) return;

    _debounce?.cancel();

    final query = controller.text.trim();

    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    // 👇 ADD THIS LINE
    final currentQuery = query;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isLoading = true);

      try {
        final response = await placesSdk.findAutocompletePredictions(
          currentQuery,
          countries: ["IN"],
        );

        // 👇 ADD THIS CHECK
        if (!mounted || controller.text.trim() != currentQuery) return;

        setState(() {
          _predictions = response.predictions;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    });
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services in your device settings.')));
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission was denied.')));
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission is permanently denied, please enable it in settings.')));
      }
      return null;
    }

    try {
      // First try to get the last known position for a quick response
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      
      // If no last known position, try getting current with a timeout
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      return null;
    }
  }

  /// Opens map picker
  Future<void> _openMapPicker(
    TextEditingController controller,
    ActiveField field,
  ) async {
    maps.LatLng? initialLatLng;

    if (field == ActiveField.start) {
      initialLatLng =
          _startLatLng ?? await _getLatLngFromPlaceId(_startPlaceId);
    } else {
      initialLatLng = _dropLatLng ?? await _getLatLngFromPlaceId(_dropPlaceId);
    }

    if (initialLatLng == null) {
      try {
        final position = await _getCurrentLocation();
        if (position != null) {
          initialLatLng = maps.LatLng(position.latitude, position.longitude);
        }
      } catch (e) {
        // ignore
      }
    }

    if (initialLatLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Showing default location. Tap the location button on the map or search for your location.'),
          ),
        );
      }
      initialLatLng = const maps.LatLng(20.5937, 78.9629);
    }

    if (!mounted) return;

    final result = await Navigator.push<maps.LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPlacePicker(initialPosition: initialLatLng!),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _updateFromLatLng(result, controller, field);
    }

    setState(() => _activeField = null);
  }

  Widget _buildPlaceField(
    String hint,
    TextEditingController controller,
    ActiveField field,
  ) {
    final isActive = _activeField == field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) {
            return TextField(
              controller: controller,
              onTap: () {
                setState(() => _activeField = field);
              },
              onChanged: (_) => _onPlaceChanged(controller),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                hintText: hint,
                filled: true,
                fillColor: Colors.grey.shade300,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),

                // 👇 suffix icons NOW react to text changes
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          controller.clear();
                          setState(() {
                            _predictions = [];
                            if (field == ActiveField.start) {
                              _startPlaceId = null;
                              _startLatLng = null;
                            } else if (field == ActiveField.drop) {
                              _dropPlaceId = null;
                              _dropLatLng = null;
                            }
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: () async {
                        _activeField = field;
                        await _openMapPicker(controller, field);
                        if (!mounted) return;
                        setState(() {
                          _predictions = [];
                          _activeField = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // 👇 Suggestions BELOW the active field
        if (isActive && (_isLoading || _predictions.isNotEmpty))
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child:
                _isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (_, index) {
                        final p = _predictions[index];
                        return ListTile(
                          title: Text(p.fullText),
                          onTap: () {
                            controller.text = p.fullText;
                            if (_activeField == ActiveField.start) {
                              _startPlaceId = p.placeId;
                              _startLatLng = null;
                            } else if (_activeField == ActiveField.drop) {
                              _dropPlaceId = p.placeId;
                              _dropLatLng = null;
                            }
                            setState(() {
                              _predictions = [];
                              _activeField = null;
                            });
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
          ),
      ],
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: () async {
        await _pickTime();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time),
            const SizedBox(width: 10),
            Text(
              selectedTime.format(context),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 10),
            Text(DateFormat('EEE, dd MMM').format(selectedDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              if (passengers > 1) setState(() => passengers--);
            },
          ),
          Text(passengers.toString()),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => passengers++),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch() async {
    if (startController.text.isEmpty || dropController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and drop locations'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_startLatLng == null && _startPlaceId == null) {
        // First try to look up in our local major stops list to avoid geocoding errors (like Mathur resolving to Chennai)
        final localMatch = DirectionsService.getStopoverLocation(startController.text);
        if (localMatch != null) {
          _startLatLng = maps.LatLng(localMatch.latitude, localMatch.longitude);
        } else {
          try {
            final locations = await locationFromAddress(startController.text);
            if (locations.isNotEmpty) {
              _startLatLng = maps.LatLng(locations.first.latitude, locations.first.longitude);
            }
          } catch (e) {
            // ignore
          }
        }
      }

      if (_startLatLng == null && _startPlaceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find starting location. Please select from suggestions or map.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      if (_dropLatLng == null && _dropPlaceId == null) {
        // Look up local major stops
        final localMatch = DirectionsService.getStopoverLocation(dropController.text);
        if (localMatch != null) {
          _dropLatLng = maps.LatLng(localMatch.latitude, localMatch.longitude);
        } else {
          try {
            final locations = await locationFromAddress(dropController.text);
            if (locations.isNotEmpty) {
              _dropLatLng = maps.LatLng(locations.first.latitude, locations.first.longitude);
            }
          } catch (e) {
            // ignore
          }
        }
      }

      if (_dropLatLng == null && _dropPlaceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find drop location. Please select from suggestions or map.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      // Ensure we have coordinates if selected via autocomplete
      if (_startLatLng == null && _startPlaceId != null) {
        _startLatLng = await _getLatLngFromPlaceId(_startPlaceId);
      }
      if (_dropLatLng == null && _dropPlaceId != null) {
        _dropLatLng = await _getLatLngFromPlaceId(_dropPlaceId);
      }

      final rideService = RideService();
      List<Map<String, dynamic>> results;

      if (_startLatLng != null && _dropLatLng != null) {
        // Use basic search + local matching for strict Stopover routing logic.
        results = await rideService.searchRidesBasic(
          departureDate: selectedDate,
          seats: passengers,
        );
        
        // Apply Stopover Match Logic!
        results = RideMatchingEngine.filterMatchingRides(
          availableRides: results,
          startLat: _startLatLng?.latitude,
          startLng: _startLatLng?.longitude,
          dropLat: _dropLatLng?.latitude,
          dropLng: _dropLatLng?.longitude,
          startQuery: startController.text,
          dropQuery: dropController.text,
          requiredSeats: passengers,
        );
      } else {
        // Fallback to basic search if we still don't have coordinates (shouldn't happen now)
        results = await rideService.searchRidesBasic(
          departureDate: selectedDate,
          seats: passengers,
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => AvailableRidesPage(
                rides: results,
                startLocation: startController.text,
                endLocation: dropController.text,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching rides: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "Ride, Laugh, Repeat, For Less!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildPlaceField(
                    "Starting from",
                    startController,
                    ActiveField.start,
                  ),
                  const SizedBox(height: 12),
                  _buildPlaceField(
                    "Drop point",
                    dropController,
                    ActiveField.drop,
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(),
                  const SizedBox(height: 12),
                  _buildTimeField(),
                  const SizedBox(height: 12),
                  _buildPassengerField(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C6D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              "Search a Ride",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map Picker Widget
class MapPlacePicker extends StatefulWidget {
  final maps.LatLng initialPosition;
  const MapPlacePicker({super.key, required this.initialPosition});

  @override
  State<MapPlacePicker> createState() => _MapPlacePickerState();
}

class _MapPlacePickerState extends State<MapPlacePicker> {
  late maps.LatLng selectedPosition;
  late maps.GoogleMapController _mapController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedPosition = widget.initialPosition;
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final newLatLng = maps.LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          selectedPosition = newLatLng;
          _isSearching = false;
        });
        _mapController.animateCamera(maps.CameraUpdate.newLatLngZoom(newLatLng, 16));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find location')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search location...',
                  border: InputBorder.none,
                ),
                onSubmitted: _searchLocation,
              )
            : const Text("Pick a location"),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: maps.GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          _mapController = controller;

          // ✅ BEST FIX: animate camera AFTER map loads
          _mapController.animateCamera(
            maps.CameraUpdate.newLatLngZoom(
              selectedPosition,
              16, // perfect zoom for address picking
            ),
          );
        },
        initialCameraPosition: maps.CameraPosition(
          target: widget.initialPosition,
          zoom: 14, // fallback only
        ),
        onTap: (latLng) async {
          setState(() {
            selectedPosition = latLng;
          });
          _mapController.animateCamera(maps.CameraUpdate.newLatLng(latLng));
        },
        markers: {
          maps.Marker(
            markerId: const maps.MarkerId("selected"),
            position: selectedPosition,
          ),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, selectedPosition);
        },
        label: const Text("Confirm location"),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
