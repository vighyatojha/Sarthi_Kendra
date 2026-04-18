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

  // ─── Stream all messages for a chat ───────────────────────────────────────

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

  // ─── Send a regular chat message ──────────────────────────────────────────

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String role = 'user',
    String? helperId,   // pass this so we can write a notification
    String? serviceName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _msgsRef(chatId).push().set({
      'text':       text,
      'senderId':   senderId,
      'senderName': senderName,
      'senderRole': role,
      'timestamp':  now,
      'read':       false,
    });

    // Update Firestore metadata so helper's chat list refreshes
    await _chatDoc(chatId).update({
      'lastMessage':     text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'helperUnread':    FieldValue.increment(1),
    }).catchError((_) {});

    // Write a Firestore notification so it appears in NotificationsScreen
    if (helperId != null && helperId.isNotEmpty) {
      await _fs
          .collection('notifications')
          .doc(helperId)
          .collection('items')
          .add({
        'type':      'new_message',
        'title':     'New message from $senderName',
        'body':      text.length > 80 ? '${text.substring(0, 80)}…' : text,
        'chatId':    chatId,
        'senderId':  senderId,
        'senderName': senderName,
        'serviceName': serviceName ?? '',
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
  }

  // ─── Send booking-confirmed system message ─────────────────────────────────

  Future<void> sendBookingConfirmedMessage({
    required String chatId,
    required String helperId,
    required String helperName,
    required String userName,
    required String serviceName,
    required String scheduledTime,
    String? userId,
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
      'type': 'booking_confirmed',
      'timestamp': now,
      'read': false,
    });

    await _chatDoc(chatId).update({
      'lastMessage': 'Booking confirmed! I\'ll be there at $scheduledTime.',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userUnread': FieldValue.increment(1),
      if (userId != null)
        'unreadCount_$userId': FieldValue.increment(1),
      'bookingStatus': 'accepted',
    }).catchError((_) {});
  }

  // ─── NEW: Send system message when helper confirms job done ───────────────
  //
  // Appears in both sides' chat as a purple info pill.
  // Tells the user: "Helper confirmed the job is done — please confirm payment."

  Future<void> sendHelperConfirmedMessage({
    required String chatId,
    required String helperName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _msgsRef(chatId).push().set({
      'text':       '✅ $helperName has confirmed the job is done. '
          'Please tap "Confirm Payment" to complete the booking.',
      'senderId':   'system',
      'senderName': 'Sarthi Kendra',
      'senderRole': 'system',
      'type':       'system',
      'timestamp':  now,
      'read':       false,
    });
  }

  // PASTE after sendHelperConfirmedMessage method (after its closing brace)

  Future<void> sendUserPaymentConfirmedMessage({
    required String chatId,
    required String paymentMethod,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _msgsRef(chatId).push().set({
      'text': paymentMethod == 'upi'
          ? '💳 The customer has confirmed UPI (online) payment. Have you received it?'
          : '💳 The customer has confirmed cash payment. Have you received it?',
      'senderId':   'system',
      'senderName': 'Sarthi Kendra',
      'senderRole': 'system',
      'type':       'payment_confirmation_pending',
      'paymentMethod': paymentMethod,
      'timestamp':  now,
      'read':       false,
    });
  }

  Future<void> sendReceiptReadyMessage({required String chatId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _msgsRef(chatId).push().set({
      'text':       '🎉 Payment received and confirmed! The service is now complete. Download your receipt.',
      'senderId':   'system',
      'senderName': 'Sarthi Kendra',
      'senderRole': 'system',
      'type':       'receipt_ready',
      'timestamp':  now,
      'read':       false,
    });
  }

  // ─── NEW: Send system message when BOTH sides have confirmed ──────────────
  //
  // Appears as a celebration pill in both chats before the review sheet opens.

  Future<void> sendMutualCompletionMessage({required String chatId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _msgsRef(chatId).push().set({
      'text':       '🎉 Both parties confirmed. '
          'The job is now officially complete! '
          'Please take a moment to rate each other.',
      'senderId':   'system',
      'senderName': 'Sarthi Kendra',
      'senderRole': 'system',
      'type':       'system',
      'timestamp':  now,
      'read':       false,
    });
  }

  // ─── Notify helper inbox (lightweight RTDB trigger) ───────────────────────

  Future<void> notifyHelperMessage({
    required String userId,
    required String helperName,
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

  Future<void> resetUserUnread(String chatId, String userId) async {
    await _chatDoc(chatId).update({
      'userUnread': 0,
      'unreadCount_$userId': 0,
    }).catchError((_) {});
  }

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

  // ─── Send a system warning message ────────────────────────────────────────

  Future<void> sendSystemWarning({
    required String chatId,
    required String message,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _msgsRef(chatId).push().set({
      'text':       message,
      'senderId':   'system',
      'senderName': 'Sarthi Kendra',
      'senderRole': 'system',
      'type':       'system_warning',
      'timestamp':  now,
      'read':       false,
    });
  }
}