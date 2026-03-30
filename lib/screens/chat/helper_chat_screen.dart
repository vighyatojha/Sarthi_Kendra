// lib/screens/chat/helper_chat_screen.dart
//
// Enhanced Chat Hub — 2 tabs:
//   Tab 1: Booking Chats  (Firestore list → RTDB messages)
//   Tab 2: Support Chat   (RTDB support_chats/{uid} ↔ Admin panel)
//
// HOW BOOKING CHATS ARE CONNECTED TO USER SIDE
// ─────────────────────────────────────────────
// When a helper accepts a booking, call:
//
//   final chatId = await BookingChatService.instance.onBookingAccepted(
//     bookingId:     booking.id,
//     helperId:      helperUid,
//     helperName:    helperDisplayName,
//     helperPhoto:   helperPhotoUrl,      // optional
//     userId:        booking.userId,
//     userName:      booking.userName,
//     serviceName:   booking.serviceName,
//     scheduledTime: booking.scheduledTime, // e.g. "10:00 AM, 30 Mar 2026"
//   );
//
// This creates the shared Firestore `chats/{chatId}` document and fires an
// automated RTDB message that appears in BOTH apps instantly.
//
// RTDB structure (shared with user side):
//   chats/{chatId}/messages/{msgId}   ← messages readable by both sides
//
// Firestore structure:
//   chats/{chatId}                    ← metadata, participants, unread counters
//   support_chats/{uid}               ← admin support metadata
//   support_chats/{uid}/messages      ← admin support messages

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/booking_chat_service.dart';
import '../../services/realtime_db_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _purple  = Color(0xFF7C3AED);
const _indigo  = Color(0xFF2D1B69);
const _violet  = Color(0xFF5B21B6);
const _cyan    = Color(0xFF06B6D4);
const _green   = Color(0xFF16A34A);
const _amber   = Color(0xFFF59E0B);
const _red     = Color(0xFFEF4444);
const _bgLight = Color(0xFFF2F3F8);
const _card    = Colors.white;

extension _Op on Color {
  Color op(double a) => withValues(alpha: a);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT — Chat Hub
// ═══════════════════════════════════════════════════════════════════════════════

class HelperChatScreen extends StatefulWidget {
  const HelperChatScreen({super.key});

