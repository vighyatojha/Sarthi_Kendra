// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/helper_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth      _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db   = FirebaseFirestore.instance;

  HelperModel? _helper;
  String?      _errorMessage;
  bool         _isLoading   = false;
  bool         _initialized = false;
  int          _unreadCount = 0;

  StreamSubscription<User?>?             _authSub;
  StreamSubscription<DocumentSnapshot>?  _helperSub;
  StreamSubscription<QuerySnapshot>?     _notifSub;

  HelperModel? get helper       => _helper;
  String?      get errorMessage => _errorMessage;
  bool         get isLoading    => _isLoading;
  bool         get initialized  => _initialized;
  bool         get isLoggedIn   => _auth.currentUser != null && _helper != null;
  int          get unreadCount  => _unreadCount;

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

  // ── Helper document ───────────────────────────────────────────
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
        onError: (e) => debugPrint('Helper stream: $e'),
      );
    } catch (e) {
      debugPrint('_fetchHelper: $e');
      _errorMessage = _friendlyError(e);
    }
  }

  // ── Notification background listener ─────────────────────────
  void _subscribeNotifications(String uid) {
    _notifSub?.cancel();
    _notifSub = _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      _unreadCount = snap.docs.length;
      notifyListeners();
    }, onError: (e) => debugPrint('Notif stream: $e'));
  }

  // ── Mark all notifications read ───────────────────────────────
  Future<void> markAllNotificationsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllRead: $e');
    }
  }

  // ── Refresh profile ───────────────────────────────────────────
  Future<void> refreshProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('helpers').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _helper = HelperModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('refreshProfile: $e');
    }
  }

  // ── Toggle online ─────────────────────────────────────────────
  Future<void> toggleOnlineStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _helper == null) return;
    final next = !_helper!.isOnline;
    _helper = _helper!.copyWith(isOnline: next);
    notifyListeners();
    try {
      await _db.collection('helpers').doc(uid).update({
        'isOnline':  next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _helper = _helper!.copyWith(isOnline: !next);
      notifyListeners();
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────
  // Supports: email address OR 10-digit phone number
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String emailToUse = identifier.trim();

      // ── Phone number login: look up email in Firestore ────────
      if (!emailToUse.contains('@')) {
        final phone  = emailToUse.replaceAll(RegExp(r'\s+'), '');
        final query  = await _db
            .collection('helpers')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          _errorMessage =
          'No account found with this phone number. Try using your email.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final helperData = query.docs.first.data();
        emailToUse = (helperData['email'] as String?) ?? '';

        if (emailToUse.isEmpty) {
          _errorMessage = 'Account found but email is missing. Contact support.';
          _isLoading    = false;
          notifyListeners();
          return false;
        }
      }

      // ── Firebase Auth sign in ─────────────────────────────────
      final cred = await _auth.signInWithEmailAndPassword(
        email:    emailToUse,
        password: password.trim(),
      );

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

  // ── REGISTER ──────────────────────────────────────────────────
  Future<bool> register({
    required String       name,
    required String       email,
    required String       password,
    required String       phone,
    required List<String> services,
    required String       area,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if email already exists
      final existingEmail = await _db
          .collection('helpers')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (existingEmail.docs.isNotEmpty) {
        _errorMessage =
        'This email is already registered. Please login instead.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if phone already exists
      final existingPhone = await _db
          .collection('helpers')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();

      if (existingPhone.docs.isNotEmpty) {
        _errorMessage =
        'This phone number is already registered. Please login instead.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password.trim(),
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name.trim());

      final data = {
        'uid':             uid,
        'name':            name.trim(),
        'email':           email.trim().toLowerCase(),
        'phone':           phone.trim(),
        'services':        services,
        'area':            area.trim(),
        'status':          'pending',
        'rating':          0.0,
        'totalJobs':       0,
        'kycDone':         false,
        'kycSkipped':      false,
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
      if (e.code == 'email-already-in-use') {
        _errorMessage =
        'This email is already registered. Please login or use a different email.';
      } else {
        _errorMessage = _authError(e.code);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ── SUBMIT KYC ────────────────────────────────────────────────
  Future<bool> submitKyc(Map<String, String> kycData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _db.collection('helpers').doc(uid).update({
        'kycData':   kycData,
        'kycDone':   true,
        'status':    'submitted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ── SKIP KYC ─────────────────────────────────────────────────
  Future<void> skipKyc() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('helpers').doc(uid).update({
        'kycSkipped': true,
        'updatedAt':  FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('skipKyc: $e');
    }
  }

  // ── PASSWORD RESET ────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────────
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('helpers').doc(uid).update({'isOnline': false});
      } catch (_) {}
    }
    _cancelStreams();
    _helper       = null;
    _errorMessage = null;
    _unreadCount  = 0;
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
      case 'invalid-credential':
        return 'Invalid email/phone or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _friendlyError(dynamic e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Access denied. Check Firestore rules.';
      }
      return e.message ?? 'An error occurred.';
    }
    return e.toString();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelStreams();
    super.dispose();
  }
}