// lib/core/job_models.dart
// Data contract for requests (jobs), price quotes (pitches) and bookings.
// IDENTICAL in Trouble Sarthi and Sarthi Kendra. Field names must match
// firestore.rules exactly, because the rules check every write.

import 'package:cloud_firestore/cloud_firestore.dart';

int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
double _dbl(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;
String _str(dynamic v, [String d = '']) => v is String ? v : d;
DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strList(dynamic v) => v is List ? v.whereType<String>().toList() : const <String>[];
String? _nonEmpty(dynamic v) => v is String && v.isNotEmpty ? v : null;

// ─── Time slot ──────────────────────────────────────────────────────────────

class JobSlot {
  final bool isNow;
  final DateTime start;
  final DateTime end;
  const JobSlot({required this.isNow, required this.start, required this.end});

  factory JobSlot.fromMap(Map<String, dynamic>? m) {
    final now = DateTime.now();
    if (m == null) return JobSlot(isNow: true, start: now, end: now);
    return JobSlot(
      isNow: m['type'] == 'now',
      start: DateTime.fromMillisecondsSinceEpoch(_int(m['startMs'], now.millisecondsSinceEpoch)),
      end: DateTime.fromMillisecondsSinceEpoch(_int(m['endMs'], now.millisecondsSinceEpoch)),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': isNow ? 'now' : 'scheduled',
    'startMs': start.millisecondsSinceEpoch,
    'endMs': end.millisecondsSinceEpoch,
  };

  bool overlaps(JobSlot o) => start.isBefore(o.end) && o.start.isBefore(end);
}

// ─── Request (job) ──────────────────────────────────────────────────────────

enum JobStatus { open, booked, completed, expired, cancelled, unknown }

class JobRequest {
  final String id;
  final String customerId;
  final String customerFirstName;
  final String categoryId;
  final String subcategoryId;
  final String serviceName;
  final String description;
  final String language;
  final List<String> photoUrls;
  final String? audioUrl;
  final int audioDurationSec;
  final String areaName;
  final double approxLat;
  final double approxLng;
  final JobSlot slot;
  final String rawStatus;
  final DateTime? pitchDeadline;
  final DateTime? expiresAt;
  final String? bookedHelperId;
  final String? bookingId;
  final int notifiedCount;
  final DateTime? createdAt;

  const JobRequest({
    required this.id,
    required this.customerId,
    required this.customerFirstName,
    required this.categoryId,
    required this.subcategoryId,
    required this.serviceName,
    required this.description,
    required this.language,
    required this.photoUrls,
    required this.audioUrl,
    required this.audioDurationSec,
    required this.areaName,
    required this.approxLat,
    required this.approxLng,
    required this.slot,
    required this.rawStatus,
    required this.pitchDeadline,
    required this.expiresAt,
    required this.bookedHelperId,
    required this.bookingId,
    required this.notifiedCount,
    required this.createdAt,
  });

  factory JobRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return JobRequest(
      id: doc.id,
      customerId: _str(d['customerId']),
      customerFirstName: _str(d['customerFirstName'], 'Customer'),
      categoryId: _str(d['categoryId']),
      subcategoryId: _str(d['subcategoryId']),
      serviceName: _str(d['serviceName']),
      description: _str(d['description']),
      language: _str(d['language'], 'en'),
      photoUrls: _strList(d['photoUrls']),
      audioUrl: _nonEmpty(d['audioUrl']),
      audioDurationSec: _int(d['audioDurationSec']),
      areaName: _str(d['areaName']),
      approxLat: _dbl(d['approxLat']),
      approxLng: _dbl(d['approxLng']),
      slot: JobSlot.fromMap(d['slot'] as Map<String, dynamic>?),
      rawStatus: _str(d['status']),
      pitchDeadline: _ts(d['pitchDeadline']),
      expiresAt: _ts(d['expiresAt']),
      bookedHelperId: _nonEmpty(d['bookedHelperId']),
      bookingId: _nonEmpty(d['bookingId']),
      notifiedCount: _int(d['notifiedCount']),
      createdAt: _ts(d['createdAt']),
    );
  }

  /// Status as the user should see it. There is no server to expire requests,
  /// so an open request past its expiry time is shown as expired (the rules
  /// also refuse late quotes and late bookings).
  JobStatus get status {
    switch (rawStatus) {
      case 'open':
        return (expiresAt != null && expiresAt!.isBefore(DateTime.now())) ? JobStatus.expired : JobStatus.open;
      case 'booked':
        return JobStatus.booked;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.unknown;
    }
  }

  bool get acceptingPitches =>
      rawStatus == 'open' && pitchDeadline != null && pitchDeadline!.isAfter(DateTime.now());
}

/// An open request as a helper sees it in their feed.
class NearbyJob {
  final JobRequest job;
  final double distanceKm;
  const NearbyJob(this.job, this.distanceKm);
}

// ─── Pitch (a helper's price quote) ─────────────────────────────────────────

enum PitchStatus { active, withdrawn, cancelled, unknown }

class Pitch {
  final String jobId;
  final String helperId;
  final int amount;
  final String note;
  final int? etaMinutes;
  final double distanceKm;
  final PitchStatus status;
  final int edits;
  final DateTime? createdAt;

  const Pitch({
    required this.jobId,
    required this.helperId,
    required this.amount,
    required this.note,
    required this.etaMinutes,
    required this.distanceKm,
    required this.status,
    required this.edits,
    required this.createdAt,
  });

  factory Pitch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final eta = d['etaMinutes'];
    return Pitch(
      jobId: _str(d['jobId']),
      helperId: doc.id,
      amount: _int(d['amount']),
      note: _str(d['note']),
      etaMinutes: eta is num ? eta.toInt() : null,
      distanceKm: _dbl(d['distanceKm']),
      status: switch (_str(d['status'])) {
        'active' => PitchStatus.active,
        'withdrawn' => PitchStatus.withdrawn,
        'cancelled' => PitchStatus.cancelled,
        _ => PitchStatus.unknown,
      },
      edits: _int(d['edits']),
      createdAt: _ts(d['createdAt']),
    );
  }
}

