import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';

class PostRideData {
  LatLng? pickup;
  LatLng? destination;
  String pickupAddress = '';
  String destinationAddress = '';
  double distance = 0.0; // In kilometers
  List<StopoverDistrict> selectedStopovers = [];

  // New fields for ride posting
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int seats = 1;
  double pricePerSeat = 0.0;
}
