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
    required String scheduledTime,
  }) async {
    // chatId = bookingId (deterministic — both apps derive it the same way,
    // no lookup needed, no random Firestore ID mismatch possible)
    final chatId = bookingId;

    // ── Step 1: set (merge) the Firestore chat document ────────────────────
    // merge:true → re-acceptances never wipe existing RTDB message history.
    // All fields written in one call so both apps always see a complete doc.
    await _fs.collection('chats').doc(chatId).set(
      {
        'chatId':              chatId,
        'bookingId':           bookingId,
        'helperId':            helperId,
        'helperName':          helperName,
        'helperPhoto':         helperPhoto ?? '',
        'userId':              userId,
        'userName':            userName,
        'otherName':           helperName,
        'helperOnline':        true,
        'serviceName':         serviceName,
        'participants':        [userId, helperId],
        'lastMessage':         'Booking confirmed! I\'ll be there at $scheduledTime.',
        'lastMessageTime':     FieldValue.serverTimestamp(),
        'helperUnread':        0,
        'userUnread':          1,
        'unreadCount_$userId': 1,
        'bookingStatus':       'accepted',
        'createdAt':           FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // ── Step 2: stamp chatId onto the booking doc ───────────────────────────
    await _fs.collection('bookings').doc(bookingId).update({
      'chatId':     chatId,
      'status':     'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // ── Step 3: send auto-confirmation RTDB message ─────────────────────────
    await RealtimeDbService.instance.sendBookingConfirmedMessage(
      chatId:        chatId,
      helperId:      helperId,
      helperName:    helperName,
      userName:      userName,
      serviceName:   serviceName,
      scheduledTime: scheduledTime,
      userId:        userId,
    );

    // ── Step 3b: send chat lifecycle warning ────────────────────────────────
    await RealtimeDbService.instance.sendSystemWarning(
      chatId:  chatId,
      message: '⚠️ Important: This chat will be automatically deleted once '
          'both parties complete the mutual review after the service. '
          'Please take a screenshot before review if you need a record.',
    );

    // ── Step 4: Firestore notification so badge updates immediately ─────────
    await _sendBookingConfirmedNotification(
      userId:        userId,
      helperId:      helperId,
      helperName:    helperName,
      serviceName:   serviceName,
      scheduledTime: scheduledTime,
      bookingId:     bookingId,
      chatId:        chatId,
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
      'status':      'completed',
      'completedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // Notify user to rate the service
    await _fs
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type':      'service_completed',
      'title':     'Service Completed ✅',
      'body':      'How was your "$serviceName" experience? Tap to rate!',
      'bookingId': bookingId,
      'chatId':    chatId,
      'rating':    0,
      'read':      false,
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
      'type':      'booking_confirmed',
      'title':     'Booking Confirmed! 🎉',
      'body':      '$helperName has accepted your "$serviceName" booking '
          'and will arrive at $scheduledTime.',
      'bookingId': bookingId,
      'chatId':    chatId,
      'helperId':  helperId,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}