/// Public numbers from a helper's profile, used for ranking and display.
class HelperStats {
  final String id;
  final String name;
  final String photoUrl;
  final double rating;
  final int ratingCount;
  final int completedJobs;
  final int cancelCount;
  final int tagPos;
  final int tagNeg;
  final int experienceYears;

  const HelperStats({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.ratingCount,
    required this.completedJobs,
    required this.cancelCount,
    required this.tagPos,
    required this.tagNeg,
    required this.experienceYears,
  });

  factory HelperStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return HelperStats(
      id: doc.id,
      name: _str(d['name'], 'Helper'),
      photoUrl: _str(d['photoUrl']),
      // Ratings written by the new review flow (ratingSum / ratingCount); old docs had only 'rating'.
      rating: _dbl(d['rating']),
      ratingCount: _int(d['ratingCount']),
      completedJobs: _int(d['completedJobs']),
      cancelCount: _int(d['cancelCount']),
      tagPos: _int(d['tagPos']),
      tagNeg: _int(d['tagNeg']),
      experienceYears: _int(d['experience']),
    );
  }
}

/// A quote joined with the helper's stats and the computed rank.
class RankedPitch {
  final Pitch pitch;
  final HelperStats helper;
  final double score;
  final int rank;
  final List<String> badges;
  const RankedPitch(this.pitch, this.helper, this.score, this.rank, this.badges);
}

String badgeLabel(String b) => switch (b) {
  'best_match' => 'Best match',
  'lowest_price' => 'Lowest price',
  'top_rated' => 'Top rated',
  'nearest' => 'Nearest',
  'new_helper' => 'New on Sarthi',
  _ => b,
};

// ─── Booking ────────────────────────────────────────────────────────────────

enum BookingStatus { confirmed, onTheWay, arrived, inProgress, workDone, completed, cancelled, unknown }

const _statusKeys = {
  'confirmed': BookingStatus.confirmed,
  'on_the_way': BookingStatus.onTheWay,
  'arrived': BookingStatus.arrived,
  'in_progress': BookingStatus.inProgress,
  'work_done': BookingStatus.workDone,
  'completed': BookingStatus.completed,
  'cancelled': BookingStatus.cancelled,
};

BookingStatus parseBookingStatus(String s) => _statusKeys[s] ?? BookingStatus.unknown;

/// The key Firestore stores for a status ('on_the_way', …).
String bookingStatusKey(BookingStatus s) =>
    _statusKeys.entries.firstWhere((e) => e.value == s, orElse: () => const MapEntry('unknown', BookingStatus.unknown)).key;

const activeBookingStatuses = {
  BookingStatus.confirmed,
  BookingStatus.onTheWay,
  BookingStatus.arrived,
  BookingStatus.inProgress,
  BookingStatus.workDone,
};

const bookingSteps = [
  BookingStatus.confirmed,
  BookingStatus.onTheWay,
  BookingStatus.arrived,
  BookingStatus.inProgress,
  BookingStatus.workDone,
  BookingStatus.completed,
];

String bookingStatusLabel(BookingStatus s) => switch (s) {
  BookingStatus.confirmed => 'Confirmed',
  BookingStatus.onTheWay => 'On the way',
  BookingStatus.arrived => 'Arrived',
  BookingStatus.inProgress => 'Work in progress',
  BookingStatus.workDone => 'Work done',
  BookingStatus.completed => 'Completed',
  BookingStatus.cancelled => 'Cancelled',
  BookingStatus.unknown => 'Updating…',
};

class BookingAddress {
  final String line, houseNo, landmark, areaName;
  final double lat, lng;
  const BookingAddress(this.line, this.houseNo, this.landmark, this.areaName, this.lat, this.lng);

  factory BookingAddress.fromMap(Map<String, dynamic>? m) => BookingAddress(
    _str(m?['line']),
    _str(m?['houseNo']),
    _str(m?['landmark']),
    _str(m?['areaName']),
    _dbl(m?['lat']),
    _dbl(m?['lng']),
  );

