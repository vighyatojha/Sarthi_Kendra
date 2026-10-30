// lib/core/review_sheet.dart
// Mutual (double-blind) ratings after a completed booking. IDENTICAL in both apps.
//
//  • Customer rates the helper, helper rates the customer.
//  • Each review stays hidden from the other person until they BOTH have
//    reviewed, or 14 days after completion — so nobody rates in revenge.
//  • Reviews can be written for 14 days after the job is completed.
//
// ReviewSheet       — the rating bottom sheet (stars, quick tags, comment).
// MutualReviewCard  — the card on the booking screen that shows where the
//                     mutual review stands and both reviews once revealed.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'job_api.dart';
import 'job_models.dart';
import 'sarthi_ui.dart';

const reviewWindow = Duration(days: 14);

const _starWords = ['', 'Poor', 'Below average', 'Okay', 'Good', 'Excellent'];

String _first(String name) {
  final f = name.trim().split(RegExp(r'\s+')).first;
  return f.isEmpty ? name : f;
}

// ─────────────────────────────────────────────────────────────────────────────
// RATING SHEET
// ─────────────────────────────────────────────────────────────────────────────

class ReviewSheet extends StatefulWidget {
  final Booking booking;
  final bool asCustomer;
  final Color accent;

  const ReviewSheet({
    super.key,
    required this.booking,
    required this.asCustomer,
    this.accent = SarthiColors.purple,
  });

  String get otherName => asCustomer ? booking.helperName : booking.customerName;

