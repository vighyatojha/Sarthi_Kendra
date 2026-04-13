// lib/screens/review/mutual_review_sheet.dart
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/realtime_db_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MUTUAL REVIEW SHEET
// Call MutualReviewSheet.showForHelper(...) from booking completion screens.
// ─────────────────────────────────────────────────────────────────────────────

enum _ReviewerRole { user, helper }

class MutualReviewSheet extends StatefulWidget {
  final String bookingId;
  final String revieweeId;
  final String revieweeName;
  final String serviceName;
  final _ReviewerRole role;
  final VoidCallback? onAfterClose;

  const MutualReviewSheet._({
    required this.bookingId,
    required this.revieweeId,
    required this.revieweeName,
    required this.serviceName,
    required this.role,
    this.onAfterClose,
  });

  static Future<void> showForHelper(
      BuildContext context, {
        required String bookingId,
        required String userId,
        required String userName,
        required String serviceName,
        VoidCallback? onAfterClose,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => MutualReviewSheet._(
        bookingId: bookingId,
        revieweeId: userId,
        revieweeName: userName,
        serviceName: serviceName,
        role: _ReviewerRole.helper,
        onAfterClose: onAfterClose,
      ),
    );
  }

  @override
  State<MutualReviewSheet> createState() => _MutualReviewSheetState();
}

