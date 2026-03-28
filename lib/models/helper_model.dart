// lib/models/helper_model.dart
// Complete model — all fields, getters, copyWith, fromMap, toMap

class HelperModel {
  final String       uid;
  final String       name;
  final String       username;
  final String       email;
  final String       phone;
  final List<String> services;
  final String       area;
  final String       status;      // pending | submitted | approved | rejected | inactive
  final double       rating;
  final int          totalJobs;
  final bool         kycDone;
  final bool         kycSkipped;
  final bool         isOnline;
  final String       photoUrl;
  final double       totalBalance;
  final double       weeklyEarnings;
  final double       monthlyEarnings;
  final double       pendingPayout;
  final double       todayEarnings;
  final String?      fcmToken;
  final bool         notifEnabled;
  final String?      kycRejectedReason;

  // ✅ NEW FIELDS (FIX)
  final String kycStatus;
  final Map<String, dynamic>? kycDocuments;

  const HelperModel({
    required this.uid,
    required this.name,
    this.username    = '',
    required this.email,
    required this.phone,
    required this.services,
    required this.area,
    required this.status,
    this.rating          = 0.0,
    this.totalJobs       = 0,
    this.kycDone         = false,
    this.kycSkipped      = false,
    this.isOnline        = false,
    this.photoUrl        = '',
    this.totalBalance    = 0.0,
    this.weeklyEarnings  = 0.0,
    this.monthlyEarnings = 0.0,
    this.pendingPayout   = 0.0,
    this.todayEarnings   = 0.0,
    this.fcmToken,
    this.notifEnabled    = true,
    this.kycRejectedReason,

    // ✅ NEW (FIX)
    this.kycStatus = 'not_submitted',
    this.kycDocuments,
  });

  // ── Computed getters ─────────────────────────────────────────
  String get displayId {
    final part = uid.length >= 6 ? uid.substring(0, 6).toUpperCase() : uid.toUpperCase();
    return 'SK-$part';
  }

