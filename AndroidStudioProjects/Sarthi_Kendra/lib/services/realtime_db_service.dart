// lib/service/realtime_db_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class RealtimeDbService {
  RealtimeDbService._();
  static final RealtimeDbService instance = RealtimeDbService._();

  final _db = FirebaseDatabase.instance;

  // ── Send a message ────────────────────────────────────────────
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      await _db.ref('chats/$chatId/messages').push().set({
        'senderId':   senderId,
        'senderName': senderName,
        'text':       text,
        'timestamp':  ServerValue.timestamp,
        'type':       'text',
      });
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
  }

  // ── Stream messages for a chat ────────────────────────────────
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db
        .ref('chats/$chatId/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Map<String, dynamic>>[];
      final Map<dynamic, dynamic> raw = data as Map<dynamic, dynamic>;
      return raw.entries
          .map((e) => Map<String, dynamic>.from(e.value as Map))
          .toList()
        ..sort((a, b) =>
            ((a['timestamp'] as int?) ?? 0)
                .compareTo((b['timestamp'] as int?) ?? 0));
    });
  }

  // ── Notify helper about a new message from user ───────────────
  Future<void> notifyHelperMessage({
    required String userId,
    required String helperName,
    required String messagePreview,
    String? bookingId,
  }) async {
    try {
      await _db.ref('notifications/$userId').push().set({
        'type':    'new_message',
        'from':    helperName,
        'preview': messagePreview,
        if (bookingId != null) 'bookingId': bookingId,
        'timestamp': ServerValue.timestamp,
        'read':    false,
      });
    } catch (e) {
      debugPrint('notifyHelperMessage: $e');
    }
  }

  // ── Delete a chat (clear messages) ───────────────────────────
  Future<void> deleteChat(String chatId) async {
    try {
      await _db.ref('chats/$chatId/messages').remove();
    } catch (e) {
      debugPrint('deleteChat: $e');
    }
  }
}