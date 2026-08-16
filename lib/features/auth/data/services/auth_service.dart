import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/booking/data/models/booking_model.dart';
import 'package:padel/features/auth/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  // Set when a Google/Apple sign-in fails because the email is already tied
  // to a different provider. Linked automatically the next time the user
  // successfully signs in (with any method), so the two accounts merge
  // instead of staying stuck.
  AuthCredential? _pendingLinkCredential;
  String? _pendingLinkEmail;

  String? get pendingLinkEmail => _pendingLinkEmail;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Stream<UserModel?> get authStateChanges => _auth.authStateChanges().asyncMap(
        (firebaseUser) async {
          if (firebaseUser == null) return null;
          try {
            return await _fetchUserModel(firebaseUser.uid);
          } catch (_) {
            return null;
          }
        },
      );

  Future<UserModel?> get currentUser async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _fetchUserModel(firebaseUser.uid);
  }

  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _linkPendingCredentialIfAny();
    final uid = credential.user!.uid;
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        email: email,
        displayName: credential.user!.displayName ?? email.split('@').first,
        photoUrl: credential.user!.photoURL,
        createdAt: DateTime.now(),
      );
      await _db.collection(AppConstants.usersCollection).doc(uid).set(user.toJson());
      return user;
    }
    return UserModel.fromJson(doc.data()!);
  }

  /// Links a previously-blocked Google/Apple credential to whichever account
  /// just signed in successfully. Firebase refuses to auto-merge accounts
  /// across providers for the same email (anti-takeover protection), so this
  /// is the recovery step: once the user proves ownership via any method,
  /// we attach the other provider to that same account.
  Future<void> _linkPendingCredentialIfAny() async {
    final cred = _pendingLinkCredential;
    if (cred == null) return;
    _pendingLinkCredential = null;
    _pendingLinkEmail = null;
    try {
      await _auth.currentUser?.linkWithCredential(cred);
    } catch (_) {
      // Best-effort — if it's already linked elsewhere, or the email doesn't
      // match, just leave it for the user to try signing in again.
    }
  }

  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required double skillLevel,
    required String preferredSide,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);

    final user = UserModel(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      skillLevel: skillLevel,
      preferredSide: preferredSide,
      createdAt: DateTime.now(),
    );

    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(user.toJson());
    } catch (e) {
      if (!e.toString().contains('permission-denied') &&
          !e.toString().contains('PERMISSION_DENIED')) {
        rethrow;
      }
    }

    return user;
  }

  Future<UserModel> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('Apple sign-in is only available on iOS.');
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.trim().isEmpty) {
      throw Exception('Apple sign-in did not return an identity token. Please try again.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );

    final UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pendingLinkCredential = oauthCredential;
        _pendingLinkEmail = e.email;
      }
      rethrow;
    }
    await _linkPendingCredentialIfAny();
    final uid = userCredential.user!.uid;

    final displayName = userCredential.user!.displayName ??
        [appleCredential.givenName, appleCredential.familyName]
            .whereType<String>()
            .join(' ')
            .trim();

    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        email: userCredential.user!.email ?? appleCredential.email ?? '',
        displayName: displayName.isNotEmpty ? displayName : 'Player',
        photoUrl: userCredential.user!.photoURL,
        preferredSide: '',
        skillLevel: 0.0,
        createdAt: DateTime.now(),
      );
      await _db.collection(AppConstants.usersCollection).doc(uid).set(user.toJson());
      return user;
    }

    return UserModel.fromJson(doc.data()!);
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<UserModel> signInWithGoogle() async {
    UserCredential userCredential;
    AuthCredential? googleCredential;

    try {
      if (kIsWeb) {
        // The google_sign_in plugin's imperative popup flow isn't supported on
        // web (it now requires Google Identity Services' rendered button), so
        // go through FirebaseAuth's own popup instead. (No standalone
        // credential object to cache for later linking on this path.)
        userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // Without this, google_sign_in can silently reuse whatever Google
        // account was cached from a previous sign-in (on this device, or by
        // another app sharing the same Google session) instead of showing
        // the account picker — the "random email" symptom. Clearing the
        // cached selection first forces the picker to show every time.
        try {
          await _googleSignIn.disconnect();
        } catch (_) {
          try {
            await _googleSignIn.signOut();
          } catch (_) {
            // Nothing cached to clear — fine, proceed to sign-in.
          }
        }

        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) throw Exception('Google sign-in cancelled');

        final googleAuth = await googleUser.authentication;
        googleCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(googleCredential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pendingLinkCredential = googleCredential;
        _pendingLinkEmail = e.email;
      }
      rethrow;
    }
    await _linkPendingCredentialIfAny();

    final uid = userCredential.uid;

    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        email: userCredential.user!.email ?? '',
        displayName: userCredential.user!.displayName ?? '',
        photoUrl: userCredential.user!.photoURL,
        preferredSide: '',
        skillLevel: 0.0,
        createdAt: DateTime.now(),
      );
      await _db.collection(AppConstants.usersCollection).doc(uid).set(user.toJson());
      return user;
    }

    return UserModel.fromJson(doc.data()!);
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
    } else {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    }
  }

  /// Re-authenticates the current user before a sensitive operation such as
  /// deleting the account. Firebase blocks `user.delete()` when the login is
  /// stale, so this refreshes the session first.
  Future<void> reauthenticateForDeletion({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final providerIds = user.providerData.map((provider) => provider.providerId).toSet();

    if (providerIds.contains('password')) {
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw Exception('This account does not have an email address for re-authentication.');
      }
      if (password == null || password.isEmpty) {
        throw Exception('Password is required to delete this account.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }

    if (providerIds.contains('google.com')) {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return;
      }

      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return;
    }

    if (providerIds.contains('apple.com')) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        throw Exception('Apple re-authentication is only available on iOS.');
      }

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.trim().isEmpty) {
        throw Exception('Apple sign-in did not return an identity token. Please try again.');
      }

      await user.reauthenticateWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: identityToken,
          rawNonce: rawNonce,
        ),
      );
      return;
    }

    throw Exception('Please sign in again before deleting this account.');
  }

  /// Deletes the current Firebase Auth account and removes or anonymizes the
  /// associated Firestore records.
  Future<void> deleteCurrentAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    await reauthenticateForDeletion(password: password);
    final uid = user.uid;

    await _deleteAssociatedUserData(uid);
    await user.delete();
    await signOut();
  }

  Future<UserModel> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    String? preferredSide,
    String? phone,
    double? skillLevel,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (preferredSide != null) updates['preferredSide'] = preferredSide;
    if (phone != null) updates['phone'] = phone;
    if (skillLevel != null) updates['skillLevel'] = skillLevel;

    await _db.collection(AppConstants.usersCollection).doc(uid).update(updates);

    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }

    return _fetchUserModel(uid);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Sends an SMS OTP to [phoneNumber]. Callback-based because
  /// `FirebaseAuth.verifyPhoneNumber` itself is callback-based (it may
  /// auto-resolve on Android via SMS retriever before `codeSent` even fires).
  Future<void> sendPhoneVerificationCode(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: (e) => onFailed(e.message ?? 'Phone verification failed'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  /// Links the OTP-verified phone number to the current account and marks
  /// [UserModel.phoneVerified] on the Firestore user doc.
  ///
  /// If this phone number is already verified on a *different* account (e.g.
  /// the user previously tested email/password sign-up with the same number,
  /// then later signed in with Google), we don't just fail: the OTP itself is
  /// proof the caller owns that phone number, so we sign them straight into
  /// the existing account instead. That guarantees one verified phone number
  /// always maps to exactly one account, regardless of how many sign-in
  /// methods (email/Google/Apple) a person has tried.
  Future<UserModel> confirmPhoneVerificationCode({
    required String verificationId,
    required String smsCode,
    required String uid,
    required String phoneNumber,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final alreadyLinked = user.providerData.any((p) => p.providerId == 'phone');
    String activeUid = uid;
    if (!alreadyLinked) {
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // Both codes mean the same thing here: this phone number is already
        // verified on a different account. (Firebase's own linkWithCredential
        // docs promise `credential-already-in-use`, but some SDK/plugin
        // versions surface phone-linking conflicts as
        // `account-exists-with-different-credential` instead — handle both
        // the same way rather than depending on which one shows up.)
        if (e.code == 'credential-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          // signInWithCredential fully replaces the current session in one
          // atomic step (no intermediate signed-out state), so this doesn't
          // bounce the user back to the login screen.
          final existingUserCredential = await _auth.signInWithCredential(credential);
          activeUid = existingUserCredential.user!.uid;
        } else {
          throw Exception(_friendlyPhoneLinkError(e));
        }
      }
    }

    await _db.collection(AppConstants.usersCollection).doc(activeUid).update({
      'phone': phoneNumber,
      'phoneVerified': true,
    });

    return _fetchUserModel(activeUid);
  }

  /// Marks phone verification as skipped so the router stops gating the app
  /// behind it — remembered permanently until the user verifies from Profile.
  Future<UserModel> skipPhoneVerification(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'phoneVerificationSkipped': true,
    });
    return _fetchUserModel(uid);
  }

  String _friendlyPhoneLinkError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'That code is incorrect. Please check it and try again.';
      case 'session-expired':
      case 'invalid-verification-id':
        return 'This code has expired. Tap "Resend code" and try again.';
      case 'provider-already-linked':
        return 'This account already has a verified phone number.';
      default:
        return e.message ?? 'Could not verify this code. Please try again.';
    }
  }

  /// Toggles a venue in/out of the user's favorites list.
  Future<UserModel> toggleFavorite(String uid, String venueId) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');

    final user = UserModel.fromJson(doc.data()!);
    final favs = List<String>.from(user.favoriteVenueIds);

    if (favs.contains(venueId)) {
      favs.remove(venueId);
    } else {
      favs.add(venueId);
    }

    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'favoriteVenueIds': favs});

    return _fetchUserModel(uid);
  }

  /// Tops up wallet balance by [amount].
  Future<UserModel> topUpWallet(String uid, double amount) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'walletBalance': FieldValue.increment(amount),
    });
    return _fetchUserModel(uid);
  }

  /// Deducts [amount] from wallet balance. Throws if insufficient funds.
  Future<UserModel> deductWallet(String uid, double amount) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');

    final user = UserModel.fromJson(doc.data()!);
    if (user.walletBalance < amount) throw Exception('Insufficient wallet balance');

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'walletBalance': FieldValue.increment(-amount),
    });
    return _fetchUserModel(uid);
  }

  /// Records a loyalty booking. Sets eligible=true when count reaches a multiple of 5.
  Future<UserModel> recordLoyaltyBooking(String uid) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');

    final user = UserModel.fromJson(doc.data()!);
    final newCount = user.loyaltyBookingCount + 1;
    final eligible = newCount % AppConstants.loyaltyBookingsRequired == 0;

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'loyaltyBookingCount': newCount,
      'loyaltyDiscountEligible': eligible,
    });

    return _fetchUserModel(uid);
  }

  /// Resets loyalty discount eligibility after it has been used.
  Future<UserModel> consumeLoyaltyDiscount(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'loyaltyDiscountEligible': false,
    });
    return _fetchUserModel(uid);
  }

  /// Saves FCM token to user document.
  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'fcmToken': token,
    });
  }

  Future<void> _deleteAssociatedUserData(String uid) async {
    await Future.wait([
      _deleteDocumentsWhereFieldEquals(
        collectionPath: AppConstants.notificationsCollection,
        field: 'userId',
        value: uid,
      ),
      _deleteDocumentsWhereFieldEquals(
        collectionPath: AppConstants.skillRequestsCollection,
        field: 'userId',
        value: uid,
      ),
      _deleteDocumentsWhereFieldEquals(
        collectionPath: AppConstants.reviewsCollection,
        field: 'userId',
        value: uid,
      ),
      _anonymizeBookings(uid),
      _cleanupOpenMatches(uid),
      _cleanupMarketItems(uid),
      _db.collection(AppConstants.usersCollection).doc(uid).delete(),
    ]);
  }

  Future<void> _deleteDocumentsWhereFieldEquals({
    required String collectionPath,
    required String field,
    required String value,
  }) async {
    while (true) {
      final snap = await _db
          .collection(collectionPath)
          .where(field, isEqualTo: value)
          .limit(250)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _anonymizeBookings(String uid) async {
    final snap = await _db
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: uid)
        .get();

    for (final doc in snap.docs) {
      final booking = BookingModel.fromJson({...doc.data(), 'id': doc.id});
      if (booking.status == BookingStatus.upcoming && booking.startTime.isAfter(DateTime.now())) {
        await _cancelBookingAndReleaseSlots(booking);
      }

      await doc.reference.update({
        'userId': AppConstants.deletedAccountUserId,
      });
    }
  }

  Future<void> _cleanupOpenMatches(String uid) async {
    final organizerSnap = await _db
        .collection(AppConstants.openMatchesCollection)
        .where('organizerId', isEqualTo: uid)
        .get();

    for (final doc in organizerSnap.docs) {
      await doc.reference.delete();
    }

    final participantSnap = await _db
        .collection(AppConstants.openMatchesCollection)
        .where('participantIds', arrayContains: uid)
        .get();

    for (final doc in participantSnap.docs) {
      final data = doc.data();
      if ((data['organizerId'] as String? ?? '') == uid) continue;

      final participantIds = List<String>.from(data['participantIds'] as List? ?? []);
      participantIds.remove(uid);
      final totalSlots = data['totalSlots'] as int? ?? AppConstants.maxMatchPlayers;
      final updatedFilledSlots = (data['filledSlots'] as int? ?? 1) - 1;

      await doc.reference.update({
        'participantIds': participantIds,
        'filledSlots': updatedFilledSlots < 1 ? 1 : updatedFilledSlots,
        'status': updatedFilledSlots >= totalSlots ? AppConstants.matchFull : AppConstants.matchOpen,
      });
    }
  }

  Future<void> _cleanupMarketItems(String uid) async {
    final snap = await _db
        .collection(AppConstants.marketItemsCollection)
        .where('sellerId', isEqualTo: uid)
        .get();

    for (final doc in snap.docs) {
      await doc.reference.update({
        'status': AppConstants.marketItemRemoved,
        'sellerId': AppConstants.deletedAccountUserId,
        'sellerName': AppConstants.deletedAccountDisplayName,
      });
    }
  }

  Future<void> _cancelBookingAndReleaseSlots(BookingModel booking) async {
    final bookingRef = _db.collection(AppConstants.bookingsCollection).doc(booking.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(bookingRef);
      if (!snap.exists) return;

      tx.update(bookingRef, {
        'status': AppConstants.bookingCancelled,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });

      for (final slotId in booking.slotIds) {
        final slotRef = _db
            .collection(AppConstants.venuesCollection)
            .doc(booking.venueId)
            .collection(AppConstants.courtsSubcollection)
            .doc(booking.courtId)
            .collection(AppConstants.slotsSubcollection)
            .doc(booking.date)
            .collection('times')
            .doc(slotId);

        tx.update(slotRef, {
          'status': AppConstants.statusAvailable,
          'bookingId': null,
        });
      }
    });
  }

  Future<UserModel> _fetchUserModel(String uid) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');
    return UserModel.fromJson(doc.data()!);
  }
}

extension on UserCredential {
  String get uid => user!.uid;
}
