// lib/core/ranking.dart
// Ranks the price quotes on a request. Runs in the customer's app (free plan:
// no server). Same formula as ranker/scoring.py, so a trained ML model can
// replace it later without changing what the screens show.
//
// score (0–100) =
//   32% star rating (Bayesian: new helpers start at 4.2 so they aren't buried)
// + 10% customer feedback tags (positive vs negative)
// +  8% reliability (few cancellations)
// + 25% price compared with the other quotes on this request
// + 10% experience (jobs completed, years)
// + 10% distance
// +  5% how quickly they responded

import 'dart:math' as math;

import 'app_config.dart';
import 'job_models.dart';

const _priorMean = 4.2;
const _priorWeight = 5.0;

double bayesRating(double avg, int n) => (_priorMean * _priorWeight + avg * n) / (_priorWeight + n);

double _clamp(double x, double lo, double hi) => math.min(hi, math.max(lo, x));

double _median(List<int> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

/// [jobCreatedAt] is used to measure how fast each helper responded.
List<RankedPitch> rankPitches(List<Pitch> pitches, Map<String, HelperStats> helpers, DateTime? jobCreatedAt) {
  final rows = <({Pitch p, HelperStats h, double score, double bayes})>[];
  if (pitches.isEmpty) return const [];
  final med = _median(pitches.map((p) => p.amount).toList());
  const r = AppConfig.searchRadiusKm;

  for (final p in pitches) {
    final h = helpers[p.helperId] ??
        HelperStats(
          id: p.helperId, name: 'Helper', photoUrl: '', rating: 0, ratingCount: 0,
          completedJobs: 0, cancelCount: 0, tagPos: 0, tagNeg: 0, experienceYears: 0,
        );
    final bayes = bayesRating(h.rating, h.ratingCount);
    final rating = (bayes - 1) / 4;
    final feedback = (h.tagPos + 1) / (h.tagPos + h.tagNeg + 2);
    final reliability = 1 - h.cancelCount / (h.completedJobs + h.cancelCount + 3);
    final experience = 0.7 * math.min(1.0, math.log(1 + h.completedJobs) / math.log(101)) +
        0.3 * math.min(1.0, h.experienceYears / 10);
    final price = _clamp(med / math.max(1, p.amount), 0, 1.5) / 1.5;
    final distance = 1 - _clamp(p.distanceKm, 0, r) / r;
    final responseSec = (jobCreatedAt != null && p.createdAt != null)
        ? p.createdAt!.difference(jobCreatedAt).inSeconds.toDouble()
        : 900.0;
    final response = 1 - _clamp(responseSec, 0, 1800) / 1800;
    final s = 0.32 * rating + 0.10 * feedback + 0.08 * reliability + 0.25 * price +
        0.10 * experience + 0.10 * distance + 0.05 * response;
    rows.add((p: p, h: h, score: (s * 1000).roundToDouble() / 10, bayes: bayes));
  }

  rows.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    final c2 = a.p.amount.compareTo(b.p.amount);
    return c2 != 0 ? c2 : a.p.distanceKm.compareTo(b.p.distanceKm);
  });

  final minPrice = rows.map((x) => x.p.amount).reduce(math.min);
  final uniqueMin = rows.where((x) => x.p.amount == minPrice).length == 1;
  final minDist = rows.map((x) => x.p.distanceKm).reduce(math.min);
  final rated = rows.where((x) => x.h.ratingCount >= 3);
  final topBayes = rated.isEmpty ? -1.0 : rated.map((x) => x.bayes).reduce(math.max);
  final many = rows.length >= 2;

  return [
    for (var i = 0; i < rows.length; i++)
      RankedPitch(rows[i].p, rows[i].h, rows[i].score, i + 1, [
        if (many && i == 0) 'best_match',
        if (many && uniqueMin && rows[i].p.amount == minPrice) 'lowest_price',
        if (rows[i].h.ratingCount >= 3 && rows[i].bayes == topBayes) 'top_rated',
        if (many && rows[i].p.distanceKm == minDist) 'nearest',
        if (rows[i].h.ratingCount == 0) 'new_helper',
      ]),
  ];
}

/// Feature row saved for every quote when a customer books, for training later.
Map<String, dynamic> rankingFeatures(RankedPitch r, DateTime? jobCreatedAt) => {
  'helperId': r.pitch.helperId,
  'amount': r.pitch.amount,
  'distanceKm': r.pitch.distanceKm,
  'responseSec': (jobCreatedAt != null && r.pitch.createdAt != null)
      ? r.pitch.createdAt!.difference(jobCreatedAt).inSeconds
      : 0,
  'ratingAvg': r.helper.rating,
  'ratingCount': r.helper.ratingCount,
  'completedJobs': r.helper.completedJobs,
  'cancelCount': r.helper.cancelCount,
  'tagPos': r.helper.tagPos,
  'tagNeg': r.helper.tagNeg,
  'experienceYears': r.helper.experienceYears,
  'shownRank': r.rank,
  'shownScore': r.score,
};