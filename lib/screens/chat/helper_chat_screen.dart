// lib/screens/chat/helper_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../services/realtime_db_service.dart';
import 'helper_chat_room_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _purple  = Color(0xFF7C3AED);
const _indigo  = Color(0xFF2D1B69);
const _violet  = Color(0xFF5B21B6);
const _cyan    = Color(0xFF06B6D4);
const _green   = Color(0xFF16A34A);
const _amber   = Color(0xFFF59E0B);
const _red     = Color(0xFFEF4444);
const _bgLight = Color(0xFFF8F7FF);

extension _Op on Color {
  Color op(double a) => withOpacity(a);
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), _indigo, _violet, _purple],
        ),
      ),
      child: Column(children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.op(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.op(0.25)),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(hi ? 'मेरी चैट' : 'My Chats',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.op(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _purple.op(0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _purple,
            unselectedLabelColor: Colors.white.op(0.70),
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: hi ? 'बुकिंग चैट' : 'Booking Chats'),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(hi ? 'सपोर्ट' : 'Admin Support'),
                    if (_supportUnread > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('$_supportUnread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Booking Chat List
// ✅ FIX: removed orderBy('lastMessageTime') — now sorts client-side
//         This eliminates the "Firestore index required" error
// ═══════════════════════════════════════════════════════════════════════════════
class _BookingChatList extends StatelessWidget {
  final String uid;
  final bool hi;
  const _BookingChatList({required this.uid, required this.hi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _emptyState();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('helperId', isEqualTo: uid)
      // ✅ No orderBy — avoids composite index requirement
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _purple, strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_rounded,
                    color: _amber, size: 48),
                const SizedBox(height: 12),
                Text(
                  hi
                      ? 'चैट लोड नहीं हो सकी।'
                      : 'Could not load chats. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF374151), fontSize: 14),
                ),
              ]),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState();

        // ✅ Sort client-side by lastMessageTime descending
        final sorted = [...docs]..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['lastMessageTime'] as Timestamp?;
          final bTs = bData['lastMessageTime'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final d = sorted[i].data() as Map<String, dynamic>;
            final chatId    = sorted[i].id;
            final name      = (d['userName']        as String?) ?? 'Customer';
            final userId    = (d['userId']          as String?) ?? '';
            final lastMsg   = (d['lastMessage']     as String?) ?? '';
            final time      = (d['lastMessageTime'] as Timestamp?)?.toDate();
            final unread    = ((d['helperUnread']   ?? 0) as num).toInt();
            final svc       = (d['serviceName']     as String?) ?? '';
            final bookId    = (d['bookingId']       as String?) ?? '';
            final status    = (d['bookingStatus']   as String?) ?? '';
            final userPhoto = (d['userPhoto']       as String?);

            return _ChatTile(
              chatId:        chatId,
              bookingId:     bookId,
              userId:        userId,
              userName:      name,
              lastMessage:   lastMsg,
              lastTime:      time,
              unreadCount:   unread,
              serviceName:   svc,
              bookingStatus: status,
              userPhoto:     userPhoto,
            );
          },
        );
      },
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
            color: _purple.op(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: _purple.op(0.15), width: 2)),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: _purple, size: 38),
      ),
      const SizedBox(height: 18),
      Text(
        hi ? 'कोई बुकिंग चैट नहीं' : 'No booking chats yet',
        style: const TextStyle(
            color: Color(0xFF1E1B4B),
            fontSize: 17,
            fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        hi
            ? 'बुकिंग स्वीकार करें तो चैट शुरू होगी'
            : 'Accept a booking to start chatting',
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
    ]),
  );
}

