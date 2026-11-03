class PricingService {
  /// Calculate the recommended price per seat based on BlaBlaCar's peer-to-peer model.
  /// The driver does not make a profit; costs are shared among passengers.
  /// 
  /// [distanceKm] - Total distance of the ride in kilometers
  /// [fuelMileageKmPerLiter] - Vehicle's fuel efficiency (e.g., 15 km/l)
  /// [fuelPricePerLiter] - Current price of fuel per liter
  /// [tollCharges] - Total toll charges for the trip
  /// [maintenanceCostPerKm] - Estimated maintenance (wear & tear) per km
  /// [availableSeats] - Number of seats available for passengers
  static Map<String, dynamic> calculatePrice({
    required double distanceKm,
    required double fuelMileageKmPerLiter,
    required double fuelPricePerLiter,
    required double tollCharges,
    required double maintenanceCostPerKm,
    required int availableSeats,
  }) {
    if (availableSeats <= 0) {
      throw ArgumentError('Available seats must be greater than 0');
    }

    // 1. Calculate Fuel Cost
    // (Distance / Mileage) * Fuel Price
    double fuelCost = (distanceKm / fuelMileageKmPerLiter) * fuelPricePerLiter;

    // 2. Calculate Maintenance Cost (Wear & Tear)
    double maintenanceCost = distanceKm * maintenanceCostPerKm;

    // 3. Total Trip Cost
    double totalTripCost = fuelCost + tollCharges + maintenanceCost;

    // 4. Calculate Recommended Price Per Seat
    // As per BlaBlaCar model, driver also pays their share. Assume average car has 4 people (1 driver + 3 passengers)
    // We divide total cost by 4 to get a fair price per person, so passengers aren't penalized if driver only offers 1 seat.
    double recommendedPricePerSeat = totalTripCost / 4.0;

    // 5. Min and Max limits to prevent drivers from making a profit
    // Allowed to reduce by 50% or increase by a very small margin (e.g., 10%)
    double minPrice = recommendedPricePerSeat * 0.5;
    double maxPrice = recommendedPricePerSeat * 1.1; 

    return {
      'totalTripCost': totalTripCost.roundToDouble(),
      'fuelCost': fuelCost.roundToDouble(),
      'maintenanceCost': maintenanceCost.roundToDouble(),
      'tollCharges': tollCharges,
      'recommendedPrice': recommendedPricePerSeat.roundToDouble(),
      'minPrice': minPrice.roundToDouble(),
      'maxPrice': maxPrice.roundToDouble(),
    };
  }

  /// Helper to calculate price with default conservative estimates for India
  /// [distanceKm] - Total distance in km
  /// [availableSeats] - Number of passenger seats
  static Map<String, dynamic> calculateDefaultPrice({
    required double distanceKm,
    required int availableSeats,
    double tollCharges = 0.0,
  }) {
    // Default estimates (can be adjusted based on real-time data or vehicle type)
    const defaultFuelMileage = 15.0; // 15 km/l
    const defaultFuelPrice = 105.0; // ₹105 per liter
    const defaultMaintenanceCost = 2.0; // ₹2 per km

    return calculatePrice(
      distanceKm: distanceKm,
      fuelMileageKmPerLiter: defaultFuelMileage,
      fuelPricePerLiter: defaultFuelPrice,
      tollCharges: tollCharges,
      maintenanceCostPerKm: defaultMaintenanceCost,
      availableSeats: availableSeats,
    );
  }
}