  String get full => [houseNo, line, if (landmark.isNotEmpty) 'Near $landmark']
      .where((s) => s.trim().isNotEmpty)
      .join(', ');
}

class Booking {
  final String id;
  final String jobId;
  final String customerId;
  final String customerName;
  final String helperId;
  final String helperName;
  final String helperPhotoUrl;
  final String subcategoryId;
  final String serviceName;
  final String description;
  final List<String> photoUrls;
  final String? audioUrl;
  final BookingAddress address;
  final JobSlot slot;
  final int agreedAmount;
  final BookingStatus status;
  final Map<String, DateTime?> statusAt;
  final String? cancelledBy;
  final String cancelReason;
  final String? paymentMethod;
  final DateTime? customerPaidAt;
  final DateTime? workDoneAt;
  final DateTime? completedAt;
  final bool customerReviewed;
  final bool helperReviewed;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    required this.jobId,
    required this.customerId,
    required this.customerName,
    required this.helperId,
    required this.helperName,
    required this.helperPhotoUrl,
    required this.subcategoryId,
    required this.serviceName,
    required this.description,
    required this.photoUrls,
    required this.audioUrl,
    required this.address,
    required this.slot,
    required this.agreedAmount,
    required this.status,
    required this.statusAt,
    required this.cancelledBy,
    required this.cancelReason,
    required this.paymentMethod,
    required this.customerPaidAt,
    required this.workDoneAt,
    required this.completedAt,
    required this.customerReviewed,
    required this.helperReviewed,
    required this.createdAt,
  });

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawAt = (d['statusAt'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return Booking(
      id: doc.id,
      jobId: _str(d['jobId']),
      customerId: _str(d['customerId']),
      customerName: _str(d['customerName'], 'Customer'),
      helperId: _str(d['helperId']),
      helperName: _str(d['helperName'], 'Helper'),
      helperPhotoUrl: _str(d['helperPhotoUrl']),
      subcategoryId: _str(d['subcategoryId']),
      serviceName: _str(d['serviceName']),
      description: _str(d['description']),
      photoUrls: _strList(d['photoUrls']),
      audioUrl: _nonEmpty(d['audioUrl']),
      address: BookingAddress.fromMap(d['address'] as Map<String, dynamic>?),
      slot: JobSlot.fromMap(d['slot'] as Map<String, dynamic>?),
      agreedAmount: _int(d['agreedAmount']),
      status: parseBookingStatus(_str(d['status'])),
      statusAt: rawAt.map((k, v) => MapEntry(k, _ts(v))),
      cancelledBy: _nonEmpty(d['cancelledBy']),
      cancelReason: _str(d['cancelReason']),
      paymentMethod: _nonEmpty(d['paymentMethod']),
      customerPaidAt: _ts(d['customerPaidAt']),
      workDoneAt: _ts(d['workDoneAt']),
      completedAt: _ts(d['completedAt']),
      customerReviewed: d['customerReviewed'] == true,
      helperReviewed: d['helperReviewed'] == true,
      createdAt: _ts(d['createdAt']),
    );
  }

  bool get isActive => activeBookingStatuses.contains(status);
  bool get canCancel => status == BookingStatus.confirmed || status == BookingStatus.onTheWay;

  /// Customer may close the job 24 h after "work done" if the helper never confirmed payment.
  bool get customerCanClose =>
      status == BookingStatus.workDone &&
          workDoneAt != null &&
          DateTime.now().isAfter(workDoneAt!.add(const Duration(hours: 24)));

  /// Chat stays open while active and for 7 days after completion.
  /// Chat is open only while the job is active (firestore.rules agrees).
  bool get chatOpen => isActive;

  DateTime? timeOf(BookingStatus s) => statusAt[bookingStatusKey(s)];
}

// ─── Review tags (must match allowedTags() in firestore.rules) ──────────────

class ReviewTag {
  final String id;
  final String label;
  final bool positive;
  const ReviewTag(this.id, this.label, this.positive);
}

const customerToHelperTags = [
  ReviewTag('on_time', 'On time', true),
  ReviewTag('fair_price', 'Fair price', true),
  ReviewTag('quality_work', 'Quality work', true),
  ReviewTag('polite', 'Polite', true),
  ReviewTag('clean_work', 'Clean work', true),
  ReviewTag('late', 'Late', false),
  ReviewTag('overcharged', 'Asked for more money', false),
  ReviewTag('poor_work', 'Poor work', false),
  ReviewTag('rude', 'Rude', false),
  ReviewTag('messy', 'Left a mess', false),
];

const helperToCustomerTags = [
  ReviewTag('clear_instructions', 'Clear instructions', true),
  ReviewTag('respectful', 'Respectful', true),
  ReviewTag('paid_promptly', 'Paid promptly', true),
  ReviewTag('hard_to_reach', 'Hard to reach', false),
  ReviewTag('disrespectful', 'Disrespectful', false),
  ReviewTag('payment_issue', 'Payment issue', false),
];