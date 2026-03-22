// lib/screens/chat/helper_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/smooth_route.dart';
import 'helper_chat_room_screen.dart';

class HelperChatListScreen extends StatelessWidget {
  const HelperChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid    = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, isDark)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverToBoxAdapter(
            child: _ChatList(uid: uid, isDark: isDark),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 16,
        bottom: 20, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: const Row(children: [
        Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
        SizedBox(width: 12),
        Text('Messages', style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ChatList extends StatelessWidget {
  final String uid;
  final bool   isDark;
  const _ChatList({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _empty(isDark);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('helperId', isEqualTo: uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(
                color: AppColors.brandPurple)),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) return _empty(isDark);

        return Column(
          children: snap.data!.docs
              .map((doc) => _ChatTile(doc: doc, isDark: isDark, uid: uid))
              .toList(),
        );
      },
    );
  }

  Widget _empty(bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 80),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color:  AppColors.brandPurple.withOpacity(0.1),
          shape:  BoxShape.circle,
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            size: 34, color: AppColors.brandPurple),
      ),
      const SizedBox(height: 16),
      Text('No messages yet',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textDarkLight)),
      const SizedBox(height: 6),
      Text(
          'When users book your services, chats will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight)),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool   isDark;
  final String uid;
  const _ChatTile({
    required this.doc,
    required this.isDark,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final d        = doc.data() as Map<String, dynamic>;
    final userName = (d['userName']  ?? d['otherName'] ?? 'Customer') as String;
    final lastMsg  = (d['lastMessage'] ?? '') as String;
    final unread   = ((d['unreadCount_$uid'] ?? 0) as num).toInt();
    final isOnline = (d['userOnline'] ?? false) as bool;
    final photoUrl = (d['userPhoto']  ?? '') as String;
    final ts       = d['lastMessageTime'] as Timestamp?;
    final timeStr  = ts != null ? _fmtTime(ts.toDate()) : '';
    final userId   = (d['userId']     ?? '') as String;
    final service  = (d['serviceName'] ?? '') as String;
    final initial  = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        SmoothRoute(
          page: HelperChatRoomScreen(
            chatId:      doc.id,
            userId:      userId,
            userName:    userName,
            userPhoto:   photoUrl.isNotEmpty ? photoUrl : null,
            serviceName: service,
            bookingId:   d['bookingId'] as String?,
          ),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread > 0
                ? AppColors.brandPurple.withOpacity(0.3)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Row(children: [
          // Avatar + online dot
          Stack(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), AppColors.gradientEnd]),
                image: photoUrl.isNotEmpty
                    ? DecorationImage(
                    image: NetworkImage(photoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: photoUrl.isEmpty
                  ? Center(child: Text(initial,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 20)))
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: 1, bottom: 1,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color:  AppColors.onlineGreen,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          // Text info
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(userName, style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   15,
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
              ), overflow: TextOverflow.ellipsis)),
              Text(timeStr, style: TextStyle(
                fontSize: 11,
                color:    unread > 0
                    ? AppColors.brandPurple
                    : (isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              )),
            ]),
            if (service.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(service, style: const TextStyle(
                  color: AppColors.cyanAccent,
                  fontSize: 11, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(lastMsg, style: TextStyle(
                color:      isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize:   13,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
              ), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppColors.brandPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
          ])),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }
}