  @override
  State<HelperChatScreen> createState() => _HelperChatScreenState();
}

class _HelperChatScreenState extends State<HelperChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _supportUnread = 0;
  StreamSubscription? _supportUnreadSub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _listenSupportUnread();
  }

  @override
  void dispose() {
    _supportUnreadSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _listenSupportUnread() {
    if (_uid.isEmpty) return;
    _supportUnreadSub = FirebaseDatabase.instance
        .ref('support_chats/$_uid/unreadHelper')
        .onValue
        .listen((e) {
      if (mounted) {
        setState(() => _supportUnread = (e.snapshot.value as int?) ?? 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hi = context.watch<LanguageProvider>().isHindi;
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(children: [
        _buildHeader(hi),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _BookingChatList(uid: _uid, hi: hi),
              _SupportChatRoom(uid: _uid, hi: hi),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(bool hi) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), _indigo, _violet, _purple],
        ),
      ),
      child: Column(children: [
        SizedBox(height: top + 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _purple.op(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.op(0.3)),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(hi ? 'मेरी चैट' : 'My Chats',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.op(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _purple,
            unselectedLabelColor: Colors.white.op(0.65),
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: hi ? 'बुकिंग चैट' : 'Booking Chats'),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(hi ? 'सपोर्ट' : 'Admin Support'),
                    if (_supportUnread > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('$_supportUnread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Booking Chat List
// ═══════════════════════════════════════════════════════════════════════════════

class _BookingChatList extends StatelessWidget {
  final String uid;
  final bool hi;
  const _BookingChatList({required this.uid, required this.hi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _emptyState();

    return StreamBuilder<QuerySnapshot>(
      // Queries the same `chats` collection that the user-side reads.
      // helperId field is written by BookingChatService.onBookingAccepted().
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('helperId', isEqualTo: uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _purple, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final chatId = docs[i].id;
            final name = (d['userName'] as String?) ?? 'Customer';
            final lastMsg = (d['lastMessage'] as String?) ?? '';
            final time =
            (d['lastMessageTime'] as Timestamp?)?.toDate();
            final unread = ((d['helperUnread'] ?? 0) as num).toInt();
            final svc = (d['serviceName'] as String?) ?? '';
            final bookId = (d['bookingId'] as String?) ?? '';
            final status = (d['bookingStatus'] as String?) ?? '';
            final userPhoto = (d['userPhoto'] as String?);

            return _ChatTile(
              chatId: chatId,
              bookingId: bookId,
              userName: name,
              lastMessage: lastMsg,
              lastTime: time,
              unreadCount: unread,
              serviceName: svc,
              bookingStatus: status,
              userPhoto: userPhoto,
            );
          },
        );
      },
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: _purple.op(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: _purple, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          hi ? 'कोई बुकिंग चैट नहीं' : 'No booking chats yet',
          style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          hi
              ? 'बुकिंग स्वीकार करें तो चैट शुरू होगी'
              : 'Accept a booking to start chatting',
          style:
          const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
      ],
    ),
  );
  // ignore: unused_field
  //bool get hi => false;
}

// ─── Chat list tile ───────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String chatId,
      bookingId,
      userName,
      lastMessage,
      serviceName,
      bookingStatus;
  final DateTime? lastTime;
  final int unreadCount;
  final String? userPhoto;

  const _ChatTile({
    required this.chatId,
    required this.bookingId,
    required this.userName,
    required this.lastMessage,
    required this.lastTime,
    required this.unreadCount,
    required this.serviceName,
    required this.bookingStatus,
    this.userPhoto,
  });

  Color get _statusColor {
    switch (bookingStatus.toLowerCase()) {
      case 'completed':
        return _green;
      case 'accepted':
        return _purple;
      case 'in_progress':
        return _cyan;
      default:
        return _amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : 'C';
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: () async {
        // Reset helper's unread counter on open
        await RealtimeDbService.instance.resetHelperUnread(chatId);

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelperChatRoomScreen(
                chatId: chatId,
                bookingId: bookingId,
                userName: userName,
                serviceName: serviceName,
                userPhoto: userPhoto,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: hasUnread
                  ? _purple.op(0.3)
                  : const Color(0xFFEDE9FE)),
          boxShadow: [
            BoxShadow(
                color: hasUnread ? _purple.op(0.10) : Colors.black.op(0.04),
                blurRadius: hasUnread ? 14 : 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          // ── Avatar ──────────────────────────────────────────────────
          Stack(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_purple.op(0.80), _purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(
                    color: hasUnread ? _purple : _purple.op(0.2), width: 2),
                image: (userPhoto != null && userPhoto!.isNotEmpty)
                    ? DecorationImage(
                    image: NetworkImage(userPhoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: (userPhoto == null || userPhoto!.isEmpty)
                  ? Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)))
                  : null,
            ),
            if (hasUnread)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
          ]),
          const SizedBox(width: 12),

          // ── Text content ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(userName,
                        style: TextStyle(
                          color: const Color(0xFF1F2937),
                          fontSize: 14,
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w700,
                        )),
                  ),
                  if (lastTime != null)
                    Text(_timeLabel(lastTime!),
                        style: TextStyle(
                            color: hasUnread
                                ? _purple
                                : const Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 3),
                if (serviceName.isNotEmpty)
                  Row(children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                          color: _statusColor, shape: BoxShape.circle),
                    ),
                    Text(serviceName,
                        style: const TextStyle(
                            color: _cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(
                    child: Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? const Color(0xFF374151)
                            : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _purple,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$unreadCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat('d MMM').format(dt);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Admin Support Chat (RTDB support_chats/{uid})
// ═══════════════════════════════════════════════════════════════════════════════

class _SupportChatRoom extends StatefulWidget {
  final String uid;
  final bool hi;
  const _SupportChatRoom({required this.uid, required this.hi});

  @override
  State<_SupportChatRoom> createState() => _SupportChatRoomState();
}

class _SupportChatRoomState extends State<_SupportChatRoom> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _loaded = false;

  DatabaseReference get _msgsRef =>
      FirebaseDatabase.instance.ref('support_chats/${widget.uid}/messages');

  DatabaseReference get _metaRef =>
      FirebaseDatabase.instance.ref('support_chats/${widget.uid}');

  @override
  void initState() {
    super.initState();
    _resetUnread();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetUnread() async {
    if (widget.uid.isEmpty) return;
    try {
      await _metaRef.update({'unreadHelper': 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.uid.isEmpty) return;

    setState(() => _sending = true);
    _ctrl.clear();

    final helper = FirebaseAuth.instance.currentUser;
    final helperName = helper?.displayName ?? 'Helper';
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _msgsRef.push().set({
        'text': text,
        'senderId': widget.uid,
        'senderName': helperName,
        'senderRole': 'helper',
        'timestamp': now,
        'read': false,
      });

      await _metaRef.update({
        'helperName': helperName,
        'helperId': widget.uid,
        'lastMessage': text,
        'lastMessageTime': now,
        'lastSenderId': widget.uid,
        'status': 'open',
        'unreadAdmin': ServerValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildStatusBar(),
      Expanded(
        child: StreamBuilder<DatabaseEvent>(
          stream: _msgsRef.orderByChild('timestamp').onValue,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !_loaded) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: _purple, strokeWidth: 2));
            }
            _loaded = true;

            List<_Msg> msgs = [];
            if (snap.hasData && snap.data!.snapshot.value != null) {
              final raw = Map<String, dynamic>.from(
                  snap.data!.snapshot.value as Map);
              msgs = raw.entries.map((e) {
                final d = Map<String, dynamic>.from(e.value as Map);
                return _Msg(
                  key: e.key,
                  text: (d['text'] as String?) ?? '',
                  senderId: (d['senderId'] as String?) ?? '',
                  role: (d['senderRole'] as String?) ?? 'helper',
                  ts: (d['timestamp'] as int?) ?? 0,
                );
              }).toList()
                ..sort((a, b) => a.ts.compareTo(b.ts));

              for (final m in msgs) {
                if (m.role == 'admin') {
                  _msgsRef
                      .child(m.key)
                      .update({'read': true}).catchError((_) {});
                }
              }
            }

            if (msgs.isEmpty) return _emptySupport();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) {
                _scrollCtrl
                    .jumpTo(_scrollCtrl.position.maxScrollExtent);
              }
            });

            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final isMe = m.senderId == widget.uid;
                final showTime = i == msgs.length - 1 ||
                    msgs[i + 1].ts - m.ts > 300000;
                final showDate =
                    i == 0 || !_sameDay(msgs[i - 1].ts, m.ts);
                return Column(children: [
                  if (showDate) _DateDivider(ts: m.ts),
                  _SupportBubble(
                      msg: m, isMe: isMe, showTime: showTime),
                ]);
              },
            );
          },
        ),
      ),
      _buildInput(),
    ]);
  }

  Widget _buildStatusBar() {
    return StreamBuilder<DatabaseEvent>(
      stream: _metaRef.onValue,
      builder: (_, snap) {
        final d = snap.data?.snapshot.value != null
            ? Map<String, dynamic>.from(
            snap.data!.snapshot.value as Map)
            : <String, dynamic>{};
        final status = (d['status'] as String?) ?? 'open';
        final isResolved = status == 'resolved';

        return Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isResolved ? _green.op(0.08) : _purple.op(0.06),
            border: Border(
                bottom: BorderSide(
                    color: isResolved
                        ? _green.op(0.20)
                        : _purple.op(0.15))),
          ),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: isResolved ? _green : _amber,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isResolved
                    ? (widget.hi ? 'समस्या हल हो गई ✓' : 'Issue Resolved ✓')
                    : (widget.hi
                    ? 'अभी ऑनलाइन — सपोर्ट टीम से चैट करें'
                    : 'Live Support · Admin is monitoring'),
                style: TextStyle(
                    color: isResolved ? _green : _purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isResolved ? _green.op(0.12) : _purple.op(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.headset_mic_rounded, size: 11),
                const SizedBox(width: 4),
                Text('SUPPORT',
                    style: TextStyle(
                        color: isResolved ? _green : _purple,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _purple.op(0.12))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.op(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 110),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _purple.op(0.20)),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: Color(0xFF1F2937), fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hi
                    ? 'सपोर्ट टीम को संदेश लिखें...'
                    : 'Message the support team...',
                hintStyle: const TextStyle(
                    color: Color(0xFFADB5BD), fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: _sending
                  ? LinearGradient(
                  colors: [_purple.op(0.4), _purple.op(0.4)])
                  : const LinearGradient(
                  colors: [Color(0xFF9333EA), _purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _sending
                  ? []
                  : [
                BoxShadow(
                    color: _purple.op(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: _sending
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emptySupport() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: _purple.op(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.headset_mic_rounded,
              color: _purple, size: 36),
        ),
        const SizedBox(height: 18),
        Text(
          widget.hi ? 'सपोर्ट टीम से बात करें' : 'Chat with Support Team',
          style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          widget.hi
              ? 'कोई समस्या है? हमें लिखें, हम जल्द जवाब देंगे।'
              : 'Have a question or issue? Send us a message.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _purple.op(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _purple.op(0.20)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              widget.hi
                  ? 'सपोर्ट टीम ऑनलाइन है'
                  : 'Support team is online',
              style: const TextStyle(
                  color: _purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    ),
  );

  bool _sameDay(int ts1, int ts2) {
    final a = DateTime.fromMillisecondsSinceEpoch(ts1);
    final b = DateTime.fromMillisecondsSinceEpoch(ts2);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─── Support message model ────────────────────────────────────────────────────

class _Msg {
  final String key, text, senderId, role;
  final int ts;
  const _Msg({
    required this.key,
    required this.text,
    required this.senderId,
    required this.role,
    required this.ts,
  });
}

// ─── Support message bubble ───────────────────────────────────────────────────

class _SupportBubble extends StatelessWidget {
  final _Msg msg;
  final bool isMe, showTime;
  const _SupportBubble(
      {required this.msg, required this.isMe, required this.showTime});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(msg.ts);
    final timeStr = DateFormat('h:mm a').format(dt);

    return Column(children: [
      Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_purple, Color(0xFF9333EA)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Icon(Icons.headset_mic_rounded,
                        color: Colors.white, size: 14)),
              ),
            ],
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.70),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(color: const Color(0xFFEDE9FE)),
                boxShadow: [
                  BoxShadow(
                      color: isMe ? _purple.op(0.20) : Colors.black.op(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('Support Team',
                          style: TextStyle(
                              color: _purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  Text(msg.text,
                      style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : const Color(0xFF1F2937),
                          fontSize: 14,
                          height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
      if (showTime)
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: 10, left: isMe ? 0 : 46, right: 4),
            child: Text(timeStr,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 10)),
          ),
        ),
    ]);
  }
}

// ─── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final int ts;
  const _DateDivider({required this.ts});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String label;
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      label = 'Today';
    } else if (now.difference(dt).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('d MMM yyyy').format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Divider(color: _purple.op(0.12))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: _purple.op(0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: const TextStyle(
                  color: _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: _purple.op(0.12))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOOKING CHAT ROOM SCREEN
// Reads/writes RTDB `chats/{chatId}/messages` — same path as user-side ChatScreen.
// ═══════════════════════════════════════════════════════════════════════════════

class HelperChatRoomScreen extends StatefulWidget {
  final String chatId, bookingId, userName;
  final String? serviceName, userPhoto;

  const HelperChatRoomScreen({
    super.key,
    required this.chatId,
    required this.bookingId,
    required this.userName,
    this.serviceName,
    this.userPhoto,
  });

  @override
  State<HelperChatRoomScreen> createState() => _HelperChatRoomScreenState();
}

class _HelperChatRoomScreenState extends State<HelperChatRoomScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Helper';

  // ── Shared RTDB path — same as user-side RealtimeDbService.messagesStream() ─
  DatabaseReference get _msgsRef =>
      FirebaseDatabase.instance.ref('chats/${widget.chatId}/messages');

  DocumentReference get _chatDoc =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  @override
  void initState() {
    super.initState();
    // Reset helper's unread counter when room opens
    RealtimeDbService.instance.resetHelperUnread(widget.chatId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _uid.isEmpty) return;

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Write to shared RTDB path — user sees this in their ChatScreen
      await _msgsRef.push().set({
        'text': text,
        'senderId': _uid,
        'senderName': _myName,
        'senderRole': 'helper',
        'timestamp': now,
        'read': false,
      });

      // Update Firestore metadata — user's messages list refreshes
      await _chatDoc.update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'userUnread': FieldValue.increment(1),
        // Also increment the key-per-uid counter the user-side reads
        'unreadCount_${await _getUserId()}': FieldValue.increment(1),
      }).catchError((_) {});

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  /// Reads userId from the Firestore chat document so we can
  /// increment the correct `unreadCount_{userId}` field.
  Future<String> _getUserId() async {
    try {
      final snap = await _chatDoc.get();
      return (snap.data() as Map<String, dynamic>?)?['userId'] as String? ??
          '';
    } catch (_) {
      return '';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _markComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark Service Complete?',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
            'Confirm "${widget.serviceName ?? 'the service'}" is done?',
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Done',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final userId = await _getUserId();
      await BookingChatService.instance.onBookingCompleted(
        bookingId: widget.bookingId,
        chatId: widget.chatId,
        userId: userId,
        serviceName: widget.serviceName ?? 'Service',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Service marked as completed!'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : 'C';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgLight,
      body: Column(children: [
        _buildHeader(initials),
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: StreamBuilder<DatabaseEvent>(
              stream: _msgsRef.orderByChild('timestamp').onValue,
              builder: (ctx, snap) {
                List<_Msg> msgs = [];

                if (snap.hasData && snap.data!.snapshot.value != null) {
                  final raw = Map<String, dynamic>.from(
                      snap.data!.snapshot.value as Map);
                  msgs = raw.entries.map((e) {
                    final d = Map<String, dynamic>.from(e.value as Map);
                    return _Msg(
                      key: e.key,
                      text: (d['text'] as String?) ?? '',
                      senderId: (d['senderId'] as String?) ?? '',
                      role: (d['senderRole'] as String?) ?? 'user',
                      ts: (d['timestamp'] as int?) ?? 0,
                    );
                  }).toList()
                    ..sort((a, b) => a.ts.compareTo(b.ts));

                  // Mark user messages as read
                  for (final m in msgs) {
                    if (m.role == 'user') {
                      _msgsRef
                          .child(m.key)
                          .update({'read': true}).catchError((_) {});
                    }
                  }
                }

                if (msgs.isEmpty) return _emptyChat();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl
                        .jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isMe = m.senderId == _uid;
                    final showTime = i == msgs.length - 1 ||
                        msgs[i + 1].ts - m.ts > 300000;
                    final showDate =
                        i == 0 || !_sameDay(msgs[i - 1].ts, m.ts);
                    return Column(children: [
                      if (showDate) _DateDivider(ts: m.ts),
                      _RoomBubble(
                          msg: m,
                          isMe: isMe,
                          showTime: showTime,
                          initials: initials),
                    ]);
                  },
                );
              },
            ),
          ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildHeader(String initials) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E0754), _indigo, _violet, _purple],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 14),
        child: Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF9333EA)]),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.35), width: 2),
              image: widget.userPhoto != null
                  ? DecorationImage(
                  image: NetworkImage(widget.userPhoto!),
                  fit: BoxFit.cover)
                  : null,
            ),
            child: widget.userPhoto == null
                ? Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                if (widget.serviceName != null) ...[
                  const SizedBox(height: 2),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .doc(widget.bookingId)
                        .snapshots(),
                    builder: (_, snap) {
                      final s = (snap.data?.data()
                      as Map<String, dynamic>?)?['status']
                      as String? ??
                          '';
                      return Text(_statusLabel(s),
                          style: const TextStyle(
                              color: Color(0xFFB2E8E8), fontSize: 11));
                    },
                  ),
                ],
              ],
            ),
          ),
          // Mark complete button
          GestureDetector(
            onTap: _markComplete,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: _green.withOpacity(0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget _buildInput() => Container(
    padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3)),
      ],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 110),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _purple.withOpacity(0.15)),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                color: Color(0xFF1F2937), fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(
                  color: Color(0xFFADB5BD), fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              isDense: true,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _sending ? null : _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: _sending
                ? LinearGradient(
              colors: [
                _purple.withOpacity(0.4),
                _purple.withOpacity(0.4)
              ],
            )
                : const LinearGradient(
                colors: [Color(0xFF9333EA), _purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _sending
                ? []
                : [
              BoxShadow(
                  color: _purple.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: _sending
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    ]),
  );

  Widget _emptyChat() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: _purple.withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: _purple, size: 30),
        ),
        const SizedBox(height: 14),
        Text('Chat with ${widget.userName}',
            style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Say hello to start the conversation!',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12)),
      ],
    ),
  );

  bool _sameDay(int ts1, int ts2) {
    final a = DateTime.fromMillisecondsSinceEpoch(ts1);
    final b = DateTime.fromMillisecondsSinceEpoch(ts2);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'accepted':
        return 'Booking Accepted · ${widget.serviceName}';
      case 'in_progress':
        return 'Job In Progress';
      case 'completed':
        return 'Job Completed ✓';
      default:
        return widget.serviceName ?? 'Service Chat';
    }
  }
}

