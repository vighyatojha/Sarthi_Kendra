// lib/screens/chat/helper_chat_screen.dart
// Chat list + ChatRoom — Firebase Realtime Database
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CHAT LIST SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class HelperChatScreen extends StatelessWidget {
  const HelperChatScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hi     = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF2F3F8),
      body: Column(children: [
        _buildHeader(context, isDark, hi),
        Expanded(child: _uid.isEmpty
            ? _empty(isDark, hi)
            : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('helperId', isEqualTo: _uid)
              .orderBy('lastMessageTime', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppColors.brandPurple));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return _empty(isDark, hi);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d          = docs[i].data() as Map<String, dynamic>;
                final chatId     = docs[i].id;
                final userName   = (d['userName']     as String?) ?? 'Customer';
                final lastMsg    = (d['lastMessage']  as String?) ?? '';
                final lastTime   = (d['lastMessageTime'] as Timestamp?)?.toDate();
                final unread     = ((d['helperUnread'] ?? 0) as num).toInt();
                final bookingId  = (d['bookingId']    as String?) ?? '';
                final serviceName= (d['serviceName']  as String?) ?? '';

                return _ChatListTile(
                  chatId:      chatId,
                  bookingId:   bookingId,
                  userName:    userName,
                  lastMessage: lastMsg,
                  lastTime:    lastTime,
                  unreadCount: unread,
                  serviceName: serviceName,
                  isDark:      isDark,
                );
              },
            );
          },
        ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext ctx, bool isDark, bool hi) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 16,
        bottom: 18, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), Color(0xFF5B21B6), AppColors.brandPurple],
        ),
      ),
      child: Row(children: [
        const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Text(hi ? 'चैट' : 'Messages',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _empty(bool isDark, bool hi) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color:  AppColors.brandPurple.withOpacity(0.1),
              shape:  BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: AppColors.brandPurple, size: 38)),
      const SizedBox(height: 16),
      Text(hi ? 'कोई चैट नहीं' : 'No chats yet',
          style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(hi ? 'बुकिंग स्वीकार करने पर चैट शुरू होगी' : 'Accept a booking to start chatting',
          style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13)),
    ]));
  }
}

// ── Chat list tile ─────────────────────────────────────────────────────────────
class _ChatListTile extends StatelessWidget {
  final String chatId, bookingId, userName, lastMessage, serviceName;
  final DateTime? lastTime;
  final int  unreadCount;
  final bool isDark;
  const _ChatListTile({
    required this.chatId, required this.bookingId,
    required this.userName, required this.lastMessage,
    required this.lastTime, required this.unreadCount,
    required this.serviceName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId:    chatId,
          bookingId: bookingId,
          userName:  userName,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: unreadCount > 0
                  ? AppColors.brandPurple.withOpacity(0.25)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight)),
          boxShadow: [BoxShadow(
              color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Avatar
          Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color:        AppColors.brandPurple.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.brandPurple.withOpacity(0.2), width: 1.5)),
              child: Center(child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                      color: AppColors.brandPurple, fontSize: 20,
                      fontWeight: FontWeight.w700)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(userName, style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   15, fontWeight: FontWeight.w700))),
              if (lastTime != null)
                Text(_timeLabel(lastTime!), style: TextStyle(
                    color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                    fontSize: 11)),
            ]),
            if (serviceName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(serviceName, style: TextStyle(
                  color:    AppColors.cyanAccent,
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(
                  lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:      unreadCount > 0
                          ? (isDark ? Colors.white : AppColors.textDarkLight)
                          : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                      fontSize:   13,
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400))),
              if (unreadCount > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color:        AppColors.brandPurple,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$unreadCount', style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
          ])),
        ]),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours   < 24) return '${diff.inHours}h';
    if (diff.inDays    < 7)  return '${diff.inDays}d';
    return DateFormat('d MMM').format(dt);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAT ROOM SCREEN — Firebase Realtime Database messages
// ══════════════════════════════════════════════════════════════════════════════
class ChatRoomScreen extends StatefulWidget {
  final String chatId, bookingId, userName;
  const ChatRoomScreen({
    super.key, required this.chatId,
    required this.bookingId, required this.userName});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool  _isSending  = false;

  String get _uid  => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Realtime DB ref for messages
  DatabaseReference get _msgsRef =>
      FirebaseDatabase.instance.ref('chats/${widget.chatId}/messages');

  // Firestore ref for chat metadata
  DocumentReference get _chatDoc =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

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

