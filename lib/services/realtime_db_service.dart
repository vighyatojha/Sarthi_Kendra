// lib/service/realtime_db_service.dart
//
// Single source of truth for all RTDB chat operations.
// Both user-side (ChatScreen) and helper-side (HelperChatRoomScreen) read/write
// the same RTDB path:  chats/{chatId}/messages/{msgId}
//
// Firestore  chats/{chatId}       ← metadata, unread counters, participants
// RTDB       chats/{chatId}/messages ← actual message payloads

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RealtimeDbService {
  RealtimeDbService._();
  static final instance = RealtimeDbService._();

  final _db = FirebaseDatabase.instance;
  final _fs = FirebaseFirestore.instance;

  // ─── Helpers ───────────────────────────────────────────────────────────────

  DatabaseReference _msgsRef(String chatId) =>
      _db.ref('chats/$chatId/messages');

  DocumentReference _chatDoc(String chatId) =>
      _fs.collection('chats').doc(chatId);

  // ─── Stream all messages for a chat (used by user ChatScreen) ─────────────

  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    return _msgsRef(chatId).orderByChild('timestamp').onValue.map((event) {
      if (event.snapshot.value == null) return <Map<String, dynamic>>[];

      final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
      final msgs = raw.entries.map((e) {
        final d = Map<String, dynamic>.from(e.value as Map);
        return <String, dynamic>{'id': e.key, ...d};
      }).toList();

      msgs.sort((a, b) =>
          ((a['timestamp'] as int?) ?? 0)
              .compareTo((b['timestamp'] as int?) ?? 0));
      return msgs;
    });
  }

  // ─── Send a message (user → helper) ───────────────────────────────────────

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String role = 'user',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _msgsRef(chatId).push().set({
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': role,
      'timestamp': now,
      'read': false,
    });

    // Update Firestore metadata so helper's chat list refreshes
    await _chatDoc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'helperUnread': FieldValue.increment(1),
    }).catchError((_) {});
  }

  // ─── Send automated booking-confirmed message (helper → user, system tone) ─
  //
  // Called by BookingChatService.onBookingAccepted() automatically.
  // The message has type: 'booking_confirmed' so user-side ChatScreen renders
  // it as a _SystemMessage (purple info card) instead of a regular bubble.

  Future<void> sendBookingConfirmedMessage({
    required String chatId,
    required String helperId,
    required String helperName,
    required String userName,
    required String serviceName,
    required String scheduledTime,
    String? userId, // if provided, increments that user's unread counter
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final text =
        'Hello $userName! 🙏\n\n'
        'Your booking for "$serviceName" has been confirmed!\n'
        'I, $helperName, will be there at $scheduledTime.\n\n'
        'Thank you for choosing Trouble Sarthi! 😊';

    await _msgsRef(chatId).push().set({
      'text': text,
      'senderId': helperId,
      'senderName': helperName,
      'senderRole': 'helper',
      'type': 'booking_confirmed',   // renders as _SystemMessage on user side
      'timestamp': now,
      'read': false,
    });

    // Update Firestore metadata — both list views refresh
    await _chatDoc(chatId).update({
      'lastMessage': 'Booking confirmed! I\'ll be there at $scheduledTime.',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userUnread': FieldValue.increment(1),
      if (userId != null)
        'unreadCount_$userId': FieldValue.increment(1), // user-side badge
      'bookingStatus': 'accepted',
    }).catchError((_) {});
  }

  // ─── Notify helper inbox (lightweight RTDB trigger) ───────────────────────
  //
  // Used by user-side ChatScreen after sending a message so the helper's
  // device can surface a local notification via an RTDB listener / FCM trigger.

  Future<void> notifyHelperMessage({
    required String userId,          // helperId — the one to notify
    required String helperName,      // sender display name (confusingly named in original, kept)
    required String messagePreview,
    String? bookingId,
  }) async {
    await _db.ref('helpers/$userId/inbox/latestUserMsg').set({
      'from': helperName,
      'preview': messagePreview,
      'bookingId': bookingId ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ─── Reset unread counters ─────────────────────────────────────────────────

  /// Call when the user opens a chat — resets their unread counter.
  Future<void> resetUserUnread(String chatId, String userId) async {
    await _chatDoc(chatId).update({
      'userUnread': 0,
      'unreadCount_$userId': 0,
    }).catchError((_) {});
  }

  /// Call when the helper opens a chat — resets helper's unread counter.
  Future<void> resetHelperUnread(String chatId) async {
    await _chatDoc(chatId)
        .update({'helperUnread': 0}).catchError((_) {});
  }

  // ─── Mark individual RTDB messages as read ────────────────────────────────

  Future<void> markMessagesRead(String chatId, List<String> messageIds) async {
    final updates = <String, Object>{};
    for (final id in messageIds) {
      updates['chats/$chatId/messages/$id/read'] = true;
    }
    await _db.ref().update(updates).catchError((_) {});
  }

  // ─── Delete all messages from RTDB (local clear) ─────────────────────────

  Future<void> deleteChat(String chatId) async {
    await _msgsRef(chatId).remove();
  }
}