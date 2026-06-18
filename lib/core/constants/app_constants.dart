class AppConstants {
  static const String appName = 'PadelPro';

  static const List<int> slotDurations = [60, 90, 120];
  static const double minSkillLevel = 1.0;
  static const double maxSkillLevel = 7.0;
  static const int slotHoldMinutes = 5;
  static const int maxMatchPlayers = 4;

  static const String usersCollection = 'users';
  static const String venuesCollection = 'venues';
  static const String courtsSubcollection = 'courts';
  static const String slotsSubcollection = 'slots';
  static const String bookingsCollection = 'bookings';
  static const String openMatchesCollection = 'open_matches';

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
}
