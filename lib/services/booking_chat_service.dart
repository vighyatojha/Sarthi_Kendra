// lib/service/booking_chat_service.dart
//
// Call BookingChatService.instance.onBookingAccepted(...)
// from wherever your helper accepts a booking (e.g. HelperBookingsScreen).
//
// What it does:
//   1. Creates (or reuses) a Firestore `chats/{chatId}` document.
//   2. Writes the auto-confirmation message to RTDB `chats/{chatId}/messages`.
//   3. Fires a Firestore notification so the user sees the badge immediately.
//   4. Updates the booking doc with chatId + status = 'accepted'.
//
// The chatId is the Firestore doc ID — both sides (user ChatScreen and
// helper HelperChatRoomScreen) receive it and hit the same RTDB path.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_db_service.dart';

class BookingChatService {
  BookingChatService._();
  static final instance = BookingChatService._();

  final _fs = FirebaseFirestore.instance;

  // ─── Main entry point ─────────────────────────────────────────────────────

  /// Returns the chatId. Call this as soon as a helper accepts a booking.
  ///
  /// Example (in your helper bookings screen):
  /// ```dart
  /// final chatId = await BookingChatService.instance.onBookingAccepted(
  ///   bookingId:     booking.id,
  ///   helperId:      _uid,
  ///   helperName:    _myName,
  ///   helperPhoto:   _myPhoto,
  ///   userId:        booking.userId,
  ///   userName:      booking.userName,
  ///   serviceName:   booking.serviceName,
  ///   scheduledTime: booking.scheduledTime, // e.g. "10:00 AM, 30 Mar"
  /// );
  /// ```
  Future<String> onBookingAccepted({
    required String bookingId,
    required String helperId,
    required String helperName,
    String? helperPhoto,
    required String userId,
    required String userName,
    required String serviceName,
    required String scheduledTime, // human-readable, e.g. "10:00 AM, 30 Mar 2026"
  }) async {
    // ── Step 1: find or create the Firestore chat document ─────────────────
    String chatId;

    final existing = await _fs
        .collection('chats')
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Chat already exists (e.g. booking was re-accepted after cancellation)
      chatId = existing.docs.first.id;
      await _fs.collection('chats').doc(chatId).update({
        'bookingStatus': 'accepted',
        'helperName': helperName,
        'helperPhoto': helperPhoto ?? '',
        'otherName': helperName,
        'userUnread': FieldValue.increment(1),
        'unreadCount_$userId': FieldValue.increment(1),
        'lastMessage': 'Booking confirmed! I\'ll be there at $scheduledTime.',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } else {
      // ── Create fresh chat document ───────────────────────────────────────
      // Fields explanation:
      //   participants     → user-side query: .where('participants', arrayContains: uid)
      //   helperId         → helper-side query: .where('helperId', isEqualTo: uid)
      //   otherName        → user-side display name (shows helper's name)
      //   userName         → helper-side display name (shows user's name)
      //   unreadCount_{id} → user-side badge field
      //   helperUnread     → helper-side badge field
      final ref = await _fs.collection('chats').add({
        'bookingId': bookingId,
        'helperId': helperId,
        'helperName': helperName,
        'helperPhoto': helperPhoto ?? '',
        'userId': userId,
        'userName': userName,
        'otherName': helperName,       // what user sees as the chat name
        'helperOnline': true,
        'serviceName': serviceName,
        'participants': [userId, helperId],
        'lastMessage': 'Booking confirmed! I\'ll be there at $scheduledTime.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'helperUnread': 0,             // helper hasn't missed anything yet
        'userUnread': 1,               // user has 1 unread (the auto message)
        'unreadCount_$userId': 1,      // mirrors userUnread for user-side query
        'bookingStatus': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });

      chatId = ref.id;
    }

    // ── Step 2: stamp chatId onto the booking doc ───────────────────────────
    await _fs.collection('bookings').doc(bookingId).update({
      'chatId': chatId,
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {}); // don't crash if booking doc structure differs

    // ── Step 3: send auto-confirmation RTDB message ─────────────────────────
    await RealtimeDbService.instance.sendBookingConfirmedMessage(
      chatId: chatId,
      helperId: helperId,
      helperName: helperName,
      userName: userName,
      serviceName: serviceName,
      scheduledTime: scheduledTime,
      userId: userId,
    );

    // ── Step 4: create Firestore notification so badge updates immediately ──
    await _sendBookingConfirmedNotification(
      userId: userId,
      helperId: helperId,
      helperName: helperName,
      serviceName: serviceName,
      scheduledTime: scheduledTime,
      bookingId: bookingId,
      chatId: chatId,
    );

    return chatId;
  }

  // ─── Call when booking is marked complete by helper ────────────────────────

  Future<void> onBookingCompleted({
    required String bookingId,
    required String chatId,
    required String userId,
    required String serviceName,
  }) async {
    await _fs.collection('chats').doc(chatId).update({
      'bookingStatus': 'completed',
    }).catchError((_) {});

    await _fs.collection('bookings').doc(bookingId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // Notify user to rate the service
    await _fs
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type': 'service_completed',
      'title': 'Service Completed ✅',
      'body': 'How was your "$serviceName" experience? Tap to rate!',
      'bookingId': bookingId,
      'chatId': chatId,
      'rating': 0,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _sendBookingConfirmedNotification({
    required String userId,
    required String helperId,
    required String helperName,
    required String serviceName,
    required String scheduledTime,
    required String bookingId,
    required String chatId,
  }) async {
    await _fs
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type': 'booking_confirmed',
      'title': 'Booking Confirmed! 🎉',
      'body': '$helperName has accepted your "$serviceName" booking '
          'and will arrive at $scheduledTime.',
      'bookingId': bookingId,
      'chatId': chatId,
      'helperId': helperId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}