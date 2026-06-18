import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/auth/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

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
            // Doc not yet written (race during registration) — return null so
            // the stream doesn't error out. signUp emits AuthAuthenticated directly.
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
    final uid = credential.user!.uid;
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      // Profile wasn't written at sign-up (e.g. rules were locked). Create it now.
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

  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
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
      createdAt: DateTime.now(),
    );

    // Write profile to Firestore. If this fails (e.g. rules not yet deployed)
    // we still return the user — the profile will be retried on next sign-in.
    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(user.toJson());
    } catch (e) {
      // Re-throw only if it's not a permission issue so the user still gets
      // logged in. The admin can fix rules and the profile will be written
      // on the next sign-in via signInWithEmailAndPassword.
      if (!e.toString().contains('permission-denied') &&
          !e.toString().contains('PERMISSION_DENIED')) {
        rethrow;
      }
    }

    return user;
  }

  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final uid = userCredential.uid;

    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) {
      final user = UserModel(
        uid: uid,
        email: userCredential.user!.email ?? '',
        displayName: userCredential.user!.displayName ?? googleUser.displayName ?? '',
        photoUrl: userCredential.user!.photoURL,
        createdAt: DateTime.now(),
      );
      await _db.collection(AppConstants.usersCollection).doc(uid).set(user.toJson());
      return user;
    }

    return UserModel.fromJson(doc.data()!);
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<UserModel> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    double? skillLevel,
    String? preferredSide,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (skillLevel != null) updates['skillLevel'] = skillLevel;
    if (preferredSide != null) updates['preferredSide'] = preferredSide;
    if (phone != null) updates['phone'] = phone;

    await _db.collection(AppConstants.usersCollection).doc(uid).update(updates);

    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }

    return _fetchUserModel(uid);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<UserModel> _fetchUserModel(String uid) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) throw Exception('User profile not found');
    return UserModel.fromJson(doc.data()!);
  }
}

extension on UserCredential {
  String get uid => user!.uid;
}
