// lib/core/push_tokens.dart
// Saves this phone's FCM token so the server can send push notifications.
// IDENTICAL in both apps; each app passes its own role ('user' | 'helper').
//
// Call PushTokens.instance.start(app: ...) after sign-in and stop() on sign-out.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushTokens {
  PushTokens._();
  static final PushTokens instance = PushTokens._();

  StreamSubscription<String>? _refreshSub;
  String? _token;
  String? _uid;

  Future<void> start({required String app}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _uid = uid;
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _save(uid, t, app);
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        final u = FirebaseAuth.instance.currentUser?.uid;
        if (u != null) _save(u, t, app);
      });
    } catch (e) {
      debugPrint('PushTokens.start: $e');
    }
  }

  // One document per person: push_tokens/{uid} = { tokens: { <token>: {app, platform, updatedAt} } }
  // (the Worker loads everyone's tokens in a single request).
  Future<void> _save(String uid, String token, String app) async {
    _token = token;
    await FirebaseFirestore.instance.collection('push_tokens').doc(uid).set({
      'tokens': {
        token: {
          'app': app,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
  }

  /// Call BEFORE FirebaseAuth.signOut(), so this phone stops getting that account's pushes.
  Future<void> stop() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    final t = _token;
    if (uid != null && t != null) {
      try {
        await FirebaseFirestore.instance
            .collection('push_tokens')
            .doc(uid)
            .update({FieldPath(['tokens', t]): FieldValue.delete()});
      } catch (_) {}
    }
    _uid = null;
    _token = null;
  }
}