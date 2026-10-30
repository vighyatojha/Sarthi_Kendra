// lib/screens/requests/helper_booking_screen.dart
// An accepted job, step by step:
// Confirmed → Start trip → Arrived → (customer's 4-digit code) Start work →
// Mark work done → Confirm cash/UPI received → Completed → Rate customer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/booking_chat_screen.dart';
import '../../core/job_api.dart';
import '../../core/job_media_widgets.dart';
import '../../core/job_models.dart';
import '../../core/review_sheet.dart';
import '../../providers/auth_provider.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);

class HelperBookingScreen extends StatefulWidget {
  final String bookingId;
  const HelperBookingScreen({super.key, required this.bookingId});

  @override
  State<HelperBookingScreen> createState() => _HelperBookingScreenState();
}

class _HelperBookingScreenState extends State<HelperBookingScreen> {
  bool _busy = false;
  bool _reviewPrompted = false;
  bool _phoneShared = false;

  Future<void> _act(Booking b, String action, {String? code, String? reason, String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await JobApi.instance.bookingAction(b, action, code: code, reason: reason);
      if (ok != null && mounted) _snack(ok);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: error ? _red : _green, behavior: SnackBarBehavior.floating));

  Future<bool> _confirm(String title, String body, String yes, {Color color = _purple}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yes)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _enterCode(Booking b) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter start code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ask the customer for the 4-digit code shown in their app.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 12),
            decoration: const InputDecoration(counterText: '', hintText: '••••'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () {
              if (ctrl.text.length == 4) Navigator.pop(ctx, ctrl.text);
            },
            child: const Text('Start work'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), ctrl.dispose);
    if (code == null) return;
    await _act(b, 'start_work', code: code, ok: 'Work started');
  }

  Future<String?> _reason(String title, List<String> presets, {int minLen = 3}) async {
    final ctrl = TextEditingController();
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in presets) ActionChip(label: Text(p), onPressed: () => ctrl.text = p),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write the reason',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                if (ctrl.text.trim().length >= minLen) Navigator.pop(ctx, ctrl.text.trim());
              },
              child: const Text('Submit'),
            ),
          ),
        ]),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), ctrl.dispose);
    return r;
  }

  Future<void> _openMaps(Booking b) async {
    final a = b.address;
    final uri = (a.lat != 0 && a.lng != 0)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}&travelmode=driving')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a.full)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack('Could not open Maps.', error: true);
    }
  }

  Future<void> _call(Booking b) async {
    final c = await JobApi.instance.contact(b.id);
    final phone = c?.customerPhone ?? '';
    if (phone.isEmpty) {
      if (mounted) _snack('Phone number not available. Please use chat.', error: true);
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void _chat(Booking b) {
    final me = context.read<AuthProvider>().helper?.name ?? b.helperName;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingChatScreen(
        bookingId: b.id,
        otherName: b.customerName,
        myName: me,
        myRole: 'helper',
        subtitle: b.serviceName,
      ),
    ));
  }

  void _maybeReview(Booking b) {
    if (_reviewPrompted || b.status != BookingStatus.completed || b.helperReviewed) return;
    final done = b.completedAt;
    if (done != null && DateTime.now().isAfter(done.add(reviewWindow))) return;
    _reviewPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ReviewSheet.show(context, booking: b, asCustomer: false, accent: _purple);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: JobApi.instance.booking(widget.bookingId),
      builder: (context, snap) {
        final b = snap.data;
        return Scaffold(
          backgroundColor: const Color(0xFFF8F7FF),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0.5,
            title: Text(b?.serviceName ?? 'Job', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: snap.hasError
              ? const Center(child: Text('Could not load this job.'))
              : b == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(children: [
            _content(b),
            if (_busy) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
          ]),
          bottomNavigationBar: b == null ? null : _primaryAction(b),
        );
      },
    );
  }

  Widget _content(Booking b) {
    _maybeReview(b);
    if (!_phoneShared && b.isActive) {
      // Lets the customer call this helper (stored in the booking's private contact doc).
      _phoneShared = true;
      JobApi.instance.shareHelperPhone(b.id);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      // Customer + price
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFF3E8FF),
            child: Text(b.customerName.isNotEmpty ? b.customerName[0].toUpperCase() : 'C',
                style: const TextStyle(color: _purple, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              Text(bookingStatusLabel(b.status),
                  style: TextStyle(
                      color: b.status == BookingStatus.cancelled ? _red : _purple, fontWeight: FontWeight.w700)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${b.agreedAmount}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
            const Text('collect after work', style: TextStyle(fontSize: 11, color: _muted)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      // Contact row
      if (b.isActive)
        Row(children: [
          Expanded(child: _pill(Icons.chat_bubble_outline_rounded, 'Chat', () => _chat(b))),
          const SizedBox(width: 8),
          Expanded(child: _pill(Icons.call_outlined, 'Call', () => _call(b))),
          const SizedBox(width: 8),
          Expanded(child: _pill(Icons.navigation_outlined, 'Navigate', () => _openMaps(b))),
        ])
      else
        _pill(Icons.chat_bubble_outline_rounded, 'Open chat', () => _chat(b)),
      const SizedBox(height: 12),
      if (b.status == BookingStatus.cancelled)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16)),
          child: Text(
            '${b.cancelledBy == 'helper' ? 'You' : 'The customer'} cancelled this job.'
                '${b.cancelReason.isNotEmpty ? '\nReason: ${b.cancelReason}' : ''}',
            style: const TextStyle(color: Color(0xFF7F1D1D), height: 1.35),
          ),
        ),
      if (b.status == BookingStatus.workDone)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16)),
          child: Text(
            b.customerPaidAt != null
                ? 'Customer says they paid ₹${b.agreedAmount} by ${b.paymentMethod == 'upi' ? 'UPI' : 'cash'}. '
                'Confirm once you have received it.'
                : 'Collect ₹${b.agreedAmount} from the customer (cash or UPI), then confirm below.',
            style: const TextStyle(color: Color(0xFF065F46), height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      if (b.status == BookingStatus.completed)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Expanded(
              child: Text('Job completed ✅',
                  style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
        ),
      if (b.status == BookingStatus.completed) ...[
        const SizedBox(height: 12),
        MutualReviewCard(booking: b, asCustomer: false),
      ],
      const SizedBox(height: 12),
      // Details
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row(Icons.schedule_rounded,
              b.slot.isNow
                  ? 'As soon as possible (booked ${DateFormat('h:mm a').format(b.createdAt ?? DateTime.now())})'
                  : '${DateFormat('EEE d MMM').format(b.slot.start)}, '
                  '${DateFormat('h a').format(b.slot.start)} – ${DateFormat('h a').format(b.slot.end)}'),
          _row(Icons.location_on_outlined, b.address.full),
          const Divider(height: 20),
          Text(b.description, style: const TextStyle(color: Color(0xFF374151), height: 1.45)),
          if (b.photoUrls.isNotEmpty) ...[const SizedBox(height: 10), PhotoStrip(urls: b.photoUrls)],
          if (b.audioUrl != null) ...[const SizedBox(height: 10), VoiceNotePlayer(url: b.audioUrl)],
        ]),
      ),
      const SizedBox(height: 16),
      if (b.canCancel)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () async {
            final r = await _reason('Why are you cancelling?', const [
              'Not well', 'Vehicle problem', 'Emergency at home', 'Customer asked to cancel',
            ]);
            if (r != null) await _act(b, 'cancel', reason: r, ok: 'Job cancelled');
          },
          icon: const Icon(Icons.cancel_outlined, color: _red),
          label: const Text('Cancel job (affects your ranking)', style: TextStyle(color: _red)),
        )
      else if (b.status != BookingStatus.confirmed)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () async {
            final r = await _reason('Report a problem', const [
              'Customer not reachable', 'Customer refused to pay', 'Unsafe situation', 'Work different from request',
            ], minLen: 10);
            if (r != null) await _act(b, 'report_issue', reason: r, ok: 'Reported. Our team will contact you.');
          },
          icon: const Icon(Icons.flag_outlined, color: _muted),
          label: const Text('Report a problem', style: TextStyle(color: _muted)),
        ),
    ]);
  }

  /// The single next step, as a big button at the bottom.
  Widget? _primaryAction(Booking b) {
    final (String label, IconData icon, Color color, Future<void> Function()? onTap) = switch (b.status) {
      BookingStatus.confirmed => (
      'Start trip',
      Icons.directions_bike_rounded,
      _purple,
          () async {
        await _act(b, 'start_trip', ok: 'Customer notified you are on the way');
        if (mounted) _openMaps(b);
      }
      ),
      BookingStatus.onTheWay => ('I have arrived', Icons.location_on_rounded, _amber, () => _act(b, 'arrive', ok: 'Customer notified')),
      BookingStatus.arrived => ('Enter start code', Icons.pin_rounded, _purple, () => _enterCode(b)),
      BookingStatus.inProgress => (
      'Mark work done',
      Icons.task_alt_rounded,
      _green,
          () async {
        if (await _confirm('Is the work finished?',
            'The customer will be asked to pay ₹${b.agreedAmount}.', 'Yes, done', color: _green)) {
          await _act(b, 'mark_done', ok: 'Customer asked to pay');
        }
      }
      ),
      BookingStatus.workDone => (
      'I received ₹${b.agreedAmount}',
      Icons.payments_rounded,
      _green,
          () async {
        if (await _confirm('Payment received?',
            'Confirm only after you have the full ₹${b.agreedAmount} in cash or UPI.', 'Yes, received',
            color: _green)) {
          await _act(b, 'confirm_received', ok: 'Job completed');
        }
      }
      ),
      _ => ('', Icons.check, _muted, null),
    };
    if (onTap == null) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _busy ? null : onTap,
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: _purple,
      side: const BorderSide(color: Color(0xFFDDD6FE)),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  Widget _row(IconData i, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(i, size: 18, color: _purple),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: _ink))),
    ]),
  );
}