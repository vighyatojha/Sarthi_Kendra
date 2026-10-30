// lib/core/booking_chat_screen.dart
// One chat per booking: chats/{bookingId}/messages in Firestore.
// Only the customer and helper on the booking can read or write. The chat is
// open only while the booking is active; after completion it is read-only and
// the two rate each other instead (firestore.rules enforces this). Each message sends a push to the other
// person through the notify Worker. IDENTICAL in both apps.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_unread.dart';
import 'job_api.dart';
import 'job_models.dart';
import 'review_sheet.dart';
import 'sarthi_ui.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  const ChatMessage(this.id, this.senderId, this.text, this.createdAt);
}

class BookingChatService {
  BookingChatService._();
  static final BookingChatService instance = BookingChatService._();
  final _db = FirebaseFirestore.instance;

  Stream<List<ChatMessage>> messages(String bookingId) => _db
      .collection('chats')
      .doc(bookingId)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((s) => s.docs
      .map((d) => ChatMessage(
    d.id,
    '${d.data()['senderId'] ?? ''}',
    '${d.data()['text'] ?? ''}',
    (d.data()['createdAt'] as Timestamp?)?.toDate(),
  ))
      .toList());

  Future<void> send({
    required String bookingId,
    required String text,
    required String senderName,
    required String role, // 'customer' | 'helper'
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chat = _db.collection('chats').doc(bookingId);
    await chat.collection('messages').add({
      'senderId': uid,
      'senderName': senderName.length > 80 ? senderName.substring(0, 80) : senderName,
      'senderRole': role,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await chat.update({
        'lastMessage': text.length > 120 ? '${text.substring(0, 120)}…' : text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
      });
      // Push to the other person (best effort; never blocks the chat).
      JobApi.instance.notifyChat(bookingId);
    } catch (_) {}
  }
}

class BookingChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherName;
  final String otherPhotoUrl;
  final String myName;
  final String myRole; // 'customer' | 'helper'
  final String subtitle;
  final Color accent;

  const BookingChatScreen({
    super.key,
    required this.bookingId,
    required this.otherName,
    required this.myName,
    required this.myRole,
    this.otherPhotoUrl = '',
    this.subtitle = '',
    this.accent = SarthiColors.purple,
  });

  /// The chat currently on screen (notifications for it are not shown).
  static String? openChatId;

  /// Opens a chat when only the booking id is known (e.g. from a notification).
  static Future<void> open(BuildContext context, {required String bookingId, required String myRole}) async {
    Booking? b;
    try {
      b = await JobApi.instance.booking(bookingId).first.timeout(const Duration(seconds: 12));
    } catch (_) {}
    if (!context.mounted) return;
    if (b == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This chat is not available.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final bk = b;
    final asHelper = myRole == 'helper';
    final me = FirebaseAuth.instance.currentUser?.displayName;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingChatScreen(
        bookingId: bk.id,
        otherName: asHelper ? bk.customerName : bk.helperName,
        otherPhotoUrl: asHelper ? '' : bk.helperPhotoUrl,
        myName: (me != null && me.isNotEmpty) ? me : (asHelper ? bk.helperName : bk.customerName),
        myRole: myRole,
        subtitle: bk.serviceName,
      ),
    ));
  }

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<List<ChatMessage>> _messages = BookingChatService.instance.messages(widget.bookingId);
  late final Stream<Booking?> _booking = JobApi.instance.booking(widget.bookingId);
  bool _sending = false;
  int _lastCount = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    BookingChatScreen.openChatId = widget.bookingId;
    WidgetsBinding.instance.addPostFrameCallback((_) => ChatUnread.instance.markRead(widget.bookingId));
  }

  @override
  void dispose() {
    if (BookingChatScreen.openChatId == widget.bookingId) BookingChatScreen.openChatId = null;
    ChatUnread.instance.markRead(widget.bookingId);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await BookingChatService.instance.send(
        bookingId: widget.bookingId,
        text: text.length > 2000 ? text.substring(0, 2000) : text,
        senderName: widget.myName,
        role: widget.myRole,
      );
      _ctrl.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Message not sent. The chat may be closed, or you are offline.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onMessages(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatUnread.instance.markRead(widget.bookingId);
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SarthiColors.page,
      appBar: _ChatAppBar(name: widget.otherName, photoUrl: widget.otherPhotoUrl, booking: _booking, fallback: widget.subtitle),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) {
                return const SarthiEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'This chat is not available',
                  message: 'Only the customer and the booked helper can open it.',
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: SarthiColors.purple, strokeWidth: 2));
              }
              final msgs = snap.data!;
              _onMessages(msgs.length);
              if (msgs.isEmpty) {
                return const SarthiEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Say hello 👋',
                  message: 'Share details about the work here.\nFor your safety, keep plans and payment talk in this chat.',
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m.senderId == _uid;
                  final showDay = i == 0 || !_sameDay(msgs[i - 1].createdAt, m.createdAt);
                  final groupedWithNext = i + 1 < msgs.length && msgs[i + 1].senderId == m.senderId &&
                      _sameDay(msgs[i + 1].createdAt, m.createdAt);
                  return Column(children: [
                    if (showDay) _DayChip(at: m.createdAt),
                    _Bubble(message: m, mine: mine, tail: !groupedWithNext),
                  ]);
                },
              );
            },
          ),
        ),
        StreamBuilder<Booking?>(
          stream: _booking,
          builder: (context, snap) {
            final b = snap.data;
            final open = b?.chatOpen ?? true;
            if (!open) {
              final completed = b?.status == BookingStatus.completed;
              final asCustomer = widget.myRole == 'customer';
              final reviewed = b == null ? true : (asCustomer ? b.customerReviewed : b.helperReviewed);
              final windowOpen = b?.completedAt == null ||
                  DateTime.now().isBefore(b!.completedAt!.add(reviewWindow));
              return SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.lock_outline_rounded, size: 16, color: SarthiColors.faint),
                      const SizedBox(width: 6),
                      Text(completed ? 'Job completed · chat closed' : 'Booking cancelled · chat closed',
                          style: const TextStyle(color: SarthiColors.muted, fontWeight: FontWeight.w600)),
                    ]),
                    if (completed && !reviewed && windowOpen) ...[
                      const SizedBox(height: 10),
                      SarthiButton(
                        label: 'Rate ${widget.otherName.split(' ').first}',
                        icon: Icons.star_rounded,
                        colors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                        onPressed: () => ReviewSheet.show(context, booking: b!, asCustomer: asCustomer),
                      ),
                    ],
                  ]),
                ),
              );
            }
            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -2))],
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Type a message',
                        hintStyle: const TextStyle(color: SarthiColors.faint),
                        filled: true,
                        fillColor: SarthiColors.page,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SarthiColors.accent),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String photoUrl;
  final Stream<Booking?> booking;
  final String fallback;
  const _ChatAppBar({required this.name, required this.photoUrl, required this.booking, required this.fallback});

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SarthiColors.header),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              splashRadius: 22,
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 1.5)),
              child: SarthiAvatar(name: name, photoUrl: photoUrl, size: 40),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<Booking?>(
                stream: booking,
                builder: (context, snap) {
                  final b = snap.data;
                  final sub = b == null
                      ? fallback
                      : '${b.serviceName} · ${b.status == BookingStatus.cancelled ? 'Cancelled' : bookingStatusLabel(b.status)}';
                  return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                  ]);
                },
              ),
            ),
            const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool tail;
  const _Bubble({required this.message, required this.mine, required this.tail});

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null ? 'sending…' : DateFormat('h:mm a').format(message.createdAt!);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(top: 2, bottom: tail ? 6 : 1),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 6),
        decoration: BoxDecoration(
          color: mine ? null : Colors.white,
          gradient: mine ? const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine || !tail ? 18 : 4),
            bottomRight: Radius.circular(!mine || !tail ? 18 : 4),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(message.text,
                style: TextStyle(color: mine ? Colors.white : SarthiColors.ink, fontSize: 14.5, height: 1.3)),
          ),
          const SizedBox(height: 3),
          Text(time, style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : SarthiColors.faint)),
        ]),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime? at;
  const _DayChip({required this.at});
  @override
  Widget build(BuildContext context) {
    if (at == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at!.year, at!.month, at!.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : DateFormat('d MMM yyyy').format(at!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: SarthiColors.purpleLight, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SarthiColors.purpleDark)),
      ),
    );
  }
}