// ─── Chat list tile ───────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String  chatId, bookingId, userId, userName,
      lastMessage, serviceName, bookingStatus;
  final DateTime? lastTime;
  final int       unreadCount;
  final String?   userPhoto;

  const _ChatTile({
    required this.chatId,
    required this.bookingId,
    required this.userId,
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
      case 'completed':   return _green;
      case 'accepted':    return _purple;
      case 'in_progress': return _cyan;
      default:            return _amber;
    }
  }

  String get _statusLabel {
    switch (bookingStatus.toLowerCase()) {
      case 'completed':   return 'Completed';
      case 'accepted':    return 'Accepted';
      case 'in_progress': return 'In Progress';
      case 'ongoing':     return 'Ongoing';
      default:            return bookingStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials  = userName.isNotEmpty ? userName[0].toUpperCase() : 'C';
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      onTap: () async {
        await RealtimeDbService.instance.resetHelperUnread(chatId);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelperChatRoomScreen(
                chatId:      chatId,
                bookingId:   bookingId,
                userId:      userId,
                userName:    userName,
                serviceName: serviceName,
                userPhoto:   userPhoto,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasUnread ? _purple.op(0.35) : const Color(0xFFEDE9FE),
            width: hasUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: hasUnread
                    ? _purple.op(0.12)
                    : Colors.black.op(0.04),
                blurRadius: hasUnread ? 16 : 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          // ── Avatar ────────────────────────────────────────────────
          Stack(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_purple.op(0.70), _purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(
                    color: hasUnread ? _purple : _purple.op(0.20),
                    width: 2),
                image: (userPhoto != null && userPhoto!.isNotEmpty)
                    ? DecorationImage(
                    image: NetworkImage(userPhoto!),
                    fit: BoxFit.cover)
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
                bottom: 0, right: 0,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 13),

          // ── Text ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(userName,
                        style: TextStyle(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w700)),
                  ),
                  if (lastTime != null)
                    Text(_timeLabel(lastTime!),
                        style: TextStyle(
                            color: hasUnread
                                ? _purple
                                : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                        color: _statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      serviceName.isNotEmpty ? serviceName : _statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: hasUnread
                              ? const Color(0xFF374151)
                              : const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400),
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
// TAB 2 — Admin Support Chat  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════
class _SupportChatRoom extends StatefulWidget {
  final String uid;
  final bool hi;
  const _SupportChatRoom({required this.uid, required this.hi});

  @override
  State<_SupportChatRoom> createState() => _SupportChatRoomState();
}

class _SupportChatRoomState extends State<_SupportChatRoom> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool  _sending    = false;
  bool  _loaded     = false;

  DatabaseReference get _msgsRef =>
      FirebaseDatabase.instance
          .ref('support_chats/${widget.uid}/messages');
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
    try { await _metaRef.update({'unreadHelper': 0}); } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.uid.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();

    final helper     = FirebaseAuth.instance.currentUser;
    final helperName = helper?.displayName ?? 'Helper';
    final now        = DateTime.now().millisecondsSinceEpoch;

    try {
      await _msgsRef.push().set({
        'text':       text,
        'senderId':   widget.uid,
        'senderName': helperName,
        'senderRole': 'helper',
        'timestamp':  now,
        'read':       false,
      });
      await _metaRef.update({
        'helperName':      helperName,
        'helperId':        widget.uid,
        'lastMessage':     text,
        'lastMessageTime': now,
        'lastSenderId':    widget.uid,
        'status':          'open',
        'unreadAdmin':     ServerValue.increment(1),
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating));
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
            if (snap.connectionState == ConnectionState.waiting && !_loaded) {
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
                  key:      e.key,
                  text:     (d['text']       as String?) ?? '',
                  senderId: (d['senderId']   as String?) ?? '',
                  role:     (d['senderRole'] as String?) ?? 'helper',
                  ts:       (d['timestamp']  as int?)    ?? 0,
                );
              }).toList()
                ..sort((a, b) => a.ts.compareTo(b.ts));

              for (final m in msgs) {
                if (m.role == 'admin') {
                  _msgsRef.child(m.key).update({'read': true}).catchError((_) {});
                }
              }
            }

            if (msgs.isEmpty) return _emptySupport();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) {
                _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
              }
            });

            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m        = msgs[i];
                final isMe     = m.senderId == widget.uid;
                final showTime = i == msgs.length - 1 ||
                    msgs[i + 1].ts - m.ts > 300000;
                final showDate = i == 0 || !_sameDay(msgs[i - 1].ts, m.ts);
                return Column(children: [
                  if (showDate) _DateDivider(ts: m.ts),
                  _SupportBubble(msg: m, isMe: isMe, showTime: showTime),
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
            ? Map<String, dynamic>.from(snap.data!.snapshot.value as Map)
            : <String, dynamic>{};
        final status     = (d['status'] as String?) ?? 'open';
        final isResolved = status == 'resolved';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isResolved ? _green.op(0.06) : _purple.op(0.05),
            border: Border(
                bottom: BorderSide(
                    color: isResolved ? _green.op(0.18) : _purple.op(0.12))),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isResolved ? _green.op(0.10) : _purple.op(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.headset_mic_rounded,
                    size: 11, color: isResolved ? _green : _purple),
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
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _purple.op(0.10))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.op(0.05),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 110),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _purple.op(0.18)),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines:   null,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      color: Color(0xFF1E1B4B), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.hi
                        ? 'सपोर्ट टीम को संदेश लिखें...'
                        : 'Message the support team...',
                    hintStyle: const TextStyle(
                        color: Color(0xFFADB5BD), fontSize: 13),
                    border:         InputBorder.none,
                    enabledBorder:  InputBorder.none,
                    focusedBorder:  InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: _sending
                      ? LinearGradient(
                      colors: [_purple.op(0.4), _purple.op(0.4)])
                      : const LinearGradient(
                      colors: [Color(0xFF9333EA), _purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _sending
                      ? []
                      : [
                    BoxShadow(
                        color: _purple.op(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: _sending
                      ? const SizedBox(
                      width: 18, height: 18,
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
          width: 88, height: 88,
          decoration: BoxDecoration(
              color: _purple.op(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _purple.op(0.15), width: 2)),
          child: const Icon(Icons.headset_mic_rounded,
              color: _purple, size: 38),
        ),
        const SizedBox(height: 20),
        Text(
          widget.hi ? 'सपोर्ट टीम से बात करें' : 'Chat with Support Team',
          style: const TextStyle(
              color: Color(0xFF1E1B4B),
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          widget.hi
              ? 'कोई समस्या है? हमें लिखें, हम जल्द जवाब देंगे।'
              : 'Have a question or issue? Send us a message.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 24),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _purple.op(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _purple.op(0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              widget.hi ? 'सपोर्ट टीम ऑनलाइन है' : 'Support team is online',
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
  final int    ts;
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
    final dt      = DateTime.fromMillisecondsSinceEpoch(msg.ts);
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
                width: 32, height: 32,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_purple, Color(0xFF9333EA)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                    child: Icon(Icons.headset_mic_rounded,
                        color: Colors.white, size: 15)),
              ),
            ],
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.70),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
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
                          ? _purple.op(0.18)
                          : Colors.black.op(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
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
                              : const Color(0xFF1E1B4B),
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
          alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: 10, left: isMe ? 0 : 48, right: 4),
            child: Text(timeStr,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 10)),
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
    final dt  = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else if (now.difference(dt).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('d MMM yyyy').format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Divider(color: _purple.op(0.10))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: _purple.op(0.07),
              borderRadius: BorderRadius.circular(20)),
          child: Text(label,
              style: const TextStyle(
                  color: _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: _purple.op(0.10))),
      ]),
    );
  }
}