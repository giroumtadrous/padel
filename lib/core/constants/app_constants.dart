class AppConstants {
  static const String appName = 'PadelPro';

  static const List<int> slotDurations = [60, 90, 120];
  static const double minSkillLevel = 1.0;
  static const double maxSkillLevel = 7.0;
  static const int slotHoldMinutes = 5;
  static const int maxMatchPlayers = 4;

  // Firestore collections
  static const String usersCollection = 'users';
  static const String venuesCollection = 'venues';
  static const String courtsSubcollection = 'courts';
  static const String slotsSubcollection = 'slots';
  static const String bookingsCollection = 'bookings';
  static const String openMatchesCollection = 'open_matches';
  static const String reviewsCollection = 'reviews';

  static const String rolePlayer = 'player';
  static const String roleAdmin = 'admin';

  static const String sideForerhand = 'forehand';
  static const String sideBackhand = 'backhand';

  static const String statusAvailable = 'available';
  static const String statusHeld = 'held';
  static const String statusBooked = 'booked';
  static const String statusMaintenance = 'maintenance';

  static const String bookingUpcoming = 'upcoming';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';

  static const String matchOpen = 'open';
  static const String matchFull = 'full';
  static const String matchCancelled = 'cancelled';
  static const String matchCompleted = 'completed';

  // Payment methods
  static const String paymentCard = 'card';
  static const String paymentVodafone = 'vodafone_cash';
  static const String paymentFawry = 'fawry';
  static const String paymentInstaPay = 'instapay';
  static const String paymentWallet = 'wallet';

  // Manual (non-instant) payment methods require photo proof + admin review.
  static const List<String> manualPaymentMethods = [
    paymentVodafone,
    paymentFawry,
    paymentInstaPay,
  ];

  // Payment (deposit) statuses
  static const String paymentPending = 'pending_verification';
  static const String paymentPaid = 'paid';
  static const String paymentRejected = 'rejected';

  // Deposit-based booking: a flat fee (EGP) per booked hour is paid in-app to
  // hold the slot; the full court price is paid separately in cash at the venue.
  static const double depositPerHour = 20.0;

  // Loyalty
  static const int loyaltyBookingsRequired = 5;
  static const double loyaltyDiscountPercent = 0.50;

  // Wallet top-up amounts
  static const List<double> walletTopUpAmounts = [100, 200, 500];
}