class _MutualReviewSheetState extends State<MutualReviewSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  int _starRating = 0;
  bool _submitting = false;
  final Map<int, int> _answers = {};
  final TextEditingController _noteController = TextEditingController();

  late final AnimationController _doneAnim;
  late final Animation<double> _doneScale;

  @override
  void initState() {
    super.initState();
    _doneAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _doneScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _doneAnim, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _doneAnim.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<_ReviewQuestion> get _questions =>
      _helperQuestions(widget.serviceName);

  bool get _allAnswered => _answers.length == _questions.length;

  Future<void> _submit() async {
    if (_starRating == 0) return;
    setState(() => _submitting = true);
    try {
      final reviewerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final note = _noteController.text.trim();

      final reviewData = {
        'bookingId':    widget.bookingId,
        'reviewerId':   reviewerId,
        'revieweeId':   widget.revieweeId,
        'revieweeName': widget.revieweeName,
        'role':         'helper',
        'starRating':   _starRating,
        'answers':      _answers.map(
                (k, v) => MapEntry(_questions[k].question, _questions[k].options[v])),
        if (note.isNotEmpty) 'additionalNote': note,
        'serviceName':  widget.serviceName,
        'createdAt':    FieldValue.serverTimestamp(),
      };

      // Save to reviews subcollection
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.bookingId)
          .collection('helper_to_user')
          .add(reviewData);

      // Save to reviewHistory root collection
      await FirebaseFirestore.instance.collection('reviewHistory').add({
        'userId':      widget.revieweeId,
        'helperId':    reviewerId,
        'bookingId':   widget.bookingId,
        'serviceName': widget.serviceName,
        'rating':      _starRating,
        'answers':     _answers.map(
                (k, v) => MapEntry(_questions[k].question, _questions[k].options[v])),
        'role':        'helper',
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // Update booking with helperRating
      final directDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();
      if (directDoc.exists) {
        await directDoc.reference.update({
          'helperRating': _starRating,
          if (note.isNotEmpty) 'helperReview': note,
          'helperRatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user's avgRating via transaction
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.revieweeId);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(userRef);
        final prev = (snap.exists
            ? (snap.data()?['totalRatingSum'] as num?)?.toDouble()
            : null) ??
            0.0;
        final count =
            (snap.exists ? (snap.data()?['reviewCount'] as int?) : null) ?? 0;
        final newSum = prev + _starRating;
        final newCount = count + 1;
        txn.set(
          userRef,
          {
            'totalRatingSum':  newSum,
            'reviewCount':     newCount,
            'avgRating':       double.parse((newSum / newCount).toStringAsFixed(1)),
            'lastReviewedAt':  FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Auto-flag low-rated users
      if (_starRating <= 2) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.revieweeId)
            .set({
          'flagCount':     FieldValue.increment(1),
          'lastFlaggedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      setState(() { _step = 2; _submitting = false; });
      _doneAnim.forward();
    } catch (e) {
      setState(() => _submitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting review: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _step == 2
            ? _DoneView(
          key: const ValueKey('done'),
          revieweeName: widget.revieweeName,
          anim: _doneScale,
          onClose: () async {
            final chatId = widget.bookingId;
            await RealtimeDbService.instance.deleteChat(chatId);
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .update({'bookingStatus': 'review_done'})
                .catchError((_) {});
            if (context.mounted) Navigator.pop(context);
            widget.onAfterClose?.call();
          },
        )
            : _step == 1
            ? _RatingView(
          key: const ValueKey('rating'),
          revieweeName: widget.revieweeName,
          starRating: _starRating,
          submitting: _submitting,
          onStar: (s) => setState(() => _starRating = s),
          onBack: () => setState(() => _step = 0),
          onSubmit: _submit,
        )
            : _QuestionsView(
          key: const ValueKey('questions'),
          questions: _questions,
          answers: _answers,
          revieweeName: widget.revieweeName,
          serviceName: widget.serviceName,
          allAnswered: _allAnswered,
          noteController: _noteController,
          onAnswer: (q, a) => setState(() => _answers[q] = a),
          onNext: () => setState(() => _step = 1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — QUESTIONS VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionsView extends StatelessWidget {
  final List<_ReviewQuestion> questions;
  final Map<int, int> answers;
  final String revieweeName;
  final String serviceName;
  final bool allAnswered;
  final TextEditingController noteController;
  final Function(int q, int a) onAnswer;
  final VoidCallback onNext;

  const _QuestionsView({
    super.key,
    required this.questions,
    required this.answers,
    required this.revieweeName,
    required this.serviceName,
    required this.allAnswered,
    required this.noteController,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0D9488);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.70,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 42, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.engineering_rounded,
                    color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review this Customer',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const Text('How did the customer treat you?',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _ProgressBar(
              answered: answers.length,
              total: questions.length,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              itemCount: questions.length + 1,
              itemBuilder: (_, i) {
                if (i == questions.length) {
                  return _AdditionalNoteBox(
                    controller: noteController,
                    accentColor: accentColor,
                  );
                }
                return _QuestionCard(
                  index: i,
                  question: questions[i],
                  selectedOption: answers[i],
                  accentColor: accentColor,
                  onSelect: (a) => onAnswer(i, a),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
            child: SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: allAnswered ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  allAnswered
                      ? 'Next — Give Your Rating →'
                      : 'Answer all questions to continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: allAnswered ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdditionalNoteBox extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;
  const _AdditionalNoteBox(
      {required this.controller, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(Icons.edit_note_rounded, color: accentColor, size: 14),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Anything else? (Optional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: 'e.g. "Customer was very patient and prepared…"',
            hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            counterStyle:
            const TextStyle(fontSize: 10, color: Color(0xFFB0B8CC)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int answered, total;
  final Color color;
  const _ProgressBar(
      {required this.answered, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$answered / $total answered',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        Text('${total == 0 ? 0 : ((answered / total) * 100).round()}%',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : answered / total,
          minHeight: 6,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _ReviewQuestion question;
  final int? selectedOption;
  final Color accentColor;
  final ValueChanged<int> onSelect;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedOption,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedOption != null
            ? accentColor.withOpacity(0.04)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selectedOption != null
              ? accentColor.withOpacity(0.22)
              : const Color(0xFFF0F0F5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(question.question,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.4)),
          ),
          if (selectedOption != null)
            Icon(Icons.check_circle_rounded, color: accentColor, size: 18),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: question.options.asMap().entries.map((e) {
            final isSelected = selectedOption == e.key;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? accentColor : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                      : null,
                ),
                child: Text(e.value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF374151))),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — STAR RATING VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _RatingView extends StatelessWidget {
  final String revieweeName;
  final int starRating;
  final bool submitting;
  final ValueChanged<int> onStar;
  final VoidCallback onBack, onSubmit;

  const _RatingView({
    super.key,
    required this.revieweeName,
    required this.starRating,
    required this.submitting,
    required this.onStar,
    required this.onBack,
    required this.onSubmit,
  });

  String get _ratingLabel {
    switch (starRating) {
      case 1: return 'Very Poor 😞';
      case 2: return 'Below Average 😕';
      case 3: return 'Average 🙂';
      case 4: return 'Good 😊';
      case 5: return 'Excellent! 🌟';
      default: return 'Tap a star to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0D9488);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 42, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [accentColor.withOpacity(0.8), accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            shape: BoxShape.circle,
          ),
          child:
          const Icon(Icons.person_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        Text(revieweeName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        const Text('How would you rate this customer overall?',
            textAlign: TextAlign.center,
            style:
            TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < starRating;
            return GestureDetector(
              onTap: () => onStar(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: filled ? 48 : 44,
                  color: filled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFD1D5DB),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(_ratingLabel,
              key: ValueKey(_ratingLabel),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: starRating > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9CA3AF))),
        ),
        const SizedBox(height: 36),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('← Back',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: starRating > 0 && !submitting ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: submitting
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Review',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — DONE VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _DoneView extends StatelessWidget {
  final String revieweeName;
  final Animation<double> anim;
  final VoidCallback onClose;

  const _DoneView({
    super.key,
    required this.revieweeName,
    required this.anim,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(
          scale: anim,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ],
            ),
            child:
            const Icon(Icons.check_rounded, color: Colors.white, size: 46),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Review Submitted!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 10),
        Text(
          'Thank you for your honest feedback.\nIt helps keep our community genuine & safe.',
          textAlign: TextAlign.center,
          style:
          const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF059669).withOpacity(0.20)),
          ),
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded,
                color: Color(0xFF059669), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'The customer has also been asked to rate this booking.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF374151), height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Close',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW QUESTION DATA
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewQuestion {
  final String question;
  final List<String> options;
  const _ReviewQuestion(this.question, this.options);
}

List<_ReviewQuestion> _helperQuestions(String serviceName) => [
  const _ReviewQuestion(
    'Did the customer treat you respectfully?',
    ['Very respectfully', 'Mostly yes', 'Somewhat rude', 'Disrespectful'],
  ),
  const _ReviewQuestion(
    'Was the service request genuine?',
    ['Yes, completely genuine', 'Seemed genuine', 'Slightly suspicious', 'Not genuine'],
  ),
  const _ReviewQuestion(
    'Did the customer provide correct address & access?',
    ['Yes, everything was clear', 'Minor issues', 'Address was wrong', 'No access given'],
  ),
  const _ReviewQuestion(
    'Was payment handled smoothly?',
    ['Yes, no issues', 'Minor delay', 'Refused to pay full', 'Payment issues'],
  ),
  const _ReviewQuestion(
    'Did the customer make unreasonable demands?',
    ['No, totally fair', 'Minor extra requests', 'Several extras', 'Very unreasonable'],
  ),
  const _ReviewQuestion(
    'Would you accept a booking from this customer again?',
    ['Definitely yes', 'Maybe', 'Hesitant', 'No'],
  ),
];