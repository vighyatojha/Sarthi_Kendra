// lib/screens/chat/helper_chat_room_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/realtime_db_service.dart';
import '../../services/booking_chat_service.dart';
import '../../screens/review/mutual_review_sheet.dart';
import '../../theme/app_theme.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _rPurple = Color(0xFF7C3AED);
const _rIndigo = Color(0xFF2D1B69);
const _rViolet = Color(0xFF5B21B6);
const _rCyan   = Color(0xFF06B6D4);
const _rGreen  = Color(0xFF16A34A);
const _rBg     = Color(0xFFF8F7FF);

class HelperChatRoomScreen extends StatefulWidget {
  final String  chatId;
  final String  userId;
  final String  userName;
  final String? userPhoto;
  final String? serviceName;
  final String? bookingId;

  const HelperChatRoomScreen({
    super.key,
    required this.chatId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.serviceName,
    this.bookingId,
  });

  @override
  State<HelperChatRoomScreen> createState() => _HelperChatRoomState();
}

class _HelperChatRoomState extends State<HelperChatRoomScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool  _isSending  = false;

  final List<String> _quickReplies = [
    "I'm on my way",
    'Arrived at location',
    'Job started',
    '5 mins away',
  ];

  bool _isCompleted             = false;
  bool _helperConfirmed         = false;
  bool _userConfirmed           = false;
  bool _mutualCompletionHandled = false;

  // Track message count to only scroll on new messages
  int _prevMessageCount = 0;

  StreamSubscription? _statusSub;

  String get _uid    => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _myName => FirebaseAuth.instance.currentUser?.displayName ?? 'Helper';

  @override
  void initState() {
    super.initState();
    _statusSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      final data       = snap.data() ?? {};
      final status     = data['bookingStatus'] as String? ?? 'active';
      final helperDone = data['helperConfirmedComplete'] as bool? ?? false;
      final userDone   = data['userConfirmedComplete']   as bool? ?? false;

      if (!mounted) return;
      setState(() {
        _helperConfirmed = helperDone;
        _userConfirmed   = userDone;
        _isCompleted     = status == 'completed' || status == 'cancelled';
      });

      if (helperDone && userDone && !_mutualCompletionHandled) {
        _mutualCompletionHandled = true;
        _onMutuallyConfirmed();
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();

    await RealtimeDbService.instance.sendMessage(
      chatId:     widget.chatId,
      senderId:   _uid,
      senderName: _myName,
      text:       text,
      role:       'helper',
    );

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage':                  text,
      'lastMessageTime':              FieldValue.serverTimestamp(),
      'unreadCount_${widget.userId}': FieldValue.increment(1),
    }).catchError((_) {});

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  // Only scroll when new messages arrive, not on every rebuild
  void _scrollToBottomIfNeeded(int currentCount) {
    if (currentCount > _prevMessageCount) {
      _prevMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmSevaDone() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Seva Completed?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'This will notify the customer to confirm payment.\n\n'
              'Service: "${widget.serviceName ?? 'the service'}"',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await BookingChatService.instance.onHelperConfirmedComplete(
      bookingId:  widget.bookingId ?? widget.chatId,
      chatId:     widget.chatId,
      helperName: _myName,
      userId:     widget.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Customer has been notified to confirm payment.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onMutuallyConfirmed() async {
    if (!mounted) return;
    await BookingChatService.instance.onMutualCompletionConfirmed(
      bookingId:   widget.bookingId ?? widget.chatId,
      chatId:      widget.chatId,
      userId:      widget.userId,
      serviceName: widget.serviceName ?? 'Service',
    );
    if (!mounted) return;
    MutualReviewSheet.showForHelper(
      context,
      bookingId:   widget.bookingId ?? widget.chatId,
      userId:      widget.userId,
      userName:    widget.userName,
      serviceName: widget.serviceName ?? '',
    );
  }

  // ── Cancel service (helper side) ─────────────────────────────────────────
  Future<void> _cancelService() async {
    Navigator.pop(context); // close bottom sheet
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Service?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to cancel "${widget.serviceName ?? "this service"}"? '
              'The customer will be notified.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'bookingStatus': 'cancelled'});

      if ((widget.bookingId ?? '').isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('bookingCode', isEqualTo: widget.bookingId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({
            'status':      'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'helper',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Service cancelled successfully.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to cancel. Try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Clear chat ───────────────────────────────────────────────────────────
  Future<void> _clearChat() async {
    Navigator.pop(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Chat?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will delete all messages.',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RealtimeDbService.instance.deleteChat(widget.chatId);
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'lastMessage': '', 'lastMessageTime': null})
          .catchError((_) {});
    } catch (_) {}
  }

  // ── Report user — opens contact URL with pre-filled info ─────────────────
  Future<void> _reportUser() async {
    Navigator.pop(context);
    final url = Uri.parse(
      'https://vighyatojha.github.io/TroubleSarthi_web/contact.html'
          '?name=${Uri.encodeComponent(_myName)}'
          '&message=${Uri.encodeComponent('Report: User ${widget.userName} (ID: ${widget.userId}) — Service: ${widget.serviceName ?? 'N/A'}. Booking ID: ${widget.bookingId ?? 'N/A'}.')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final fallback = Uri.parse(
          'https://vighyatojha.github.io/TroubleSarthi_web/contact.html');
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ── View booking details ─────────────────────────────────────────────────
  void _viewBookingDetails() {
    Navigator.pop(context); // close sheet
    // Replace with your BookingDetailScreen navigation if available:
    // Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: widget.bookingId)));
    Navigator.pop(context); // fallback: go back to list
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _HelperChatOptionsSheet(
        userName:        widget.userName,
        userId:          widget.userId,
        isCompleted:     _isCompleted,
        onClearChat:     _clearChat,
        onReport:        _reportUser,
        onViewBooking:   _viewBookingDetails,
        onCancelService: _cancelService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: _rBg,
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        _buildHeader(initial),
        if (_userConfirmed && !_isCompleted && !_mutualCompletionHandled)
          const _UserConfirmedBanner(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: RealtimeDbService.instance.messagesStream(widget.chatId),
            builder: (context, snap) {
              // Show loader only on first load, not on every update
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: _rPurple, strokeWidth: 2));
              }
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return _EmptyChat(name: widget.userName);
              }

              // Smooth scroll: only when count grows
              _scrollToBottomIfNeeded(messages.length);

              return ListView.builder(
                controller:  _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                itemCount:   messages.length,
                // KEY: stabilises list widget identity across rebuilds
                key: PageStorageKey(widget.chatId),
                itemBuilder: (_, i) {
                  final msg  = messages[i];
                  final isMe = msg['senderId'] == _uid;
                  final type = msg['type'] as String? ?? 'text';
                  final ts   = (msg['timestamp'] as int?) ?? 0;

                  if (type == 'booking_confirmed' ||
                      type == 'system' ||
                      type == 'system_warning') {
                    return _SystemMsg(text: msg['text'] ?? '');
                  }

                  if (type == 'payment_confirmation_pending') {
                    return _PaymentReceivedQuery(
                      chatId:        widget.chatId,
                      bookingId:     widget.bookingId ?? widget.chatId,
                      userId:        widget.userId,
                      helperName:    _myName,
                      helperId:      _uid,
                      paymentMethod: (msg['paymentMethod'] as String?) ?? 'cash',
                      serviceName:   widget.serviceName ?? 'Service',
                    );
                  }

                  if (type == 'receipt_ready') {
                    return _SystemMsg(
                      text: '🎉 Payment confirmed! Job complete. Check your earnings.',
                    );
                  }

                  final showDate = i == 0 ||
                      _diffDay(
                          (messages[i - 1]['timestamp'] as int?) ?? 0, ts);

                  return Column(children: [
                    if (showDate) _DateSep(timestamp: ts),
                    _Bubble(
                      text:       msg['text'] ?? '',
                      isMe:       isMe,
                      senderName: msg['senderName'] ?? '',
                      timestamp:  ts,
                    ),
                  ]);
                },
              );
            },
          ),
        ),
        _isCompleted
            ? const _CompletedBar()
            : _helperConfirmed && !_userConfirmed
            ? const _WaitingForUserBar()
            : _buildInputBar(),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(String initial) {
    final showSevaDone = !_helperConfirmed && !_isCompleted;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_rIndigo, _rViolet, _rPurple],
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14, left: 4, right: 8),
          child: Row(children: [
            // ← Back
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
            ),

            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                const LinearGradient(colors: [_rCyan, _rPurple]),
                border: Border.all(
                    color: Colors.white.withOpacity(0.30), width: 2),
                image: widget.userPhoto != null
                    ? DecorationImage(
                    image: NetworkImage(widget.userPhoto!),
                    fit: BoxFit.cover)
                    : null,
              ),
              child: widget.userPhoto == null
                  ? Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)))
                  : null,
            ),
            const SizedBox(width: 10),

            // Name + service — same layout as user side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  if ((widget.serviceName ?? '').isNotEmpty)
                    Text(
                      widget.serviceName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFB2E8E8), fontSize: 11),
                    ),
                ],
              ),
            ),

            // Seva Done button OR "Awaiting user" chip
            if (showSevaDone)
              GestureDetector(
                onTap: _confirmSevaDone,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Seva Done',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
              )
            else if (_helperConfirmed && !_userConfirmed && !_isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 1.5),
                      ),
                      SizedBox(width: 6),
                      Text('Awaiting user',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),

            const SizedBox(width: 4),

            // 3-dot menu — matching user side
            IconButton(
              onPressed: _showOptionsMenu,
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 22),
              padding: const EdgeInsets.all(8),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Input bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Quick Replies Row ────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: _quickReplies.map((reply) => GestureDetector(
              onTap: () async {
                await RealtimeDbService.instance.sendMessage(
                  chatId:     widget.chatId,
                  senderId:   _uid,
                  senderName: _myName,
                  text:       reply,
                  role:       'helper',
                );
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .update({
                  'lastMessage':                  reply,
                  'lastMessageTime':              FieldValue.serverTimestamp(),
                  'unreadCount_${widget.userId}': FieldValue.increment(1),
                }).catchError((_) {});
                _scrollToBottom();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: _rPurple.withOpacity(0.30)),
                ),
                child: Text(reply,
                    style: const TextStyle(
                        color: _rPurple, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ),

        // ── Text input + send button ──────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
              12, 6, 12, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color:  Colors.white,
            border: Border(top: BorderSide(color: _rPurple.withOpacity(0.10))),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset: const Offset(0, -3)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(24),
                    border:       Border.all(color: _rPurple.withOpacity(0.18)),
                  ),
                  child: TextField(
                    controller:          _msgCtrl,
                    maxLines:            null,
                    textCapitalization:  TextCapitalization.sentences,
                    style: const TextStyle(color: Color(0xFF1E1B4B), fontSize: 14),
                    decoration: const InputDecoration(
                      hintText:       'Type a message...',
                      hintStyle:      TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
                      border:         InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isSending ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: _isSending
                        ? LinearGradient(colors: [_rPurple.withOpacity(0.4), _rPurple.withOpacity(0.4)])
                        : const LinearGradient(
                        colors: [_rPurple, Color(0xFF9333EA)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isSending ? [] : [
                      BoxShadow(color: _rPurple.withOpacity(0.30),
                          blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _diffDay(int ts1, int ts2) {
    final a = DateTime.fromMillisecondsSinceEpoch(ts1);
    final b = DateTime.fromMillisecondsSinceEpoch(ts2);
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CHAT OPTIONS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _HelperChatOptionsSheet extends StatelessWidget {
  final String userName, userId;
  final bool isCompleted;
  final VoidCallback onClearChat;
  final VoidCallback onReport;
  final VoidCallback onViewBooking;
  final VoidCallback onCancelService;

  const _HelperChatOptionsSheet({
    required this.userName,
    required this.userId,
    required this.isCompleted,
    required this.onClearChat,
    required this.onReport,
    required this.onViewBooking,
    required this.onCancelService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Chat Options',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
          ),
          const SizedBox(height: 16),

          _OptionTile(
            icon:      Icons.receipt_long_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg:    const Color(0xFFEDE9FE),
            title:     'View Booking Details',
            subtitle:  'See the service booking info',
            onTap:     onViewBooking,
          ),

          _OptionTile(
            icon:      Icons.cleaning_services_rounded,
            iconColor: const Color(0xFF0891B2),
            iconBg:    const Color(0xFFE0F2FE),
            title:     'Clear Chat',
            subtitle:  'Remove all messages',
            onTap:     onClearChat,
          ),

          if (!isCompleted)
            _OptionTile(
              icon:      Icons.cancel_rounded,
              iconColor: const Color(0xFFDC2626),
              iconBg:    const Color(0xFFFEE2E2),
              title:     'Cancel Service',
              subtitle:  'Cancel and notify the user',
              onTap:     onCancelService,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFF3F4F6)),
          ),

          _OptionTile(
            icon:      Icons.flag_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg:    const Color(0xFFFEE2E2),
            title:     'Report User',
            subtitle:  'Report inappropriate behavior',
            onTap:     onReport,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB), size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _UserConfirmedBanner extends StatelessWidget {
  const _UserConfirmedBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    color: const Color(0xFFF0FDF4),
    child: const Row(children: [
      SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(
            color: Color(0xFF059669), strokeWidth: 2),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Text(
          'Customer confirmed payment! Loading review…',
          style: TextStyle(
              fontSize: 13,
              color: Color(0xFF065F46),
              fontWeight: FontWeight.w500),
        ),
      ),
    ]),
  );
}

class _WaitingForUserBar extends StatelessWidget {
  const _WaitingForUserBar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    color: const Color(0xFFFFF7ED),
    child: const Row(children: [
      Icon(Icons.hourglass_top_rounded,
          color: Color(0xFFD97706), size: 18),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'Waiting for customer to confirm payment…',
          style: TextStyle(
              fontSize: 13,
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w500),
        ),
      ),
    ]),
  );
}

class _CompletedBar extends StatelessWidget {
  const _CompletedBar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    color: const Color(0xFFF0FDF4),
    child: const Row(children: [
      Icon(Icons.check_circle_rounded,
          color: Color(0xFF059669), size: 20),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'Service completed — chat is now closed.',
          style: TextStyle(
              fontSize: 13,
              color: Color(0xFF065F46),
              fontWeight: FontWeight.w500),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM MESSAGE
// ─────────────────────────────────────────────────────────────────────────────

class _SystemMsg extends StatelessWidget {
  final String text;
  const _SystemMsg({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _rPurple.withOpacity(0.18)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _rPurple, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5B21B6),
                    height: 1.5)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text, senderName;
  final bool   isMe;
  final int    timestamp;

  const _Bubble({
    required this.text,
    required this.isMe,
    required this.senderName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final time = timestamp > 0
        ? _fmt(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_rCyan, _rPurple]),
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty
                      ? senderName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                        colors: [_rPurple, Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: const Color(0xFFEDE9FE)),
                    boxShadow: [
                      BoxShadow(
                          color: isMe
                              ? _rPurple.withOpacity(0.20)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(text,
                      style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : const Color(0xFF1E1B4B),
                          fontSize: 14,
                          height: 1.4)),
                ),
                const SizedBox(height: 3),
                Text(time,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE SEPARATOR
// ─────────────────────────────────────────────────────────────────────────────

class _DateSep extends StatelessWidget {
  final int timestamp;
  const _DateSep({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else if (now.difference(dt).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('d MMM').format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: _rPurple.withOpacity(0.10))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: _rPurple.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: _rPurple,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(child: Divider(color: _rPurple.withOpacity(0.10))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CHAT
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String name;
  const _EmptyChat({required this.name});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
              color: _rPurple.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _rPurple.withOpacity(0.15), width: 2)),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 34, color: _rPurple),
        ),
        const SizedBox(height: 18),
        Text('Chat with $name',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B))),
        const SizedBox(height: 6),
        const Text(
          'Your conversation will appear here.',
          style:
          TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ]),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT RECEIVED QUERY WIDGET  (helper side)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentReceivedQuery extends StatefulWidget {
  final String chatId, bookingId, userId, helperName, helperId,
      paymentMethod, serviceName;
  const _PaymentReceivedQuery({
    required this.chatId,
    required this.bookingId,
    required this.userId,
    required this.helperName,
    required this.helperId,
    required this.paymentMethod,
    required this.serviceName,
  });
  @override
  State<_PaymentReceivedQuery> createState() => _PaymentReceivedQueryState();
}

class _PaymentReceivedQueryState extends State<_PaymentReceivedQuery> {
  bool _answered  = false;
  bool _isLoading = false;

  Future<void> _onYes() async {
    setState(() => _isLoading = true);
    try {
      await BookingChatService.instance.onHelperConfirmedPaymentReceived(
        bookingId:   widget.bookingId,
        chatId:      widget.chatId,
        userId:      widget.userId,
        helperId:    widget.helperId,
        helperName:  widget.helperName,
        serviceName: widget.serviceName,
      );
      if (mounted) setState(() { _answered = true; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onNo() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Please contact support if payment was not received.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_answered) {
      return _SystemMsg(text: '✅ You confirmed payment received. Receipt sent to customer.');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.payment_rounded, color: Color(0xFFD97706), size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Customer confirmed payment. Have you received it?',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _onYes,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isLoading
                      ? const Center(child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : const Text('✓  Yes, Received',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _onNo,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                  ),
                  child: const Text('✗  No, Not Yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}