  // Reset helper unread count when opening chat
  Future<void> _resetUnread() async {
    try {
      await _chatDoc.update({'helperUnread': 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _uid.isEmpty) return;

    setState(() => _isSending = true);
    _ctrl.clear();

    try {
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final key = _msgsRef.push().key!;

      // Write message to Realtime DB
      await _msgsRef.child(key).set({
        'text':      text,
        'senderId':  _uid,
        'senderRole': 'helper',
        'timestamp': ts,
        'read':      false,
      });

      // Update chat metadata in Firestore
      await _chatDoc.update({
        'lastMessage':     text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'userUnread':      FieldValue.increment(1),
      });

      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('send: $e');
    }
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hi     = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF2F3F8),
      body: Column(children: [
        _buildHeader(context, isDark),
        // ── Messages ──────────────────────────────────────────
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _msgsRef.orderByChild('timestamp').onValue,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    color: AppColors.brandPurple));
              }

              List<_Message> messages = [];
              if (snap.hasData && snap.data!.snapshot.value != null) {
                final raw = Map<String, dynamic>.from(
                    snap.data!.snapshot.value as Map);
                messages = raw.entries.map((e) {
                  final d = Map<String, dynamic>.from(e.value as Map);
                  return _Message(
                    key:      e.key,
                    text:     (d['text']       as String?) ?? '',
                    senderId: (d['senderId']   as String?) ?? '',
                    role:     (d['senderRole'] as String?) ?? 'user',
                    ts:       (d['timestamp']  as int?)    ?? 0,
                  );
                }).toList()..sort((a, b) => a.ts.compareTo(b.ts));

                // Mark user messages as read
                for (final m in messages) {
                  if (m.role == 'user' && !m.read) {
                    _msgsRef.child(m.key).update({'read': true});
                  }
                }
              }

              if (messages.isEmpty) return _emptyChat(isDark, hi);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller:  _scrollCtrl,
                padding:     const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount:   messages.length,
                itemBuilder: (_, i) {
                  final m      = messages[i];
                  final isMe   = m.senderId == _uid;
                  final isLast = i == messages.length - 1;
                  final showTime = isLast ||
                      messages[i + 1].ts - m.ts > 300000; // 5 min gap
                  return _MessageBubble(
                      message:  m, isMe: isMe,
                      isDark:   isDark,
                      showTime: showTime);
                },
              );
            },
          ),
        ),
        // ── Input bar ─────────────────────────────────────────
        _buildInputBar(isDark, hi),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 4, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), Color(0xFF5B21B6), AppColors.brandPurple],
        ),
      ),
      child: Row(children: [
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20)),
        Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color:  AppColors.cyanAccent.withOpacity(0.2),
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4))),
            child: Center(child: Text(
                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.userName, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          // Show booking status live
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings').doc(widget.bookingId).snapshots(),
            builder: (_, snap) {
              final s = (snap.data?.data() as Map<String, dynamic>?)?['status'] ?? '';
              return Text(_statusLabel(s), style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 11));
            },
          ),
        ])),
      ]),
    );
  }

  Widget _buildInputBar(bool isDark, bool hi) {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller:     _ctrl,
            minLines:       1, maxLines: 4,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
                color:    isDark ? Colors.white : AppColors.textDarkLight,
                fontSize: 14),
            decoration: InputDecoration(
              hintText:  hi ? 'संदेश लिखें...' : 'Type a message...',
              hintStyle: TextStyle(
                  color:    isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
                  fontSize: 14),
              border:        InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              filled:    true,
              fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF2F3F8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isSending ? null : _send,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color:        AppColors.brandPurple,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color:      AppColors.brandPurple.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))]),
              child: _isSending
                  ? const Padding(padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
        ),
      ]),
    );
  }

  Widget _emptyChat(bool isDark, bool hi) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.waving_hand_rounded,
          color: AppColors.cyanAccent, size: 40),
      const SizedBox(height: 14),
      Text(hi ? 'बातचीत शुरू करें' : 'Start the conversation',
          style: TextStyle(
              color:    isDark ? Colors.white : AppColors.textDarkLight,
              fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(hi ? 'ग्राहक को नमस्ते कहें!' : 'Say hello to the customer!',
          style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13)),
    ]));
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'accepted':    return 'Booking Accepted';
      case 'in_progress': return 'Job In Progress';
      case 'completed':   return 'Job Completed';
      default:            return 'Booking #${widget.bookingId.substring(0, 6)}';
    }
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _Message {
  final String key, text, senderId, role;
  final int    ts;
  final bool   read;
  const _Message({
    required this.key, required this.text, required this.senderId,
    required this.role, required this.ts, this.read = false});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final bool isMe, isDark, showTime;
  const _MessageBubble({
    required this.message, required this.isMe,
    required this.isDark, required this.showTime});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(message.ts);

    return Column(children: [
      Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          margin:  const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        isMe
                ? AppColors.brandPurple
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(18),
              topRight:    const Radius.circular(18),
              bottomLeft:  Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: isMe ? null : Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [BoxShadow(
                color: isDark ? Colors.transparent : Colors.black.withOpacity(0.05),
                blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Text(message.text, style: TextStyle(
              color:    isMe ? Colors.white
                  : (isDark ? Colors.white : AppColors.textDarkLight),
              fontSize: 14, height: 1.4)),
        ),
      ),
      if (showTime) Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
          child: Text(DateFormat('h:mm a').format(dt), style: TextStyle(
              color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
              fontSize: 10)),
        ),
      ),
    ]);
  }
}