  /// Returns true if a review was submitted.
  static Future<bool> show(
      BuildContext context, {
        required Booking booking,
        required bool asCustomer,
        Color accent = SarthiColors.purple,
      }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSheet(booking: booking, asCustomer: asCustomer, accent: accent),
    );
    return r == true;
  }

  /// Reviews are part of every booking. Before a customer posts a new request
  /// (or a helper sends a new price), any completed job they haven't rated yet
  /// must be rated first. Returns true when nothing is left to rate.
  static Future<bool> requirePending(BuildContext context, {required bool asCustomer}) async {
    final pending = await JobApi.instance.pendingReviews(asHelper: !asCustomer);
    for (final b in pending) {
      if (!context.mounted) return false;
      final other = _first(asCustomer ? b.helperName : b.customerName);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 40),
          title: Text('Rate $other first'),
          content: Text(
            'Your ${b.serviceName} job with $other is complete. Rating each other is part of every booking. '
                'Please rate $other before you ${asCustomer ? 'post a new request' : 'send a new price'}.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SarthiColors.purple),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rate now'),
            ),
          ],
        ),
      );
      if (go != true || !context.mounted) return false;
      final done = await ReviewSheet.show(context, booking: b, asCustomer: asCustomer);
      if (!done) return false;
    }
    return true;
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  int _stars = 0;
  final Set<String> _tags = {};
  final _comment = TextEditingController();
  bool _saving = false;
  bool _done = false;
  String? _error;

  List<ReviewTag> get _all => widget.asCustomer ? customerToHelperTags : helperToCustomerTags;
  bool get _otherAlreadyReviewed =>
      widget.asCustomer ? widget.booking.helperReviewed : widget.booking.customerReviewed;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Tap the stars to give a rating.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await JobApi.instance.submitReview(
        booking: widget.booking,
        asCustomer: widget.asCustomer,
        rating: _stars,
        tags: _tags.toList(),
        comment: _comment.text.trim(),
      );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Set<String> _visibleIds(int stars) => _all
      .where((t) => stars >= 4 ? t.positive : stars <= 2 ? !t.positive : true)
      .map((t) => t.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final other = _first(widget.otherName);
    final visible = _all.where((t) {
      if (_stars == 0 || _stars >= 4) return t.positive;
      if (_stars <= 2) return !t.positive;
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                gradient: SarthiColors.header,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                SarthiAvatar(name: widget.otherName, photoUrl: widget.asCustomer ? widget.booking.helperPhotoUrl : '', size: 58),
                const SizedBox(height: 10),
                Text(_done ? 'Thanks for your review!' : 'How was $other?',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(widget.booking.serviceName,
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: _done ? _doneView(other) : _formView(other, visible),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _formView(String other, List<ReviewTag> visible) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Double-blind explainer
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: SarthiColors.purpleLight, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.visibility_off_rounded, size: 18, color: SarthiColors.purpleDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _otherAlreadyReviewed
                  ? '$other has already rated you. Submit yours and you will both see each other\'s review.'
                  : 'Your review stays hidden until $other rates you too (or for 14 days), so you can be honest.',
              style: const TextStyle(fontSize: 12, color: SarthiColors.purpleDark, height: 1.35),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final on = i < _stars;
            return GestureDetector(
              onTap: () => setState(() {
                _stars = i + 1;
                _tags.removeWhere((id) => !_visibleIds(_stars).contains(id));
                _error = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedScale(
                  scale: on ? 1.12 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44, color: on ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB)),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(_stars == 0 ? 'Tap a star' : _starWords[_stars],
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _stars == 0 ? SarthiColors.faint : const Color(0xFFD97706))),
      ),
      const SizedBox(height: 16),
      Text(
        _stars == 0 || _stars >= 4 ? 'What went well?' : _stars <= 2 ? 'What went wrong?' : 'Anything to note?',
        style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 13.5),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: visible.map((t) {
          final sel = _tags.contains(t.id);
          final c = t.positive ? SarthiColors.green : SarthiColors.red;
          return GestureDetector(
            onTap: () => setState(() => sel ? _tags.remove(t.id) : _tags.add(t.id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? c.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? c : const Color(0xFFE5E7EB)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[Icon(Icons.check_rounded, size: 14, color: c), const SizedBox(width: 4)],
                Text(t.label,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? c : SarthiColors.body)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _comment,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: 'Anything else? (optional)',
          hintStyle: const TextStyle(color: SarthiColors.faint),
          filled: true,
          fillColor: SarthiColors.page,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      if (_error != null) ...[
        Text(_error!, style: const TextStyle(color: SarthiColors.red, fontWeight: FontWeight.w600, fontSize: 12.5)),
        const SizedBox(height: 10),
      ],
      SarthiButton(label: 'Submit review', icon: Icons.send_rounded, busy: _saving, onPressed: _submit),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Later (needed before your next booking)',
              style: TextStyle(color: SarthiColors.muted, fontSize: 12.5)),
        ),
      ),
    ]);
  }

  Widget _doneView(String other) {
    final revealed = _otherAlreadyReviewed;
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: SarthiColors.greenLight, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: SarthiColors.green, size: 36),
      ),
      const SizedBox(height: 14),
      Text(
        revealed
            ? 'You can now see what $other said about you on the booking screen.'
            : 'Your review is saved and hidden. You\'ll both see each other\'s review when $other rates you, '
            'or after 14 days.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13.5, color: SarthiColors.body, height: 1.45),
      ),
      const SizedBox(height: 18),
      SarthiButton(label: 'Done', onPressed: () => Navigator.of(context).pop(true)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MUTUAL REVIEW CARD  (shown on a completed booking, in both apps)
// ─────────────────────────────────────────────────────────────────────────────

class MutualReviewCard extends StatefulWidget {
  final Booking booking;
  final bool asCustomer;
  const MutualReviewCard({super.key, required this.booking, required this.asCustomer});

  @override
  State<MutualReviewCard> createState() => _MutualReviewCardState();
}

class _MutualReviewCardState extends State<MutualReviewCard> {
  @override
  void initState() {
    super.initState();
    // Past the 14-day window, hidden reviews are revealed by whoever opens the booking.
    JobApi.instance.revealDueReviews(widget.booking);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    if (b.status != BookingStatus.completed) return const SizedBox.shrink();
    final myRole = widget.asCustomer ? 'customer' : 'helper';
    final otherRole = widget.asCustomer ? 'helper' : 'customer';
    final iReviewed = widget.asCustomer ? b.customerReviewed : b.helperReviewed;
    final theyReviewed = widget.asCustomer ? b.helperReviewed : b.customerReviewed;
    final other = _first(widget.asCustomer ? b.helperName : b.customerName);
    final closesAt = b.completedAt?.add(reviewWindow);
    final windowOpen = closesAt == null || DateTime.now().isBefore(closesAt);
    final revealedByTime = !windowOpen;

    // Their review can be read once both reviewed, or after the window.
    final canSeeTheirs = theyReviewed && (iReviewed || revealedByTime);

    return Container(
      decoration: sarthiCard(radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            gradient: SarthiColors.header,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            const Icon(Icons.handshake_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Mutual review',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            _Step(done: iReviewed, label: 'You'),
            const SizedBox(width: 6),
            _Step(done: theyReviewed, label: other),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status line
            Text(
              _statusText(other, iReviewed, theyReviewed, windowOpen, closesAt),
              style: const TextStyle(fontSize: 12.5, color: SarthiColors.muted, height: 1.4),
            ),
            if (!iReviewed && windowOpen) ...[
              const SizedBox(height: 12),
              SarthiButton(
                label: theyReviewed ? 'Rate $other to see their review' : 'Rate $other',
                icon: Icons.star_rounded,
                colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                onPressed: () => ReviewSheet.show(context, booking: b, asCustomer: widget.asCustomer),
              ),
            ],
            if (canSeeTheirs) ...[
              const SizedBox(height: 14),
              _ReviewStream(bookingId: b.id, role: otherRole, title: '$other about you'),
            ],
            if (iReviewed) ...[
              const SizedBox(height: 12),
              _ReviewStream(bookingId: b.id, role: myRole, title: 'Your review of $other', mine: true),
            ],
          ]),
        ),
      ]),
    );
  }

  String _statusText(String other, bool mine, bool theirs, bool open, DateTime? closesAt) {
    final until = closesAt == null ? '' : DateFormat('d MMM').format(closesAt);
    if (mine && theirs) return 'You have both reviewed. Reviews are now visible to each other.';
    if (mine && !theirs) {
      return open
          ? 'Your review is hidden until $other rates you, or until $until.'
          : 'The review window has closed. Your review is now visible.';
    }
    if (!mine && theirs) {
      return open
          ? '$other has rated you. Their review stays hidden until you rate them (before $until).'
          : 'The review window has closed.';
    }
    return open
        ? 'Rate each other before $until. Neither of you sees the other\'s review until both are in.'
        : 'The review window for this job has closed.';
  }
}

class _Step extends StatelessWidget {
  final bool done;
  final String label;
  const _Step({required this.done, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: done ? Colors.white : Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(done ? Icons.check_circle_rounded : Icons.schedule_rounded,
          size: 12, color: done ? SarthiColors.green : Colors.white70),
      const SizedBox(width: 3),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 70),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.bold, color: done ? SarthiColors.ink : Colors.white)),
      ),
    ]),
  );
}

