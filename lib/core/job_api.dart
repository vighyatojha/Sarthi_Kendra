// lib/core/job_api.dart
// Every read and write for the request → quote → booking flow (free Spark plan).
// IDENTICAL in Trouble Sarthi and Sarthi Kendra.
//
// There is no server: the apps write to Firestore directly and firestore.rules
// checks every write. Each method below builds exactly the fields the rules
// expect; change both together. After important changes the app pings the
// Cloudflare Worker, which sends the push notifications.

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'geo.dart';
import 'job_models.dart';
import 'ranking.dart';
import 'service_catalog.dart';

/// A friendly error, safe to show to the user.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class JobApi {
  JobApi._();
  static final JobApi instance = JobApi._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  FieldValue get _now => FieldValue.serverTimestamp();

  /// Runs a write and turns Firebase errors into plain messages.
  /// [denied] is shown when the security rules refuse the write.
  Future<T> _guard<T>(Future<T> Function() fn, String denied) async {
    try {
      return await fn();
    } on FirebaseException catch (e) {
      debugPrint('JobApi: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') throw ApiException(denied);
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const ApiException('No internet connection. Please try again.');
      }
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  // ─── Push notifications (Cloudflare Worker) ──────────────────────────────

  /// Best-effort: a failed notification never fails the action itself.
  Future<Map<String, dynamic>> _notify(String event, {String? jobId, String? bookingId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || AppConfig.notifyWorkerUrl.contains('YOUR-SUBDOMAIN')) return const {};
      final token = await user.getIdToken();
      final res = await http
          .post(
        Uri.parse('${AppConfig.notifyWorkerUrl}/notify'),
        headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
        body: jsonEncode({
          'event': event,
          if (jobId != null) 'jobId': jobId,
          if (bookingId != null) 'bookingId': bookingId,
        }),
      )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('notify $event: ${res.statusCode} ${res.body}');
        return const {};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('notify $event failed: $e');
      return const {};
    }
  }

  /// Tells the other person on the booking that a chat message arrived.
  /// The Worker reads the message from the chat document itself.
  Future<void> notifyChat(String bookingId) async {
    await _notify('chat', bookingId: bookingId);
  }

  // ═══ Customer: requests ══════════════════════════════════════════════════

  /// Request id made on the phone, so photos can be uploaded into its folder first.
  String newJobId() => _db.collection('jobs').doc().id;

  /// Creates the request. Returns how many nearby helpers were alerted.
  Future<int> createJobRequest({
    required String jobId,
    required ServiceSubcategory subcategory,
    required String description,
    required String language,
    required List<String> photoUrls,
    String? audioUrl,
    int audioDurationSec = 0,
    required JobSlot slot,
    required String addressLine,
    required String houseNo,
    required String landmark,
    required String areaName,
    required double lat,
    required double lng,
  }) async {
    if (uid.isEmpty) throw const ApiException('Please sign in again.');
    final userRef = _db.collection('users').doc(uid);
    final jobRef = _db.collection('jobs').doc(jobId);

    final userSnap = await userRef.get();
    final fullName = (userSnap.data()?['fullName'] as String? ??
        FirebaseAuth.instance.currentUser?.displayName ??
        '')
        .trim();
    final firstName = fullName.isEmpty ? 'Customer' : fullName.split(RegExp(r'\s+')).first;
    final lastJobAt = (userSnap.data()?['lastJobAt'] as Timestamp?)?.toDate();
    if (lastJobAt != null && DateTime.now().difference(lastJobAt) < const Duration(minutes: 2)) {
      throw const ApiException('Please wait 2 minutes before posting another request.');
    }

    // Deadlines (firestore.rules checks these windows).
    final now = DateTime.now();
    final DateTime pitchDeadline;
    final DateTime expiresAt;
    final JobSlot s;
    if (slot.isNow) {
      s = JobSlot(isNow: true, start: now, end: now.add(const Duration(hours: 2)));
      pitchDeadline = now.add(AppConfig.nowPitchWindow);
      expiresAt = now.add(AppConfig.nowExpiry);
    } else {
      s = slot;
      final byWindow = now.add(AppConfig.scheduledPitchWindowMax);
      final byStart = slot.start.subtract(const Duration(hours: 1));
      pitchDeadline = byWindow.isBefore(byStart) ? byWindow : byStart;
      expiresAt = DateTime.fromMillisecondsSinceEpoch(slot.start.millisecondsSinceEpoch - 1800000);
    }

    final batch = _db.batch();
    batch.set(userRef, {'lastJobAt': _now}, SetOptions(merge: true));
    batch.set(jobRef, {
      'customerId': uid,
      'customerFirstName': firstName.length > 40 ? firstName.substring(0, 40) : firstName,
      'categoryId': subcategory.categoryId,
      'subcategoryId': subcategory.id,
      'serviceName': subcategory.en,
      'description': description,
      'language': language,
      'photoUrls': photoUrls,
      'audioUrl': audioUrl ?? '',
      'audioDurationSec': audioUrl == null ? 0 : audioDurationSec,
      'areaName': areaName.length > 100 ? areaName.substring(0, 100) : areaName,
      'approxLat': approx(lat),
      'approxLng': approx(lng),
      'geohash5': geohash(lat, lng, 5),
      'slot': s.toMap(),
      'status': 'open',
      'pitchDeadline': Timestamp.fromDate(pitchDeadline),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'bookedHelperId': null,
      'bookingId': null,
      'createdAt': _now,
      'updatedAt': _now,
    });
    batch.set(jobRef.collection('private').doc('location'), {
      'line': addressLine,
      'houseNo': houseNo,
      'landmark': landmark,
      'areaName': areaName.length > 100 ? areaName.substring(0, 100) : areaName,
      'lat': lat,
      'lng': lng,
    });

    await _guard(
      batch.commit,
      'Could not send the request. Wait 2 minutes between requests, and make sure your phone\'s '
          'date & time are set to automatic.',
    );
    final r = await _notify('job_created', jobId: jobId);
    return (r['notifiedCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> cancelJobRequest(String jobId) => _guard(
        () => _db.collection('jobs').doc(jobId).update({'status': 'cancelled', 'updatedAt': _now}),
    'This request can no longer be cancelled here.',
  );

  Stream<List<JobRequest>> myRequests({int limit = 30}) {
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(JobRequest.fromDoc).toList());
  }

  Stream<JobRequest?> job(String jobId) =>
      _db.collection('jobs').doc(jobId).snapshots().map((d) => d.exists ? JobRequest.fromDoc(d) : null);

  final Map<String, HelperStats> _helperCache = {};

  /// Active quotes on a request, joined with each helper's profile and ranked.
  Stream<List<RankedPitch>> rankedPitches(JobRequest job) => _db
      .collection('jobs')
      .doc(job.id)
      .collection('pitches')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .asyncMap((s) async {
    final pitches = s.docs.map(Pitch.fromDoc).toList();
    final missing = pitches.map((p) => p.helperId).where((id) => !_helperCache.containsKey(id)).toList();
    for (var i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(i, min(i + 30, missing.length));
      final hs = await _db.collection('helpers').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in hs.docs) {
        _helperCache[d.id] = HelperStats.fromDoc(d);
      }
    }
    return rankPitches(pitches, _helperCache, job.createdAt);
  });

  /// Books a helper. Creates the booking, start code, contact, chat and ML log
  /// in ONE batch (all or nothing). Returns the booking id.
  Future<String> acceptPitch(JobRequest job, RankedPitch chosen, List<RankedPitch> shown) async {
    final helperId = chosen.pitch.helperId;
    final bookingId = '${job.id}_$helperId';
    final jobRef = _db.collection('jobs').doc(job.id);
    final bookingRef = _db.collection('bookings').doc(bookingId);

    final results = await Future.wait([
      _db.collection('users').doc(uid).get(),
      jobRef.collection('private').doc('location').get(),
      _db.collection('helpers').doc(helperId).get(),
    ]);
    final me = results[0].data() ?? const <String, dynamic>{};
    final loc = results[1].data();
    final helper = results[2].data() ?? const <String, dynamic>{};
    if (loc == null) throw const ApiException('Request address is missing. Please post the request again.');

    final customerName = ((me['fullName'] as String?)?.trim().isNotEmpty ?? false)
        ? (me['fullName'] as String).trim()
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Customer');
    final helperName = (helper['name'] as String?) ?? chosen.helper.name;
    final helperPhoto = (helper['photoUrl'] as String?) ?? '';
    final code = (Random.secure().nextInt(10000)).toString().padLeft(4, '0');

    final batch = _db.batch();
    batch.set(bookingRef, {
      'bookingId': bookingId,
      'jobId': job.id,
      'customerId': uid,
      'customerName': customerName.length > 80 ? customerName.substring(0, 80) : customerName,
      'helperId': helperId,
      'helperName': helperName.length > 80 ? helperName.substring(0, 80) : helperName,
      'helperPhotoUrl': helperPhoto.length > 500 ? '' : helperPhoto,
      'subcategoryId': job.subcategoryId,
      'serviceName': job.serviceName,
      'description': job.description,
      'photoUrls': job.photoUrls,
      'audioUrl': job.audioUrl ?? '',
      'address': loc,
      'slot': job.slot.toMap(),
      'agreedAmount': chosen.pitch.amount,
      'status': 'confirmed',
      'statusAt': {'confirmed': _now},
      'paymentMethod': null,
      'customerPaidAt': null,
      'workDoneAt': null,
      'completedAt': null,
      'cancelledBy': null,
      'cancelReason': '',
      'customerReviewed': false,
      'helperReviewed': false,
      'createdAt': _now,
      'updatedAt': _now,
    });
    batch.set(bookingRef.collection('private').doc('secret'), {'startCode': code});
    batch.set(bookingRef.collection('private').doc('contact'), {
      'customerPhone': ((me['phone'] as String?) ?? '').length > 20 ? '' : (me['phone'] as String? ?? ''),
      'helperPhone': '',
    });
    batch.update(jobRef, {'status': 'booked', 'bookedHelperId': helperId, 'bookingId': bookingId, 'updatedAt': _now});
    batch.set(_db.collection('chats').doc(bookingId), {
      'chatId': bookingId,
      'bookingId': bookingId,
      'jobId': job.id,
      'participants': [uid, helperId],
      'customerId': uid,
      'helperId': helperId,
      'customerName': customerName,
      'userName': customerName,
      'helperName': helperName,
      'otherName': helperName,
      'helperPhoto': helperPhoto,
      'serviceName': job.serviceName,
      'bookingStatus': 'confirmed',
      'lastMessage': '',
      'lastMessageTime': _now,
      'createdAt': _now,
    });
    batch.set(_db.collection('ranking_events').doc(), {
      'customerId': uid,
      'jobId': job.id,
      'subcategoryId': job.subcategoryId,
      'chosenHelperId': helperId,
      'items': [for (final r in shown) {...rankingFeatures(r, job.createdAt), 'chosen': r.pitch.helperId == helperId}],
      'createdAt': _now,
    });

    await _guard(batch.commit,
        'This quote is no longer available (the helper changed or withdrew it, or the request expired).');
    _notify('booking', bookingId: bookingId);
    return bookingId;
  }

  // ═══ Helper: nearby requests and quotes ══════════════════════════════════

  /// Open requests within 5 km that match the helper's services.
  Stream<List<NearbyJob>> nearbyOpenJobs({
    required double lat,
    required double lng,
    required Set<String> serviceIds,
  }) {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .where('geohash5', whereIn: nearbyCells(lat, lng))
        .snapshots()
        .map((s) {
      final now = DateTime.now();
      final out = <NearbyJob>[];
      for (final d in s.docs) {
        final j = JobRequest.fromDoc(d);
        if (j.customerId == uid) continue;
        if (!serviceIds.contains(j.subcategoryId)) continue;
        if (j.pitchDeadline == null || !j.pitchDeadline!.isAfter(now)) continue;
        final km = kmBetween(lat, lng, j.approxLat, j.approxLng);
        if (km <= AppConfig.searchRadiusKm + 0.5) out.add(NearbyJob(j, double.parse(km.toStringAsFixed(1))));
      }
      out.sort((a, b) => a.job.pitchDeadline!.compareTo(b.job.pitchDeadline!));
      return out;
    });
  }

  /// All of this helper's quotes, by request id.
  Stream<Map<String, Pitch>> myPitches() {
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collectionGroup('pitches')
        .where('helperId', isEqualTo: uid)
        .snapshots()
        .map((s) => {for (final d in s.docs) (d.data()['jobId'] as String? ?? ''): Pitch.fromDoc(d)});
  }

  Stream<Pitch?> myPitch(String jobId) => _db
      .collection('jobs')
      .doc(jobId)
      .collection('pitches')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Pitch.fromDoc(d) : null);

  Future<void> submitPitch({
    required JobRequest job,
    required int amount,
    required String note,
    int? etaMinutes,
    required double distanceKm,
  }) async {
    final ref = _db.collection('jobs').doc(job.id).collection('pitches').doc(uid);
    final existing = await ref.get();
    final dist = double.parse(distanceKm.clamp(0, 6).toStringAsFixed(1));
    await _guard(() async {
      if (!existing.exists) {
        await ref.set({
          'jobId': job.id,
          'helperId': uid,
          'amount': amount,
          'note': note,
          'etaMinutes': etaMinutes,
          'distanceKm': dist,
          'status': 'active',
          'edits': 0,
          'createdAt': _now,
          'updatedAt': _now,
        });
      } else {
        final edits = (existing.data()?['edits'] as num?)?.toInt() ?? 0;
        if (edits >= AppConfig.pitchMaxEdits) {
          throw const ApiException('You have already changed this price 3 times.');
        }
        await ref.update({
          'amount': amount,
          'note': note,
          'etaMinutes': etaMinutes,
          'distanceKm': dist,
          'status': 'active',
          'edits': edits + 1,
          'updatedAt': _now,
        });
      }
    }, 'Could not send your price. The request may have closed, or your KYC is not approved yet.');
    _notify('pitch', jobId: job.id);
  }

  Future<void> withdrawPitch(String jobId) => _guard(
        () => _db
        .collection('jobs')
        .doc(jobId)
        .collection('pitches')
        .doc(uid)
        .update({'status': 'withdrawn', 'updatedAt': _now}),
    'This price can no longer be withdrawn.',
  );

  // ═══ Bookings (both sides) ═══════════════════════════════════════════════

  Stream<List<Booking>> myBookings({required bool asHelper, int limit = 50}) {
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('bookings')
        .where(asHelper ? 'helperId' : 'customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
    // Only bookings from the new request → quote flow (they have a jobId).
        .map((s) => s.docs.where((d) => '${d.data()['jobId'] ?? ''}'.isNotEmpty).map(Booking.fromDoc).toList());
  }

  /// Completed bookings this person still has to review (inside the 14-day window).
  /// Customers must rate before posting a new request; helpers before sending a new price.
  Future<List<Booking>> pendingReviews({required bool asHelper}) async {
    if (uid.isEmpty) return const [];
    try {
      final s = await _db
          .collection('bookings')
          .where(asHelper ? 'helperId' : 'customerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .limit(30)
          .get();
      final now = DateTime.now();
      return s.docs
          .where((d) => '${d.data()['jobId'] ?? ''}'.isNotEmpty)
          .map(Booking.fromDoc)
          .where((b) =>
      !(asHelper ? b.helperReviewed : b.customerReviewed) &&
          b.completedAt != null &&
          now.isBefore(b.completedAt!.add(const Duration(days: 14))))
          .toList()
        ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    } catch (e) {
      debugPrint('pendingReviews: $e');
      return const [];
    }
  }

  /// Bookings made with the old app version (read-only history).
  Stream<List<Map<String, dynamic>>> legacyBookings() {
    if (uid.isEmpty) return const Stream.empty();
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), '_id': d.id}).toList())
        .handleError((_) {});
  }

  Stream<Booking?> booking(String id) =>
      _db.collection('bookings').doc(id).snapshots().map((d) => d.exists ? Booking.fromDoc(d) : null);

  /// Customer only: the 4-digit code the helper must enter to start work.
  Stream<String?> startCode(String bookingId) => _db
      .collection('bookings')
      .doc(bookingId)
      .collection('private')
      .doc('secret')
      .snapshots()
      .map((d) => d.data()?['startCode'] as String?);

  /// Phone numbers (both parties, while the booking is active).
  Future<({String customerPhone, String helperPhone})?> contact(String bookingId) async {
    try {
      final d = await _db.collection('bookings').doc(bookingId).collection('private').doc('contact').get();
      final m = d.data();
      if (m == null) return null;
      return (customerPhone: '${m['customerPhone'] ?? ''}', helperPhone: '${m['helperPhone'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  /// Helper side: adds the helper's phone to the booking contact (once).
  Future<void> shareHelperPhone(String bookingId) async {
    try {
      final c = await contact(bookingId);
      if (c == null || c.helperPhone.isNotEmpty) return;
      final h = await _db.collection('helpers').doc(uid).get();
      final phone = '${h.data()?['phone'] ?? h.data()?['phoneNumber'] ?? ''}';
      if (phone.isEmpty || phone.length > 20) return;
      await _db
          .collection('bookings')
          .doc(bookingId)
          .collection('private')
          .doc('contact')
          .update({'helperPhone': phone});
    } catch (e) {
      debugPrint('shareHelperPhone: $e');
    }
  }

  /// action:
  ///   helper:   start_trip | arrive | start_work(code) | mark_done | confirm_received | cancel(reason)
  ///   customer: confirm_paid(method) | close_job | regenerate_code | cancel(reason)
  ///   both:     report_issue(reason)
  Future<void> bookingAction(Booking b, String action, {String? code, String? reason, String? method}) async {
    final ref = _db.collection('bookings').doc(b.id);
    final jobRef = _db.collection('jobs').doc(b.jobId);
    final isHelper = uid == b.helperId;
    Map<String, dynamic> step(String to, [Map<String, dynamic> extra = const {}]) =>
        {'status': to, 'statusAt.$to': _now, 'updatedAt': _now, ...extra};

    String denied = 'This step is not possible right now. Pull to refresh and try again.';
    final batch = _db.batch();
    var notify = true;

    switch (action) {
      case 'start_trip':
        batch.update(ref, step('on_the_way'));
      case 'arrive':
        batch.update(ref, step('arrived'));
      case 'start_work':
        batch.update(ref, step('in_progress', {'startCode': code ?? ''}));
        denied = 'Wrong code. Ask the customer for the 4-digit code shown in their app.';
      case 'mark_done':
        batch.update(ref, step('work_done', {'workDoneAt': _now}));
      case 'confirm_received':
      case 'close_job':
        batch.update(ref, step('completed', {'completedAt': _now}));
        batch.update(_db.collection('helpers').doc(b.helperId),
            {'completedJobs': FieldValue.increment(1), 'lastCompletedBookingId': b.id});
        batch.update(jobRef, {'status': 'completed', 'updatedAt': _now});
        if (action == 'close_job') denied = 'You can close the job 24 hours after the helper marked it done.';
      case 'confirm_paid':
        batch.update(ref, {'paymentMethod': method, 'customerPaidAt': _now, 'updatedAt': _now});
      case 'regenerate_code':
        batch.set(ref.collection('private').doc('secret'),
            {'startCode': Random.secure().nextInt(10000).toString().padLeft(4, '0')});
        notify = false;
      case 'cancel':
        final r = (reason ?? '').trim();
        if (r.length < 3) throw const ApiException('Please give a reason.');
        batch.update(ref, step('cancelled', {'cancelledBy': isHelper ? 'helper' : 'customer', 'cancelReason': r}));
        if (isHelper) {
          // Request reopens so the customer can choose another quote.
          batch.update(jobRef, {'status': 'open', 'bookedHelperId': null, 'bookingId': null, 'updatedAt': _now});
          batch.update(jobRef.collection('pitches').doc(uid), {'status': 'cancelled', 'updatedAt': _now});
          batch.update(_db.collection('helpers').doc(uid),
              {'cancelCount': FieldValue.increment(1), 'lastCancelledBookingId': b.id});
        } else {
          batch.update(jobRef, {'status': 'cancelled', 'updatedAt': _now});
        }
        denied = 'This booking can no longer be cancelled (the helper has already arrived).';
      case 'report_issue':
        final r = (reason ?? '').trim();
        if (r.length < 10) throw const ApiException('Please describe the problem (at least 10 characters).');
        batch.set(_db.collection('reports').doc(), {
          'bookingId': b.id,
          'reporterId': uid,
          'reporterRole': isHelper ? 'helper' : 'customer',
          'reason': r.length > 300 ? r.substring(0, 300) : r,
          'status': 'open',
          'createdAt': _now,
        });
        notify = false;
      default:
        throw ApiException('Unknown action $action');
    }

    await _guard(batch.commit, denied);
    // Keep the chat list label in sync (best effort).
    if (action != 'report_issue' && action != 'regenerate_code' && action != 'confirm_paid') {
      _db.collection('chats').doc(b.id).update({
        'bookingStatus': switch (action) {
          'start_trip' => 'on_the_way',
          'arrive' => 'arrived',
          'start_work' => 'in_progress',
          'mark_done' => 'work_done',
          'cancel' => 'cancelled',
          _ => 'completed',
        },
      }).catchError((_) {});
    }
    if (notify) _notify('booking', bookingId: b.id);
  }

  /// One review per side. The review and the target's rating totals are
  /// written in one transaction; the rules check the totals add up.
  Future<void> submitReview({
    required Booking booking,
    required bool asCustomer,
    required int rating,
    required List<String> tags,
    String comment = '',
  }) async {
    final role = asCustomer ? 'customer' : 'helper';
    final reviewId = '${booking.id}_$role';
    final positive = (asCustomer ? customerToHelperTags : helperToCustomerTags)
        .where((t) => t.positive)
        .map((t) => t.id)
        .toSet();
    final pos = tags.where(positive.contains).length;
    final targetRef = asCustomer
        ? _db.collection('helpers').doc(booking.helperId)
        : _db.collection('user_ratings').doc(booking.customerId);
    final reviewRef = _db.collection('reviews').doc(reviewId);
    final myName = asCustomer ? booking.customerName : booking.helperName;

    final bookingRef = _db.collection('bookings').doc(booking.id);
    final otherReviewRef = _db.collection('reviews').doc('${booking.id}_${asCustomer ? 'helper' : 'customer'}');

    await _guard(() => _db.runTransaction((tx) async {
      // Has the other person already reviewed? (Their review is hidden from
      // us until we review, so we read the flag on the booking instead.)
      final bk = await tx.get(bookingRef);
      final otherReviewed = bk.data()?[asCustomer ? 'helperReviewed' : 'customerReviewed'] == true;
      final t = await tx.get(targetRef);
      final old = t.data() ?? const <String, dynamic>{};
      final sum = ((old['ratingSum'] as num?)?.toInt() ?? 0) + rating;
      final count = ((old['ratingCount'] as num?)?.toInt() ?? 0) + 1;
      tx.set(reviewRef, {
        'bookingId': booking.id,
        'fromUid': uid,
        'fromRole': role,
        'fromFirstName': myName.split(' ').first,
        'toUid': asCustomer ? booking.helperId : booking.customerId,
        'rating': rating,
        'tags': tags,
        'posCount': pos,
        'negCount': tags.length - pos,
        'comment': comment.length > 500 ? comment.substring(0, 500) : comment,
        'serviceName': booking.serviceName,
        'subcategoryId': booking.subcategoryId,
        // Double-blind: visible straight away only if the other side already reviewed.
        'visible': otherReviewed,
        'createdAt': _now,
      });
      // Both have now reviewed → reveal the other person's review too.
      if (otherReviewed) tx.update(otherReviewRef, {'visible': true});
      tx.set(
        targetRef,
        {
          'ratingSum': sum,
          'ratingCount': count,
          'rating': sum / count,
          'tagPos': ((old['tagPos'] as num?)?.toInt() ?? 0) + pos,
          'tagNeg': ((old['tagNeg'] as num?)?.toInt() ?? 0) + (tags.length - pos),
          'lastReviewId': reviewId,
        },
        SetOptions(merge: true),
      );
      tx.update(bookingRef, {asCustomer ? 'customerReviewed' : 'helperReviewed': true, 'updatedAt': _now});
    }), 'You have already reviewed this job, the 14-day review window has closed, or the job is not completed yet.');
    // Tell the other person ("X rated you — rate them to see it" / "reviews are visible").
    _notify('booking', bookingId: booking.id);
  }

  /// Your review and the other person's review of this booking.
  /// The other review is null while it is still hidden (or not written yet).
  Stream<Map<String, dynamic>?> review(String bookingId, String role) => _db
      .collection('reviews')
      .doc('${bookingId}_$role')
      .snapshots()
      .map((d) => d.data())
      .handleError((_) {});

  /// After the 14-day window, either side may reveal reviews that are still hidden.
  Future<void> revealDueReviews(Booking b) async {
    final done = b.completedAt;
    if (done == null || DateTime.now().isBefore(done.add(const Duration(days: 14, minutes: 5)))) return;
    for (final role in const ['customer', 'helper']) {
      try {
        await _db.collection('reviews').doc('${b.id}_$role').update({'visible': true});
      } catch (_) {
        // Not written, already visible, or not allowed yet — nothing to do.
      }
    }
  }

  // ═══ Helper KYC ══════════════════════════════════════════════════════════

  /// Aadhaar/PAN go to helpers_private (only the helper and admins can read it).
  Future<void> submitKyc({required String aadhaar, required String pan}) async {
    final a = aadhaar.replaceAll(RegExp(r'\s'), '');
    final p = pan.trim().toUpperCase();
    if (!RegExp(r'^[2-9][0-9]{11}$').hasMatch(a)) throw const ApiException('Aadhaar number is not valid.');
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(p)) throw const ApiException('PAN is not valid (ABCDE1234F).');
    final batch = _db.batch();
    batch.set(_db.collection('helpers_private').doc(uid),
        {'kyc': {'aadhaar': a, 'pan': p, 'submittedAt': _now}}, SetOptions(mergeFields: ['kyc']));
    batch.update(_db.collection('helpers').doc(uid),
        {'kycStatus': 'pending', 'kycSubmittedAt': _now, 'updatedAt': _now});
    await _guard(batch.commit, 'Could not submit KYC. If it is already approved, no action is needed.');
  }
}