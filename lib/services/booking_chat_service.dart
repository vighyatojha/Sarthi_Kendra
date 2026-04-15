import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_db_service.dart';
import 'package:firebase_database/firebase_database.dart';

class BookingChatService {
  BookingChatService._();
  static final instance = BookingChatService._();

  final _fs = FirebaseFirestore.instance;

  // ─── Main entry point ─────────────────────────────────────────────────────

  /// Returns the chatId. Call this as soon as a helper accepts a booking.
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
    final chatId = bookingId;

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
        // Mutual confirmation flags — both start false
        'helperConfirmedComplete': false,
        'userConfirmedComplete':   false,
        'createdAt':           FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _fs.collection('bookings').doc(bookingId).update({
      'chatId':     chatId,
      'status':     'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    await RealtimeDbService.instance.sendBookingConfirmedMessage(
      chatId:        chatId,
      helperId:      helperId,
      helperName:    helperName,
      userName:      userName,
      serviceName:   serviceName,
      scheduledTime: scheduledTime,
      userId:        userId,
    );

    await RealtimeDbService.instance.sendSystemWarning(
      chatId:  chatId,
      message: '⚠️ Important: This chat will be automatically deleted once '
          'both parties complete the mutual review after the service. '
          'Please take a screenshot before review if you need a record.',
    );

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

  // ─── Step A: Helper taps "Seva Done" ──────────────────────────────────────
  //
  // Sets helperConfirmedComplete = true on Firestore.
  // Sends a system RTDB message prompting the user to confirm payment.
  // Does NOT mark the booking completed yet — user must also confirm.

  Future<void> onHelperConfirmedComplete({
    required String bookingId,
    required String chatId,
    required String helperName,
    required String userId,
  }) async {
    // Write the helper flag
    await _fs.collection('chats').doc(chatId).update({
      'helperConfirmedComplete': true,
    }).catchError((_) {});

    // Send a purple system pill into the RTDB chat
    await RealtimeDbService.instance.sendHelperConfirmedMessage(
      chatId:     chatId,
      helperName: helperName,
    );

    // Notify the user so they know action is needed
    await _fs
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type':      'helper_confirmed_complete',
      'title':     'Helper says the job is done! ✅',
      'body':      'Please confirm payment to complete the booking.',
      'bookingId': bookingId,
      'chatId':    chatId,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Step B: BOTH sides confirmed → finalise the booking ──────────────────
  //
  // Called by whichever side detects that both flags are true via the
  // Firestore stream (the stream fires on both devices simultaneously, so
  // both sides call this; the Firestore update is idempotent/merge-safe).

  Future<void> onMutualCompletionConfirmed({
    required String bookingId,
    required String chatId,
    required String userId,
    required String serviceName,
  }) async {
    // Mark booking complete in Firestore
    await _fs.collection('chats').doc(chatId).update({
      'bookingStatus': 'completed',
    }).catchError((_) {});

    await _fs.collection('bookings').doc(bookingId).update({
      'status':      'completed',
      'completedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // Drop a celebration message into the RTDB chat
    await RealtimeDbService.instance.sendMutualCompletionMessage(
      chatId: chatId,
    );

    // Notify user to leave a review
    await _fs
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type':      'service_completed',
      'title':     'Service Completed 🎉',
      'body':      'How was your "$serviceName" experience? Tap to rate!',
      'bookingId': bookingId,
      'chatId':    chatId,
      'rating':    0,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Legacy: called when helper marks complete unilaterally ───────────────
  //
  // Kept for backward compatibility. New flow goes through
  // onHelperConfirmedComplete() + onMutualCompletionConfirmed() instead.

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

    if (helperId.isNotEmpty) {
      await FirebaseDatabase.instance
          .ref('helper_notifications/$helperId')
          .push()
          .set({
        'type':      'booking_accepted',
        'title':     'Booking Accepted ✅',
        'body':      'You confirmed the "$serviceName" booking. Customer notified.',
        'bookingId': bookingId,
        'chatId':    chatId,
        'read':      false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
}