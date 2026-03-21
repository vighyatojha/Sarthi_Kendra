// lib/screens/chat/helper_chat_room_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/realtime_db_service.dart';
import '../../theme/app_theme.dart';

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

  String get _uid    => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _myName => FirebaseAuth.instance.currentUser?.displayName ?? 'Helper';

  @override
  void dispose() {
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
    );

    // Update Firestore chat metadata so the user's list refreshes
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage':                    text,
      'lastMessageTime':                FieldValue.serverTimestamp(),
      'unreadCount_${widget.userId}':   FieldValue.increment(1),
    }).catchError((_) {});

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOut,
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
            'Confirm "${widget.serviceName ?? 'the service'}" is done?',
            style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Done',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && widget.bookingId != null && mounted) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:         Text('Seva marked as completed!'),
          backgroundColor: AppColors.success,
          behavior:        SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final initial = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase() : 'U';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF4F6FB),
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────
        _buildHeader(isDark, initial),

        // ── Messages ───────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: RealtimeDbService.instance.messagesStream(widget.chatId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    color: AppColors.brandPurple, strokeWidth: 2));
              }
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return _EmptyChat(name: widget.userName);
              }
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller:  _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount:   messages.length,
                itemBuilder: (_, i) {
                  final msg  = messages[i];
                  final isMe = msg['senderId'] == _uid;
                  final ts   = (msg['timestamp'] as int?) ?? 0;
                  final showDate = i == 0 || _diffDay(
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

        // ── Input bar ──────────────────────────────────────────────
        _buildInputBar(isDark),
      ]),
    );
  }

  Widget _buildHeader(bool isDark, String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 14),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
            ),
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), AppColors.gradientEnd]),
                image: widget.userPhoto != null
                    ? DecorationImage(
                    image: NetworkImage(widget.userPhoto!),
                    fit:   BoxFit.cover)
                    : null,
              ),
              child: widget.userPhoto == null
                  ? Center(child: Text(initial,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 17)))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.userName,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (widget.serviceName != null)
                Text(widget.serviceName!,
                    style: const TextStyle(
                        color: Color(0xFFB2E8E8), fontSize: 11)),
            ])),
            // Seva done button
            GestureDetector(
              onTap: _confirmSevaDone,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color:        AppColors.success,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color:      AppColors.success.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Seva Done', style: TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, -3),
        )],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.surfaceDark
                  : const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines:   null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  color:    isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize: 14),
              decoration: const InputDecoration(
                hintText:       'Type a message...',
                hintStyle:      TextStyle(
                    color: Color(0xFFADB5BD), fontSize: 14),
                border:         InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isSending ? null : _send,
          child: Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brandPurple, AppColors.gradientEnd],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? const Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  bool _diffDay(int ts1, int ts2) {
    final a = DateTime.fromMillisecondsSinceEpoch(ts1);
    final b = DateTime.fromMillisecondsSinceEpoch(ts2);
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final String text, senderName;
  final bool   isMe;
  final int    timestamp;
  const _Bubble({required this.text, required this.isMe,
    required this.senderName, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time   = timestamp > 0
        ? _fmt(DateTime.fromMillisecondsSinceEpoch(timestamp)) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF06B6D4), AppColors.gradientEnd]),
              ),
              child: Center(child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold),
              )),
            ),
          ],
          Flexible(child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                      colors: [AppColors.brandPurple, AppColors.gradientEnd],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight)
                      : null,
                  color: isMe ? null
                      : (isDark ? AppColors.cardDark : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4  : 18),
                  ),
                  boxShadow: [BoxShadow(
                    color:      Colors.black.withOpacity(0.06),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )],
                ),
                child: Text(text, style: TextStyle(
                  color: isMe ? Colors.white
                      : (isDark ? Colors.white : AppColors.textDarkLight),
                  fontSize: 14, height: 1.4,
                )),
              ),
              const SizedBox(height: 3),
              Text(time, style: const TextStyle(
                  fontSize: 10, color: Color(0xFF9CA3AF))),
            ],
          )),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = (dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour));
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Date separator ────────────────────────────────────────────────────────────
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
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      label = '${dt.day} ${m[dt.month - 1]}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:        const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500)),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      ]),
    );
  }
}

// ── Empty chat ────────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final String name;
  const _EmptyChat({required this.name});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color:  AppColors.brandPurple.withOpacity(0.1),
            shape:  BoxShape.circle,
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 32, color: AppColors.brandPurple),
        ),
        const SizedBox(height: 16),
        Text('Chat with $name',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        const Text('Your conversation will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    ),
  );
}