  String get initials {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'SK';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get isApproved  => status == 'approved' || kycStatus == 'approved';
  bool get isRejected  => (status == 'rejected' || kycStatus == 'rejected') && !isApproved;
  bool get isInactive  => status == 'inactive' && !isApproved;

// isPending: registered but hasn't submitted KYC docs yet
  bool get isPending   => !isApproved && !isRejected && !isInactive
      && kycStatus == 'not_submitted' && !kycSkipped;

// isSubmitted: KYC docs uploaded, waiting for admin review
  bool get isSubmitted => !isApproved && !isRejected && !isInactive
      && kycStatus == 'pending';

  bool get kycRequired => !kycDone && !kycSkipped;

  // ── copyWith ─────────────────────────────────────────────────
  HelperModel copyWith({
    String?       uid,
    String?       name,
    String?       username,
    String?       email,
    String?       phone,
    List<String>? services,
    String?       area,
    String?       status,
    double?       rating,
    int?          totalJobs,
    bool?         kycDone,
    bool?         kycSkipped,
    bool?         isOnline,
    String?       photoUrl,
    double?       totalBalance,
    double?       weeklyEarnings,
    double?       monthlyEarnings,
    double?       pendingPayout,
    double?       todayEarnings,
    String?       fcmToken,
    bool?         notifEnabled,
    String?       kycRejectedReason,

    // ✅ NEW (FIX)
    String? kycStatus,
    Map<String, dynamic>? kycDocuments,
  }) {
    return HelperModel(
      uid:               uid             ?? this.uid,
      name:              name            ?? this.name,
      username:          username        ?? this.username,
      email:             email           ?? this.email,
      phone:             phone           ?? this.phone,
      services:          services        ?? this.services,
      area:              area            ?? this.area,
      status:            status          ?? this.status,
      rating:            rating          ?? this.rating,
      totalJobs:         totalJobs       ?? this.totalJobs,
      kycDone:           kycDone         ?? this.kycDone,
      kycSkipped:        kycSkipped      ?? this.kycSkipped,
      isOnline:          isOnline        ?? this.isOnline,
      photoUrl:          photoUrl        ?? this.photoUrl,
      totalBalance:      totalBalance    ?? this.totalBalance,
      weeklyEarnings:    weeklyEarnings  ?? this.weeklyEarnings,
      monthlyEarnings:   monthlyEarnings ?? this.monthlyEarnings,
      pendingPayout:     pendingPayout   ?? this.pendingPayout,
      todayEarnings:     todayEarnings   ?? this.todayEarnings,
      fcmToken:          fcmToken        ?? this.fcmToken,
      notifEnabled:      notifEnabled    ?? this.notifEnabled,
      kycRejectedReason: kycRejectedReason ?? this.kycRejectedReason,

      // ✅ NEW (FIX)
      kycStatus: kycStatus ?? this.kycStatus,
      kycDocuments: kycDocuments ?? this.kycDocuments,
    );
  }

  // ── fromMap ──────────────────────────────────────────────────
  factory HelperModel.fromMap(Map<String, dynamic> map, String uid) {
    return HelperModel(
      uid:               uid,
      name:              (map['name']              as String?) ?? '',
      username:          (map['username']          as String?) ?? '',
      email:             (map['email']             as String?) ?? '',
      phone:             (map['phone']             as String?) ?? '',
      services:          List<String>.from(map['services'] ?? []),
      area:              (map['area']              as String?) ?? '',
      status:            (map['status']            as String?) ?? 'pending',
      rating:            ((map['rating']           ?? 0.0) as num).toDouble(),
      totalJobs:         ((map['totalJobs']        ?? 0)   as num).toInt(),
      kycDone:           (map['kycDone']           as bool?) ?? false,
      kycSkipped:        (map['kycSkipped']        as bool?) ?? false,
      isOnline:          (map['isOnline']          as bool?) ?? false,
      photoUrl:          (map['photoUrl']          as String?) ?? '',
      totalBalance:      ((map['totalBalance']     ?? 0.0) as num).toDouble(),
      weeklyEarnings:    ((map['weeklyEarnings']   ?? 0.0) as num).toDouble(),
      monthlyEarnings:   ((map['monthlyEarnings']  ?? 0.0) as num).toDouble(),
      pendingPayout:     ((map['pendingPayout']    ?? 0.0) as num).toDouble(),
      todayEarnings:     ((map['todayEarnings']    ?? 0.0) as num).toDouble(),
      fcmToken:          map['fcmToken']           as String?,
      notifEnabled:      (map['notifEnabled']      as bool?) ?? true,
      kycRejectedReason: map['kycRejectedReason']  as String?,

      // ✅ NEW (FIX)
      kycStatus: (map['kycStatus'] as String?) ?? 'not_submitted',
      kycDocuments: map['kycDocuments'] as Map<String, dynamic>?,
    );
  }

  // ── toMap ────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'uid':               uid,
    'name':              name,
    'username':          username,
    'email':             email,
    'phone':             phone,
    'services':          services,
    'area':              area,
    'status':            status,
    'rating':            rating,
    'totalJobs':         totalJobs,
    'kycDone':           kycDone,
    'kycSkipped':        kycSkipped,
    'isOnline':          isOnline,
    'photoUrl':          photoUrl,
    'totalBalance':      totalBalance,
    'weeklyEarnings':    weeklyEarnings,
    'monthlyEarnings':   monthlyEarnings,
    'pendingPayout':     pendingPayout,
    'todayEarnings':     todayEarnings,
    if (fcmToken != null) 'fcmToken': fcmToken,
    'notifEnabled':      notifEnabled,
    if (kycRejectedReason != null) 'kycRejectedReason': kycRejectedReason,

    // ✅ NEW (FIX)
    'kycStatus': kycStatus,
    if (kycDocuments != null) 'kycDocuments': kycDocuments,
  };
}