class Ride {
  final String id;
  final String driverId;
  final String hostName;
  final String hostPhone;
  final String hostImage;
  final double rating;
  final int price;
  final String pickup;
  final String drop;
  final String carName;
  final String carColor;
  final String time;
  final int seats;
  
  // Preferences
  final bool instantBooking;
  final bool maxTwoInBack;
  final bool luggageAllowed;
  final bool petsAllowed;
  final bool smokingAllowed;

  Ride({
    required this.id,
    required this.driverId,
    required this.hostName,
    required this.hostPhone,
    required this.hostImage,
    required this.rating,
    required this.price,
    required this.pickup,
    required this.drop,
    required this.carName,
    required this.carColor,
    required this.time,
    required this.seats,
    this.instantBooking = true,
    this.maxTwoInBack = true,
    this.luggageAllowed = true,
    this.petsAllowed = false,
    this.smokingAllowed = false,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime time;
  final bool seen;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.time,
    this.seen = false,
  });
}
