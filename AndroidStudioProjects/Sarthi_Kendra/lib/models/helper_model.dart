// lib/models/helper_model.dart

class HelperModel {
  final String       uid;
  final String       name;
  final String       email;
  final String       phone;
  final List<String> services;
  final String       area;
  final String       status;       // pending | submitted | approved | rejected | inactive
  final double       rating;
  final int          totalJobs;
  final bool         kycDone;
  final bool         kycSkipped;
  final bool         isOnline;
  final String?      kycRejectedReason;

  // ── Earnings fields ───────────────────────────────────────────
  final double totalBalance;
  final double weeklyEarnings;
  final double monthlyEarnings;
  final double pendingPayout;
  final double todayEarnings;

  const HelperModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.services,
    required this.area,
    required this.status,
    required this.rating,
    required this.totalJobs,
    required this.kycDone,
    required this.kycSkipped,
    required this.isOnline,
    this.kycRejectedReason,
    this.totalBalance    = 0.0,
    this.weeklyEarnings  = 0.0,
    this.monthlyEarnings = 0.0,
    this.pendingPayout   = 0.0,
    this.todayEarnings   = 0.0,
  });

  // ── Aliases ───────────────────────────────────────────────────
  String get id => uid;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'SK';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String get displayId {
    final suffix = uid.length >= 4
        ? uid.substring(uid.length - 4).toUpperCase()
        : uid.toUpperCase();
    return 'SK-$suffix';
  }

  // ── Status booleans ───────────────────────────────────────────
  bool get isPending   =>
      status.toLowerCase() == 'pending' && !kycDone && !kycSkipped;
  bool get isSubmitted =>
      status.toLowerCase() == 'submitted' ||
          (kycDone && status.toLowerCase() == 'pending');
  bool get isApproved  => status.toLowerCase() == 'approved';
  bool get isRejected  => status.toLowerCase() == 'rejected';
  bool get isInactive  => status.toLowerCase() == 'inactive';

  // ── Firestore ─────────────────────────────────────────────────
  factory HelperModel.fromMap(Map<String, dynamic> map, String uid) {
    return HelperModel(
      uid:               uid,
      name:              (map['name']   as String?) ?? 'Sarthi Helper',
      email:             (map['email']  as String?) ?? '',
      phone:             (map['phone']  as String?) ?? '',
      area:              (map['area']   as String?) ?? 'N/A',
      status:            (map['status'] as String?) ?? 'pending',
      rating:            ((map['rating']    ?? 0.0) as num).toDouble(),
      totalJobs:         ((map['totalJobs'] ?? 0)   as num).toInt(),
      kycDone:           (map['kycDone']    as bool?) ?? false,
      kycSkipped:        (map['kycSkipped'] as bool?) ?? false,
      isOnline:          (map['isOnline']   as bool?) ?? false,
      kycRejectedReason: map['kycRejectedReason'] as String?,
      totalBalance:      ((map['totalBalance']    ?? 0.0) as num).toDouble(),
      weeklyEarnings:    ((map['weeklyEarnings']  ?? 0.0) as num).toDouble(),
      monthlyEarnings:   ((map['monthlyEarnings'] ?? 0.0) as num).toDouble(),
      pendingPayout:     ((map['pendingPayout']   ?? 0.0) as num).toDouble(),
      todayEarnings:     ((map['todayEarnings']   ?? 0.0) as num).toDouble(),
      services: (map['services'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':             uid,
    'name':            name,
    'email':           email,
    'phone':           phone,
    'services':        services,
    'area':            area,
    'status':          status,
    'rating':          rating,
    'totalJobs':       totalJobs,
    'kycDone':         kycDone,
    'kycSkipped':      kycSkipped,
    'isOnline':        isOnline,
    'kycRejectedReason': kycRejectedReason,
    'totalBalance':    totalBalance,
    'weeklyEarnings':  weeklyEarnings,
    'monthlyEarnings': monthlyEarnings,
    'pendingPayout':   pendingPayout,
    'todayEarnings':   todayEarnings,
  };

  HelperModel copyWith({
    String?       name,
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
    String?       kycRejectedReason,
    double?       totalBalance,
    double?       weeklyEarnings,
    double?       monthlyEarnings,
    double?       pendingPayout,
    double?       todayEarnings,
  }) {
    return HelperModel(
      uid:               uid,
      name:              name              ?? this.name,
      email:             email             ?? this.email,
      phone:             phone             ?? this.phone,
      services:          services          ?? this.services,
      area:              area              ?? this.area,
      status:            status            ?? this.status,
      rating:            rating            ?? this.rating,
      totalJobs:         totalJobs         ?? this.totalJobs,
      kycDone:           kycDone           ?? this.kycDone,
      kycSkipped:        kycSkipped        ?? this.kycSkipped,
      isOnline:          isOnline          ?? this.isOnline,
      kycRejectedReason: kycRejectedReason ?? this.kycRejectedReason,
      totalBalance:      totalBalance      ?? this.totalBalance,
      weeklyEarnings:    weeklyEarnings    ?? this.weeklyEarnings,
      monthlyEarnings:   monthlyEarnings   ?? this.monthlyEarnings,
      pendingPayout:     pendingPayout     ?? this.pendingPayout,
      todayEarnings:     todayEarnings     ?? this.todayEarnings,
    );
  }
}