class _ReviewStream extends StatelessWidget {
  final String bookingId;
  final String role;
  final String title;
  final bool mine;
  const _ReviewStream({required this.bookingId, required this.role, required this.title, this.mine = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: JobApi.instance.review(bookingId, role),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) return const SizedBox.shrink();
        final rating = (r['rating'] as num?)?.toInt() ?? 0;
        final tags = (r['tags'] as List?)?.whereType<String>().toList() ?? const <String>[];
        final comment = '${r['comment'] ?? ''}'.trim();
        final all = [...customerToHelperTags, ...helperToCustomerTags];
        ReviewTag? tag(String id) {
          for (final t in all) {
            if (t.id == id) return t;
          }
          return null;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? SarthiColors.page : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mine ? const Color(0xFFE5E7EB) : const Color(0xFFFDE68A)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: SarthiColors.ink, fontSize: 12.5)),
              ),
              for (var i = 0; i < 5; i++)
                Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 15, color: i < rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB)),
            ]),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final id in tags)
                  SarthiChip(tag(id)?.label ?? id,
                      color: (tag(id)?.positive ?? true) ? SarthiColors.green : SarthiColors.red),
              ]),
            ],
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('“$comment”', style: const TextStyle(fontSize: 12.5, color: SarthiColors.body, height: 1.4)),
            ],
            if (mine && r['visible'] == false) ...[
              const SizedBox(height: 6),
              const Row(children: [
                Icon(Icons.visibility_off_rounded, size: 13, color: SarthiColors.faint),
                SizedBox(width: 4),
                Text('Hidden from them for now', style: TextStyle(fontSize: 11, color: SarthiColors.faint)),
              ]),
            ],
          ]),
        );
      },
    );
  }
}