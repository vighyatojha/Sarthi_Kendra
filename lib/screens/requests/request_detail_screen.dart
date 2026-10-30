// lib/screens/requests/request_detail_screen.dart
// A customer's request as the helper sees it: description, photos, voice note,
// time and distance, and the form to send / change / withdraw a price.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/job_api.dart';
import '../../core/job_media_widgets.dart';
import '../../core/job_models.dart';
import '../../core/review_sheet.dart';
import '../../core/service_catalog.dart';
import '../../providers/auth_provider.dart';
import 'helper_booking_screen.dart';
import 'requests_strings.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _maxEdits = AppConfig.pitchMaxEdits; // firestore.rules allows 3 changes

class RequestDetailScreen extends StatefulWidget {
  final NearbyJob nearby;
  const RequestDetailScreen({super.key, required this.nearby});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _eta;
  bool _busy = false;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefill(Pitch? p) {
    if (_prefilled || p == null || p.status != PitchStatus.active) return;
    _prefilled = true;
    _amount.text = '${p.amount}';
    _note.text = p.note;
    _eta = p.etaMinutes;
  }

  Future<void> _send(JobRequest job) async {
    FocusScope.of(context).unfocus();
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount < AppConfig.pitchMinRupees || amount > AppConfig.pitchMaxRupees) {
      setState(() => _error = 'Enter a price between ₹${AppConfig.pitchMinRupees} and ₹${AppConfig.pitchMaxRupees}.');
      return;
    }
    // Every job ends with a mutual review: rate your last customer before a new price.
    if (!await ReviewSheet.requirePending(context, asCustomer: false)) {
      if (mounted) setState(() => _error = 'Please rate your previous customer before sending a new price.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await JobApi.instance.submitPitch(
        job: job,
        amount: amount,
        note: _note.text.trim(),
        etaMinutes: job.slot.isNow ? _eta : null,
        distanceKm: widget.nearby.distanceKm,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Price sent. The customer will be notified.'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(JobRequest job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw your price?'),
        content: const Text('The customer will no longer see your quote.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await JobApi.instance.withdrawPitch(job.id);
      _prefilled = false;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langCode(context);
    final sub = ServiceCatalog.byId(widget.nearby.job.subcategoryId);
    final myUid = context.watch<AuthProvider>().helper?.uid ?? '';
    final approved = context.watch<AuthProvider>().helper?.kycStatus == 'approved';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0.5,
        title: Text(sub?.name(lang) ?? widget.nearby.job.serviceName, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<JobRequest?>(
        stream: JobApi.instance.job(widget.nearby.job.id),
        builder: (context, jobSnap) {
          if (jobSnap.hasError) {
            return Center(child: Text(tr(context, 'expired'), style: const TextStyle(color: _muted)));
          }
          final job = jobSnap.data;
          if (job == null) return const Center(child: CircularProgressIndicator());

          return StreamBuilder<Pitch?>(
            stream: JobApi.instance.myPitch(job.id),
            builder: (context, pSnap) {
              final pitch = pSnap.data;
              _prefill(pitch);
              return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
                _jobCard(context, job),
                const SizedBox(height: 16),
                _stateOrForm(context, job, pitch, myUid, approved),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _jobCard(BuildContext context, JobRequest job) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFF3E8FF),
          child: Text(job.customerFirstName.isNotEmpty ? job.customerFirstName[0].toUpperCase() : 'C',
              style: const TextStyle(color: _purple, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${tr(context, 'customer')}: ${job.customerFirstName}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
        ),
        Text('${widget.nearby.distanceKm.toStringAsFixed(1)} ${tr(context, 'away')}',
            style: const TextStyle(color: _muted, fontSize: 12.5)),
      ]),
      const Divider(height: 24),
      _row(Icons.schedule_rounded, tr(context, 'when'),
          job.slot.isNow
              ? tr(context, 'now')
              : '${DateFormat('EEE d MMM').format(job.slot.start)}, '
              '${DateFormat('h a').format(job.slot.start)} – ${DateFormat('h a').format(job.slot.end)}'),
      _row(Icons.location_on_outlined, tr(context, 'where'),
          job.areaName.isNotEmpty ? job.areaName : '—'),
      const SizedBox(height: 8),
      Text(job.description, style: const TextStyle(color: Color(0xFF374151), height: 1.45, fontSize: 15)),
      if (job.photoUrls.isNotEmpty) ...[
        const SizedBox(height: 12),
        PhotoStrip(urls: job.photoUrls),
      ],
      if (job.audioUrl != null) ...[
        const SizedBox(height: 12),
        VoiceNotePlayer(url: job.audioUrl),
      ],
      const SizedBox(height: 8),
      const Text('Exact address is shared only if the customer books you.',
          style: TextStyle(color: _muted, fontSize: 12)),
    ]),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: _purple),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(color: _muted)),
      Expanded(child: Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _stateOrForm(BuildContext context, JobRequest job, Pitch? pitch, String myUid, bool approved) {
    // Booked: by me or by someone else.
    if (job.status == JobStatus.booked || job.status == JobStatus.completed) {
      final mine = job.bookedHelperId == myUid && job.bookingId != null;
      return _notice(
        mine ? tr(context, 'youGotIt') : tr(context, 'chosenOther'),
        mine ? _green : _muted,
        action: mine
            ? FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _green),
          onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HelperBookingScreen(bookingId: job.bookingId!))),
          child: Text(tr(context, 'openJob')),
        )
            : null,
      );
    }
    if (!job.acceptingPitches || pitch?.status == PitchStatus.cancelled) {
      return _notice(tr(context, 'expired'), _muted);
    }
    if (!approved) return _notice(tr(context, 'kycPending'), const Color(0xFFD97706));

    final active = pitch?.status == PitchStatus.active;
    // Rule: the first price counts 0; each later change (or re-send) adds 1, up to _maxEdits.
    final editsLeft = pitch == null ? _maxEdits : _maxEdits - pitch.edits;
    final canEdit = editsLeft > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? const Color(0xFFBBF7D0) : const Color(0xFFEDE9FE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (active) ...[
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: _green),
            const SizedBox(width: 6),
            Text('${tr(context, 'priceSent')}: ₹${pitch!.amount}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: _green, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          Text('$editsLeft ${tr(context, 'editsLeft')}', style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 12),
        ],
        Text(tr(context, 'price'), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          enabled: canEdit && !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: '₹ ',
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Text(tr(context, 'priceHelp'), style: const TextStyle(color: _muted, fontSize: 12, height: 1.35)),
        if (job.slot.isNow) ...[
          const SizedBox(height: 14),
          Text(tr(context, 'eta'), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final m in const [15, 30, 45, 60, 90])
              ChoiceChip(
                label: Text('$m ${tr(context, 'min')}'),
                selected: _eta == m,
                onSelected: canEdit && !_busy ? (_) => setState(() => _eta = m) : null,
              ),
          ]),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          enabled: canEdit && !_busy,
          maxLength: 300,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr(context, 'note'),
            hintText: tr(context, 'noteHint'),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: _red, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: !canEdit || _busy ? null : () => _send(job),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr(context, active ? 'updatePrice' : 'sendPrice'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        if (active)
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _withdraw(job),
              child: Text(tr(context, 'withdraw'), style: const TextStyle(color: _red)),
            ),
          ),
      ]),
    );
  }

  Widget _notice(String text, Color c, {Widget? action}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15)),
      if (action != null) ...[const SizedBox(height: 12), action],
    ]),
  );
}