// ─── Booking chat room bubble ──────────────────────────────────────────────────

class _RoomBubble extends StatelessWidget {
  final _Msg msg;
  final bool isMe, showTime;
  final String initials;

  const _RoomBubble({
    required this.msg,
    required this.isMe,
    required this.showTime,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(msg.ts);
    final timeStr = DateFormat('h:mm a').format(dt);

    // System/booking-confirmed messages render as a centred info pill
    if (msg.role == 'system' || msg.role == 'booking_confirmed') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border:
            Border.all(color: _purple.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded,
                color: _purple, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg.text,
                  style: TextStyle(
                      fontSize: 12,
                      color: _violet,
                      height: 1.5)),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(children: [
        Row(
          mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 6, bottom: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_cyan, Color(0xFF9333EA)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.70),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                      colors: [
                        Color(0xFF7C3AED),
                        Color(0xFF9333EA)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                      color: const Color(0xFFEDE9FE)),
                  boxShadow: [
                    BoxShadow(
                        color: isMe
                            ? _purple.withOpacity(0.18)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(msg.text,
                    style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : const Color(0xFF1F2937),
                        fontSize: 14,
                        height: 1.4)),
              ),
            ),
          ],
        ),
        if (showTime)
          Align(
            alignment:
            isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                  top: 3,
                  bottom: 8,
                  left: isMe ? 0 : 42,
                  right: 4),
              child: Text(timeStr,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10)),
            ),
          ),
      ]),
    );
  }
}