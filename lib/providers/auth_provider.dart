// lib/providers/auth_provider.dart  ← FULLY FIXED VERSION
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES FROM ORIGINAL (all marked with ← FIX):
//
//  1. register()       — added phoneNumber, location, serviceType, kycStatus fields
//  2. loginWithGoogle()— added phoneNumber, location, serviceType, kycStatus fields
//  3. submitKyc()      — renamed kycData→kycDocuments, status→kycStatus:'pending',
//                        kycDone stays false until approved, added kycSubmittedAt
//  4. skipKyc()        — added kycStatus:'not_submitted'
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/helper_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth      _auth   = FirebaseAuth.instance;
  final FirebaseFirestore _db     = FirebaseFirestore.instance;
  final GoogleSignIn      _google = GoogleSignIn(scopes: ['email', 'profile']);

  HelperModel? _helper;
  String?      _errorMessage;
  bool         _isLoading   = false;
  bool         _initialized = false;
  int          _unreadCount = 0;

  StreamSubscription<User?>?            _authSub;
  StreamSubscription<DocumentSnapshot>? _helperSub;
  StreamSubscription<QuerySnapshot>?    _notifSub;

  HelperModel? get helper        => _helper;
  String?      get errorMessage  => _errorMessage;
  bool         get isLoading     => _isLoading;
  bool         get initialized   => _initialized;
  bool         get isLoggedIn    => _auth.currentUser != null && _helper != null;
  int          get unreadCount   => _unreadCount;

  AuthProvider() { _init(); }

  // ── Boot ──────────────────────────────────────────────────────
  void _init() {
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _cancelStreams();
        _helper      = null;
        _initialized = true;
        notifyListeners();
      } else {
        await _fetchHelper(user.uid);
        _subscribeNotifications(user.uid);
        _initialized = true;
        notifyListeners();
      }
    });
  }

  // ── Fetch + stream helper doc ─────────────────────────────────
  Future<void> _fetchHelper(String uid) async {
    try {
      await _helperSub?.cancel();
      final doc = await _db.collection('helpers').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _helper = HelperModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
      _helperSub = _db.collection('helpers').doc(uid).snapshots().listen(
            (snap) {
          if (snap.exists && snap.data() != null) {
            _helper = HelperModel.fromMap(snap.data()!, snap.id);
            notifyListeners();
          }
        },
        onError: (e) => debugPrint('helperSub: $e'),
      );
    } catch (e) {
      debugPrint('_fetchHelper: $e');
      _errorMessage = _friendlyError(e);
    }
  }

  // ── Notifications ─────────────────────────────────────────────
  void _subscribeNotifications(String uid) {
    _notifSub?.cancel();
    _notifSub = _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((s) { _unreadCount = s.docs.length; notifyListeners(); },
        onError: (e) => debugPrint('notifSub: $e'));
  }

  Future<void> markAllNotificationsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('notifications').doc(uid).collection('items')
          .where('read', isEqualTo: false).get();
      final batch = _db.batch();
      for (final d in snap.docs) batch.update(d.reference, {'read': true});
      await batch.commit();
    } catch (_) {}
  }

  // ── Refresh ───────────────────────────────────────────────────
  Future<void> refreshProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('helpers').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _helper = HelperModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
    } catch (e) { debugPrint('refresh: $e'); }
  }

  // ── Toggle online ─────────────────────────────────────────────
  Future<void> toggleOnlineStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _helper == null) return;
    final next = !_helper!.isOnline;
    _helper = _helper!.copyWith(isOnline: next);
    notifyListeners();
    try {
      await _db.collection('helpers').doc(uid)
          .update({'isOnline': next, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      _helper = _helper!.copyWith(isOnline: !next);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────
  Future<bool> login({required String identifier, required String password}) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String emailToUse = identifier.trim();

      if (!emailToUse.contains('@')) {
        final q = await _db
            .collection('helpers')
            .where('username', isEqualTo: emailToUse.toLowerCase())
            .limit(1)
            .get();
        if (q.docs.isEmpty) {
          _errorMessage = 'No account found for "$emailToUse". Try using your email.';
          _isLoading    = false;
          notifyListeners();
          return false;
        }
        emailToUse = (q.docs.first.data()['email'] as String?) ?? '';
        if (emailToUse.isEmpty) {
          _errorMessage = 'Account found but email is missing. Contact support.';
          _isLoading    = false;
          notifyListeners();
          return false;
        }
      }

      final cred = await _auth.signInWithEmailAndPassword(
          email: emailToUse, password: password.trim());
      await _fetchHelper(cred.user!.uid);
      _subscribeNotifications(cred.user!.uid);
      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _authError(e.code);
      _isLoading    = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed. Please try again.';
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GOOGLE SIGN IN
  // ─────────────────────────────────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        _isLoading    = false;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final uid  = cred.user!.uid;

      final doc = await _db.collection('helpers').doc(uid).get();
      if (!doc.exists) {
        final data = {
          'uid':             uid,
          'name':            cred.user!.displayName ?? 'Sarthi Helper',
          'phone':           '',
          'phoneNumber':     '',
          'email':           cred.user!.email ?? '',
          'area':            '',
          'location':        '',
          'services':        <String>[],
          'serviceType':     '',
          'status':          'pending',
          'rating':          0.0,
          'totalJobs':       0,
          'kycDone':         false,
          'kycSkipped':      false,
          'kycStatus':       'not_submitted',
          'isOnline':        false,
          'photoUrl':        cred.user!.photoURL ?? '',
          'totalBalance':    0.0,
          'weeklyEarnings':  0.0,
          'monthlyEarnings': 0.0,
          'pendingPayout':   0.0,
          'todayEarnings':   0.0,
          'createdAt':       FieldValue.serverTimestamp(),
          'updatedAt':       FieldValue.serverTimestamp(),
        };
        await _db.collection('helpers').doc(uid).set(data);
      }

      // ✅ FIX: Always call _fetchHelper to start the real-time stream.
      // Previously existing users skipped this, leaving _helper without
      // a live stream — so isLoggedIn stayed false after Google login.
      await _fetchHelper(uid);
      _subscribeNotifications(uid);
      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _authError(e.code);
      _isLoading    = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google sign-in failed. Please try again.';
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────────────────────
  Future<bool> register({
    required String       name,
    required String       email,
    required String       password,
    required String       phone,
    required List<String> services,
    required String       area,
    String? username,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final eqry = await _db.collection('helpers')
          .where('email', isEqualTo: email.trim().toLowerCase()).limit(1).get();
      if (eqry.docs.isNotEmpty) {
        _errorMessage = 'This email is already registered.';
        _isLoading = false; notifyListeners(); return false;
      }
      if (phone.isNotEmpty) {
        final pqry = await _db.collection('helpers')
            .where('phone', isEqualTo: phone.trim()).limit(1).get();
        if (pqry.docs.isNotEmpty) {
          _errorMessage = 'This phone number is already registered.';
          _isLoading = false; notifyListeners(); return false;
        }
      }
      final uname = (username?.trim().toLowerCase()) ??
          name.trim().toLowerCase().replaceAll(' ', '_');
      final uqry = await _db.collection('helpers')
          .where('username', isEqualTo: uname).limit(1).get();
      if (uqry.docs.isNotEmpty) {
        _errorMessage = 'This username is taken. Choose another.';
        _isLoading = false; notifyListeners(); return false;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name.trim());

      final data = {
        'uid':             uid,
        'name':            name.trim(),
        'username':        uname,
        'email':           email.trim().toLowerCase(),

        // ← FIX: Store as both 'phone' AND 'phoneNumber'
        //   Admin panel reads h.phoneNumber; Flutter model reads 'phone'
        'phone':           phone.trim(),
        'phoneNumber':     phone.trim(),

        'services':        services,

        // ← FIX: Store as both 'area' AND 'location'
        //   Admin panel reads h.location; Flutter model reads 'area'
        'area':            area.trim(),
        'location':        area.trim(),

        // ← FIX: Store serviceType as first selected service (admin expects a string)
        //   Admin panel reads h.serviceType
        'serviceType':     services.isNotEmpty ? services.first : '',

        'status':          'pending',
        'rating':          0.0,
        'totalJobs':       0,
        'kycDone':         false,
        'kycSkipped':      false,

        // ← FIX: Added kycStatus field — admin filters by kycStatus === 'pending'
        //   Without this, no KYC submissions will ever appear in admin panel
        'kycStatus':       'not_submitted',

        'isOnline':        false,
        'totalBalance':    0.0,
        'weeklyEarnings':  0.0,
        'monthlyEarnings': 0.0,
        'pendingPayout':   0.0,
        'todayEarnings':   0.0,
        'createdAt':       FieldValue.serverTimestamp(),
        'updatedAt':       FieldValue.serverTimestamp(),
      };

      await _db.collection('helpers').doc(uid).set(data);
      _helper    = HelperModel.fromMap(data, uid);
      _subscribeNotifications(uid);
      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = e.code == 'email-already-in-use'
          ? 'Email already registered. Please login.'
          : _authError(e.code);
      _isLoading = false; notifyListeners(); return false;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading    = false; notifyListeners(); return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // KYC  ← ALL BUGS WERE HERE
  // ─────────────────────────────────────────────────────────────
  Future<bool> submitKyc(Map<String, String> kycData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _db.collection('helpers').doc(uid).update({
        // ← FIX 1 (ROOT CAUSE): Was 'kycData' — admin reads from 'kycDocuments'
        //   The entire KYC modal in admin does: const docs = h.kycDocuments || {}
        //   Saving under 'kycData' means docs is always {}, showing '—' for everything
        'kycDocuments':    kycData,

        // ← FIX 2 (ROOT CAUSE): Was 'status': 'submitted'
        //   Admin filters with: allHelpers.filter(h => h.kycStatus === 'pending')
        //   'status' and 'kycStatus' are TWO DIFFERENT FIELDS.
        //   'status' being 'submitted' has zero effect on KYC visibility.
        //   Without this line, admin will always show "No pending KYC applications".
        'kycStatus':       'pending',

        // ← FIX 3: kycDone should remain false until admin APPROVES, not on submission
        //   Setting kycDone:true here would incorrectly mark KYC as complete
        //   before admin review
        'kycDone':         false,

        // ← FIX 4: Added kycSubmittedAt — admin modal displays this field:
        //   h.kycSubmittedAt?.toDate ? h.kycSubmittedAt.toDate().toLocaleDateString() : 'N/A'
        //   Without this, "Submitted On" always shows 'N/A'
        'kycSubmittedAt':  FieldValue.serverTimestamp(),

        'updatedAt':       FieldValue.serverTimestamp(),
      });

      // Update local model immediately so UI reflects pending state
      if (_helper != null) {
        _helper = _helper!.copyWith(kycStatus: 'pending');
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e); notifyListeners(); return false;
    }
  }

  Future<void> skipKyc() async {
    final uid = _auth.currentUser?.uid; if (uid == null) return;
    try {
      await _db.collection('helpers').doc(uid).update({
        'kycSkipped': true,
        // ← FIX: Explicitly set kycStatus so admin filtering stays clean
        'kycStatus':  'not_submitted',
        'updatedAt':  FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE PROFILE
  // ─────────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String       name,
    required String       phone,
    required String       area,
    required List<String> services,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _db.collection('helpers').doc(uid).update({
        'name':        name.trim(),
        'phone':       phone.trim(),
        'phoneNumber': phone.trim(),   // ← FIX: keep alias in sync
        'area':        area.trim(),
        'location':    area.trim(),    // ← FIX: keep alias in sync
        'services':    services,
        'serviceType': services.isNotEmpty ? services.first : '',  // ← FIX
        'updatedAt':   FieldValue.serverTimestamp(),
      });
      await _auth.currentUser!.updateDisplayName(name.trim());
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e); notifyListeners(); return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PASSWORD RESET / LOGOUT
  // ─────────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e); notifyListeners(); return false;
    }
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try { await _db.collection('helpers').doc(uid).update({'isOnline': false}); }
      catch (_) {}
    }
    _cancelStreams();
    _helper = null; _errorMessage = null; _unreadCount = 0;
    await _google.signOut().catchError((_) {});
    await _auth.signOut();
    notifyListeners();
  }

  void _cancelStreams() {
    _helperSub?.cancel(); _helperSub = null;
    _notifSub?.cancel();  _notifSub  = null;
  }

  // ── Error helpers ─────────────────────────────────────────────
  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return 'Invalid email/username or password.';
      case 'email-already-in-use': return 'Email already registered.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      case 'too-many-requests':    return 'Too many attempts. Try again later.';
      case 'network-request-failed': return 'No internet connection.';
      default: return 'Authentication failed. Please try again.';
    }
  }

  String _friendlyError(dynamic e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') return 'Access denied. Check Firestore rules.';
      return e.message ?? 'An error occurred.';
    }
    return e.toString();
  }

  @override
  void dispose() {
    _authSub?.cancel(); _cancelStreams(); super.dispose();
  }
}