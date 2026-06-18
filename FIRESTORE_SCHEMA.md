# Firestore Schema — PadelPro

## Design Principles
- **Read cost minimisation**: denormalise `venueName`, `courtName` into bookings/slots to avoid extra reads on list views.
- **Real-time slots**: slots live as a subcollection of each court, partitioned by date string (`yyyy-MM-dd`), enabling cheap real-time listeners per court-per-day.
- **Hold/lock pattern**: a 5-minute optimistic lock via Firestore Transaction before payment prevents double-booking.
- **Security**: Firestore Rules enforce that only the document owner or an admin can write. Admin role is stored on the `users` document.

---

## Collections

### `users/{userId}`
Stores both player profiles and admin accounts.

```
users/{userId}
├── uid            : String         — matches Firebase Auth UID
├── email          : String
├── displayName    : String
├── photoUrl       : String?
├── role           : 'player' | 'admin'
├── skillLevel     : Number         — 1.0–7.0 (padel rating convention)
├── preferredSide  : 'forehand' | 'backhand'
├── matchesPlayed  : Number
├── phone          : String?
├── managedVenueIds: String[]       — only populated for role='admin'
└── createdAt      : Timestamp
```

---

### `venues/{venueId}`
Padel club/venue listing. Courts are a subcollection.

```
venues/{venueId}
├── id             : String
├── name           : String
├── description    : String
├── address        : String
├── city           : String
├── latitude       : Number
├── longitude      : Number
├── imageUrls      : String[]
├── amenities      : Map
│   ├── hasShowers       : Boolean
│   ├── hasRacketRental  : Boolean
│   ├── hasParking       : Boolean
│   └── hasCafe          : Boolean
├── openingHour    : Number         — e.g. 7  (7 AM)
├── closingHour    : Number         — e.g. 23 (11 PM)
├── rating         : Number         — 0.0–5.0
├── reviewCount    : Number
├── adminId        : String         — uid of the managing admin
├── isActive       : Boolean
└── createdAt      : Timestamp
```

---

### `venues/{venueId}/courts/{courtId}`
Individual courts. Subcollection of venue.

```
courts/{courtId}
├── id             : String
├── venueId        : String         — denormalised for top-level queries
├── name           : String         — e.g. "Court 1", "Glass Court A"
├── courtType      : 'indoor' | 'outdoor'
├── surface        : 'glass' | 'turf'
├── imageUrl       : String?
├── peakHourPrice  : Number         — price per 60-min slot (peak)
├── offPeakPrice   : Number         — price per 60-min slot (off-peak)
├── peakStartHour  : Number         — e.g. 17 (5 PM)
├── peakEndHour    : Number         — e.g. 22 (10 PM)
├── isActive       : Boolean
└── maintenanceNote: String?
```

---

### `venues/{venueId}/courts/{courtId}/slots/{date}/{slotId}`
Real-time slot availability. Two-level subcollection: court → date → slots.

```
slots/{date}/{slotId}
├── id             : String         — "{courtId}_{date}_{HHmm}"
├── courtId        : String
├── venueId        : String
├── date           : String         — "yyyy-MM-dd"
├── startTime      : Timestamp
├── endTime        : Timestamp
├── durationMinutes: Number         — 60 | 90 | 120
├── status         : 'available' | 'held' | 'booked' | 'maintenance'
├── price          : Number         — computed at slot creation
├── isPeakHour     : Boolean
├── bookingId      : String?        — set atomically when booked
├── heldBy         : String?        — userId holding the slot
└── heldUntil      : Timestamp?     — lock expires after 5 minutes
```

**Booking Transaction Flow:**
1. `READ` slot document inside a Transaction.
2. Assert `status == 'available'`.
3. `WRITE` `status = 'held'`, `heldBy = userId`, `heldUntil = now + 5 min`.
4. On payment confirmation → second Transaction: `status = 'booked'`, `bookingId = newId`.
5. Cloud Function (scheduled) cleans up expired `held` slots every minute.

---

### `bookings/{bookingId}`
Confirmed reservations.

```
bookings/{bookingId}
├── id             : String
├── userId         : String
├── courtId        : String
├── venueId        : String
├── venueName      : String         — denormalised
├── courtName      : String         — denormalised
├── slotId         : String
├── date           : String
├── startTime      : Timestamp
├── endTime        : Timestamp
├── durationMinutes: Number
├── totalPrice     : Number
├── status         : 'upcoming' | 'completed' | 'cancelled'
├── isOpenMatch    : Boolean
├── openMatchId    : String?
├── paymentStatus  : 'pending' | 'paid' | 'refunded'
├── createdAt      : Timestamp
└── cancelledAt    : Timestamp?
```

**Indexes required:**
- `userId + status + startTime` (booking history, sorted)
- `venueId + date + status` (admin daily view)

---

### `open_matches/{matchId}`
Community open match listings. Created when a player opens their booked court to others.

```
open_matches/{matchId}
├── id             : String
├── bookingId      : String
├── courtId        : String
├── venueId        : String
├── venueName      : String         — denormalised
├── courtName      : String         — denormalised
├── organizerId    : String
├── organizerName  : String         — denormalised
├── date           : String
├── startTime      : Timestamp
├── endTime        : Timestamp
├── totalSlots     : Number         — always 4 (padel is 4-player)
├── filledSlots    : Number         — incremented atomically on join
├── participantIds : String[]
├── minSkillLevel  : Number         — minimum required skill rating
├── maxSkillLevel  : Number         — maximum allowed skill rating
├── pricePerPlayer : Number         — totalPrice / totalSlots
├── description    : String
├── status         : 'open' | 'full' | 'cancelled' | 'completed'
└── createdAt      : Timestamp
```

**Indexes required:**
- `status + startTime` (browse open matches)
- `status + minSkillLevel + startTime` (filtered skill-level browse)
- `organizerId + status` (my open matches)

---

## Security Rules Summary

```
/users/{uid}        — read: authenticated; write: uid == request.auth.uid || admin
/venues/{venueId}   — read: all; write: admin of venue || super-admin
/courts/{courtId}   — read: all; write: venue admin
/slots/{...}        — read: authenticated; write: via Cloud Function / Transaction only
/bookings/{id}      — read: booking.userId == auth.uid || admin; write: booking.userId == auth.uid
/open_matches/{id}  — read: authenticated; write: organizer || admin
```
