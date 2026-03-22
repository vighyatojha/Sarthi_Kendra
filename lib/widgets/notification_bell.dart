// lib/widgets/notification_bell.dart
// Reusable bell widget that reads unread count from Realtime DB
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';
import '../utils/smooth_route.dart';

class NotificationBell extends StatelessWidget {
  final bool isDark;
  const NotificationBell({super.key, required this.isDark});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) return const SizedBox(width: 44);

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('notifications/$_uid')
          .orderByChild('read')
          .equalTo(false)
          .onValue,
      builder: (context, snap) {
        int unread = 0;
        if (snap.hasData && snap.data!.snapshot.value != null) {
          final data = snap.data!.snapshot.value as Map?;
          unread = data?.length ?? 0;
        }

        return GestureDetector(
          onTap: () => Navigator.push(context,
              SmoothRoute(page: const NotificationsScreen())),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white, size: 20),
              ),
              if (unread > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                        minWidth: 18, minHeight: 18),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}