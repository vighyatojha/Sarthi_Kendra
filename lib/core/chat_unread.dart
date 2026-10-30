// lib/core/chat_unread.dart
// Remembers, on this phone, when each booking chat was last opened, so chat
// lists and the Messages badge can show which conversations have new messages.
// (The security rules don't let one side write unread counters for the other,
// so this is kept locally.) IDENTICAL in both apps.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatUnread {
  ChatUnread._();
  static final ChatUnread instance = ChatUnread._();

  /// Bumps whenever a chat is marked read, so lists can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Number of booking chats with unread messages (for the Messages badge).
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  final Map<String, int> _readAt = {};
  String _loadedFor = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastDocs = const [];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _key => 'chat_read_$_uid';

  Future<void> _ensureLoaded() async {
    final uid = _uid;
    if (uid.isEmpty || _loadedFor == uid) return;
    _readAt.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) {
          if (v is num) _readAt[k] = v.toInt();
        });
      }
    } catch (_) {}
    _loadedFor = uid;
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      // Keep the newest 300 chats only.
      if (_readAt.length > 300) {
        final sorted = _readAt.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _readAt
          ..clear()
          ..addEntries(sorted.take(300));
      }
      await p.setString(_key, jsonEncode(_readAt));
    } catch (_) {}
  }

  /// Call when the chat is opened and whenever new messages arrive while open.
  Future<void> markRead(String chatId) async {
    await _ensureLoaded();
    _readAt[chatId] = DateTime.now().millisecondsSinceEpoch;
    revision.value++;
    _recount();
    await _save();
  }

  /// True if someone else sent a message after this phone last opened the chat.
  bool isUnread(Map<String, dynamic> chat, String chatId) {
    final uid = _uid;
    final last = chat['lastMessageTime'];
    final sender = chat['lastSenderId'];
    final text = chat['lastMessage'];
    if (last is! Timestamp || sender is! String || sender.isEmpty || sender == uid) return false;
    if (text is! String || text.isEmpty) return false;
    final readAt = _readAt[chatId] ?? 0;
    return last.millisecondsSinceEpoch > readAt;
  }

  /// Starts watching this user's chats to keep [unreadCount] current.
  /// Safe to call more than once.
  Future<void> start() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _ensureLoaded();
    if (_sub != null && _loadedFor == uid) return;
    await _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((s) {
      _lastDocs = s.docs;
      _recount();
    }, onError: (_) {});
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastDocs = const [];
    _loadedFor = '';
    _readAt.clear();
    unreadCount.value = 0;
  }

  void _recount() {
    var n = 0;
    for (final d in _lastDocs) {
      if (isUnread(d.data(), d.id)) n++;
    }
    if (unreadCount.value != n) unreadCount.value = n;
  }
}