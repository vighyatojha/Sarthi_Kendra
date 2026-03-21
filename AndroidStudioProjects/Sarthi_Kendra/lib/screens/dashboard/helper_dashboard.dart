// lib/screens/dashboard/helper_dashboard.dart
// Updated: smooth transitions everywhere + notification bell + real data
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/helper_model.dart';
import '../../utils/smooth_route.dart';
import '../kyc/kyc_screen.dart';
import '../bookings/incoming_booking_detail.dart';
import '../earning/earnings_screen.dart';
import '../profile/helper_profile_screen.dart';
import '../chat/helper_chat_screen.dart';
import '../notifications/notifications_screen.dart';
import '../trust/trust_safety_screen.dart';

class HelperDashboard extends StatefulWidget {
  const HelperDashboard({super.key});
  @override
  State<HelperDashboard> createState() => _HelperDashboardState();
}

class _HelperDashboardState extends State<HelperDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late final AnimationController _tabAnim;
  late final Animation<double>   _tabFade;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 200));
    _tabFade = CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut);
    _tabAnim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  void dispose() { _tabAnim.dispose(); super.dispose(); }

  void _switchTab(int i) {
    if (_selectedTab == i) return;
    _tabAnim.reset();
    setState(() => _selectedTab = i);
    _tabAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // ── Status gates ─────────────────────────────────────────────
    if (helper != null) {
      if (helper.isPending)   return _PendingKycScreen(helper: helper);
      if (helper.isSubmitted) return _UnderReviewScreen(helper: helper);
      if (helper.isRejected)  return _RejectedScreen(helper: helper);
      if (helper.isInactive)  return _InactiveScreen(helper: helper);
    }

    // ── Full dashboard ────────────────────────────────────────────
    final pages = [
      const _DashboardHome(),
      const HelperChatListScreen(),
      const EarningsScreen(),
      const TrustSafetyScreen(),
      const HelperProfileScreen(),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: _tabFade,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        selected:  _selectedTab,
        onSelect:  _switchTab,
        isDark:    isDark,
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int    selected;
  final void Function(int) onSelect;
  final bool   isDark;
  const _BottomNav({required this.selected, required this.onSelect,
    required this.isDark});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded,           Icons.home_outlined,               'HOME'),
      (Icons.chat_bubble_rounded,    Icons.chat_bubble_outline_rounded, 'CHATS'),
      (Icons.wallet_rounded,         Icons.wallet_outlined,             'EARNINGS'),
      (Icons.shield_rounded,         Icons.shield_outlined,             'TRUST'),
      (Icons.person_rounded,         Icons.person_outline_rounded,      'PROFILE'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.asMap().entries.map((e) {
            final i                          = e.key;
            final (activeIcon, inactiveIcon, label) = e.value;
            final isSelected                 = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPurple.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isSelected ? activeIcon : inactiveIcon,
                    size:  24,
                    color: isSelected
                        ? AppColors.brandPurple
                        : (isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
                  ),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(
                    fontSize:      9,
                    fontWeight:    isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:         isSelected
                        ? AppColors.brandPurple
                        : (isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
                    letterSpacing: 0.5,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),
      )),
    );
  }
}

// ── Status screens ────────────────────────────────────────────────────────────
class _PendingKycScreen extends StatelessWidget {
  final HelperModel helper;
  const _PendingKycScreen({required this.helper});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          _StatusHeader(helper: helper, isDark: isDark,
              color: AppColors.warning, text: 'Action Required'),
          const Spacer(),
          _StatusIcon(color: AppColors.warning, icon: Icons.upload_file_rounded),
          const SizedBox(height: 24),
          _StatusTitle('Complete Your KYC', isDark: isDark),
          const SizedBox(height: 12),
          _StatusBody(
            'Upload your Aadhaar & PAN to get verified. '
                'You cannot receive bookings until admin approves.',
            isDark: isDark,
          ),
          const SizedBox(height: 32),
          _StepsCard(isDark: isDark, steps: const [
            ('Registration Complete', true),
            ('Upload Aadhaar & PAN',  false),
            ('Admin Approval',        false),
            ('Go Live & Earn',        false),
          ]),
          const Spacer(),
          _PrimaryBtn(label: 'Upload KYC Documents',
              icon: Icons.upload_rounded,
              onTap: () => Navigator.push(context,
                  SmoothRoute(page: const KycScreen()))),
          const SizedBox(height: 12),
          const _LogoutBtn(),
        ]),
      )),
    );
  }
}

class _UnderReviewScreen extends StatefulWidget {
  final HelperModel helper;
  const _UnderReviewScreen({required this.helper});
  @override
  State<_UnderReviewScreen> createState() => _UnderReviewState();
}
class _UnderReviewState extends State<_UnderReviewScreen> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<AuthProvider>().refreshProfile();
    });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          _StatusHeader(helper: widget.helper, isDark: isDark,
              color: AppColors.brandPurple, text: 'Under Review'),
          const Spacer(),
          _StatusIcon(color: AppColors.brandPurple, icon: Icons.manage_search_rounded),
          const SizedBox(height: 24),
          _StatusTitle('Documents Under Review', isDark: isDark),
          const SizedBox(height: 12),
          _StatusBody('Your KYC is submitted. Admin will review within 24 hours.',
              isDark: isDark),
          const SizedBox(height: 32),
          _StepsCard(isDark: isDark, steps: const [
            ('Registration Complete',  true),
            ('KYC Documents Uploaded', true),
            ('Admin Approval',         false),
            ('Go Live & Earn',         false),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppColors.cyanAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyanAccent.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.sync_rounded, size: 16, color: AppColors.cyanAccent),
              const SizedBox(width: 8),
              Text('Auto-checking every 30 sec', style: TextStyle(
                color:    isDark ? AppColors.cyanAccent : AppColors.gradientEnd,
                fontSize: 12,
              )),
            ]),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().refreshProfile(),
            icon:  const Icon(Icons.refresh_rounded),
            label: const Text('Check Status Now'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
              foregroundColor: AppColors.brandPurple,
              side: const BorderSide(color: AppColors.brandPurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          const _LogoutBtn(),
        ]),
      )),
    );
  }
}

class _RejectedScreen extends StatelessWidget {
  final HelperModel helper;
  const _RejectedScreen({required this.helper});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          _StatusHeader(helper: helper, isDark: isDark,
              color: AppColors.danger, text: 'KYC Rejected'),
          const Spacer(),
          _StatusIcon(color: AppColors.danger, icon: Icons.cancel_rounded),
          const SizedBox(height: 24),
          _StatusTitle('KYC Rejected', isDark: isDark),
          const SizedBox(height: 12),
          if (helper.kycRejectedReason != null) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reason from Admin:', style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Text(helper.kycRejectedReason!, style: TextStyle(
                  color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                  fontSize: 13, height: 1.5,
                )),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          _StatusBody('Please re-upload clear, valid documents.', isDark: isDark),
          const Spacer(),
          _PrimaryBtn(label: 'Re-upload Documents',
              icon: Icons.upload_rounded, color: AppColors.danger,
              onTap: () => Navigator.push(context,
                  SmoothRoute(page: const KycScreen()))),
          const SizedBox(height: 12),
          const _LogoutBtn(),
        ]),
      )),
    );
  }
}

class _InactiveScreen extends StatelessWidget {
  final HelperModel helper;
  const _InactiveScreen({required this.helper});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          _StatusHeader(helper: helper, isDark: isDark,
              color: AppColors.textMidDark, text: 'Account Deactivated'),
          const Spacer(),
          _StatusIcon(color: AppColors.textMidDark, icon: Icons.block_rounded),
          const SizedBox(height: 24),
          _StatusTitle('Account Deactivated', isDark: isDark),
          const SizedBox(height: 12),
          _StatusBody('Your account has been deactivated. '
              'Contact support for assistance.', isDark: isDark),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: const Row(children: [
              Icon(Icons.support_agent_rounded,
                  color: AppColors.brandPurple, size: 24),
              SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contact Support',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('support@sarthikendra.in',
                    style: TextStyle(color: AppColors.brandPurple, fontSize: 13)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          const _LogoutBtn(),
        ]),
      )),
    );
  }
}

// ── Shared status widgets ─────────────────────────────────────────────────────
class _StatusHeader extends StatelessWidget {
  final HelperModel helper; final bool isDark;
  final Color color; final String text;
  const _StatusHeader({required this.helper, required this.isDark,
    required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 46, height: 46,
        decoration: BoxDecoration(color: color.withOpacity(0.15),
            shape: BoxShape.circle),
        child: Center(child: Text(helper.initials, style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.w700)))),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(helper.name, style: TextStyle(
          color: isDark ? Colors.white : AppColors.textDarkLight,
          fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(text, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ])),
  ]);
}

class _StatusIcon extends StatelessWidget {
  final Color color; final IconData icon;
  const _StatusIcon({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 110, height: 110,
    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 2)),
    child: Icon(icon, size: 50, color: color),
  );
}

class _StatusTitle extends StatelessWidget {
  final String text; final bool isDark;
  const _StatusTitle(this.text, {required this.isDark});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: isDark ? Colors.white : AppColors.textDarkLight,
      fontSize: 22, fontWeight: FontWeight.w800));
}

class _StatusBody extends StatelessWidget {
  final String text; final bool isDark;
  const _StatusBody(this.text, {required this.isDark});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center,
      style: TextStyle(
          color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
          fontSize: 14, height: 1.6));
}

class _PrimaryBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final Color? color;
  const _PrimaryBtn({required this.label, required this.icon,
    required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon:  Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _LogoutBtn extends StatelessWidget {
  const _LogoutBtn();
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => context.read<AuthProvider>().logout(),
    icon:  const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
    label: const Text('Logout',
        style: TextStyle(color: AppColors.danger, fontSize: 13)),
  );
}

class _StepsCard extends StatelessWidget {
  final bool isDark; final List<(String, bool)> steps;
  const _StepsCard({required this.isDark, required this.steps});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Column(children: steps.asMap().entries.map((e) {
      final (label, done) = e.value;
      final isLast = e.key == steps.length - 1;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color:  done ? AppColors.success : Colors.transparent,
              shape:  BoxShape.circle,
              border: Border.all(
                color: done ? AppColors.success
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: 2,
              ),
            ),
            child: Center(child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    shape: BoxShape.circle))),
          ),
          if (!isLast) Container(width: 2, height: 28,
              color: done ? AppColors.success.withOpacity(0.3)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight)),
        ]),
        const SizedBox(width: 14),
        Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(label, style: TextStyle(
              color:      done ? AppColors.success
                  : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
              fontSize:   13,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ))),
      ]);
    }).toList()),
  );
}

// ── HOME tab ──────────────────────────────────────────────────────────────────
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final uid     = helper?.uid ?? '';

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _Header(helper: helper, isDark: isDark)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(delegate: SliverChildListDelegate([
          const SizedBox(height: 16),
          _OnlineToggle(helper: helper, isDark: isDark),
          const SizedBox(height: 16),
          _TodayCard(uid: uid, isDark: isDark),
          const SizedBox(height: 20),
          _SectionHeader('New Requests', isDark),
          const SizedBox(height: 12),
          _RequestsList(uid: uid, isDark: isDark),
          const SizedBox(height: 20),
          _SectionHeader('Recent Activity', isDark),
          const SizedBox(height: 12),
          _ActivityList(uid: uid, isDark: isDark),
          const SizedBox(height: 100),
        ])),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  final HelperModel? helper;
  final bool         isDark;
  const _Header({required this.helper, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color:  AppColors.cyanAccent.withOpacity(0.2),
            shape:  BoxShape.circle,
            border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5), width: 2),
          ),
          child: Center(child: Text(helper?.initials ?? 'SK',
              style: const TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(helper?.name ?? 'Sarthi Helper',
              style: const TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(children: [
            Text(helper?.displayId ?? 'SK-0000',
                style: TextStyle(color: AppColors.cyanAccent, fontSize: 12)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('•', style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        (helper?.isOnline == true
                    ? AppColors.onlineGreen : Colors.grey).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                helper?.isOnline == true ? 'Online' : 'Offline',
                style: TextStyle(
                  color:      helper?.isOnline == true
                      ? AppColors.onlineGreen : Colors.white60,
                  fontSize: 10, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ])),
        // Bell icon with dot
        const NotificationBell(isDark: false),
      ]),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final HelperModel? helper; final bool isDark;
  const _OnlineToggle({required this.helper, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SERVICE STATUS', style: TextStyle(
          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
        )),
        const SizedBox(height: 4),
        Text(helper?.isOnline == true ? 'Currently Online' : 'Currently Offline',
            style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w700,
            )),
      ]),
      const Spacer(),
      Transform.scale(scale: 1.2, child: Switch(
        value:     helper?.isOnline ?? false,
        onChanged: (_) => context.read<AuthProvider>().toggleOnlineStatus(),
      )),
    ]),
  );
}

class _TodayCard extends StatelessWidget {
  final String uid; final bool isDark;
  const _TodayCard({required this.uid, required this.isDark});
  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    final now  = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status',   isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .snapshots(),
      builder: (context, snap) {
        double total = 0; int jobs = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m = d.data() as Map<String, dynamic>;
            total += ((m['amount'] ?? 0) as num).toDouble();
            jobs++;
          }
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Today's Earnings", style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13,
              )),
              const SizedBox(height: 8),
              Text('₹ ${total.toStringAsFixed(2)}', style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   28, fontWeight: FontWeight.w800,
              )),
              if (jobs > 0) ...[
                const SizedBox(height: 4),
                Text('$jobs job${jobs > 1 ? 's' : ''} completed',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ])),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color:        AppColors.brandPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.wallet_rounded,
                  color: AppColors.brandPurple, size: 24),
            ),
          ]),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final bool isDark;
  const _SectionHeader(this.title, this.isDark);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: TextStyle(
      color:      isDark ? Colors.white : AppColors.textDarkLight,
      fontSize:   18, fontWeight: FontWeight.w700,
    )),
    const SizedBox(width: 8),
    Container(width: 8, height: 8,
        decoration: const BoxDecoration(
            color: AppColors.brandPurple, shape: BoxShape.circle)),
  ]);
}

class _RequestsList extends StatelessWidget {
  final String uid; final bool isDark;
  const _RequestsList({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _empty();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return _empty();
        return Column(children: snap.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _ReqCard(
            bookingId:   doc.id,
            userName:    d['userName']    ?? 'Customer',
            serviceName: d['serviceName'] ?? 'Service',
            amount:      ((d['amount']    ?? 0) as num).toDouble(),
            createdAt:   (d['createdAt']  as Timestamp?)?.toDate(),
            isDark:      isDark,
          );
        }).toList());
      },
    );
  }

  Widget _empty() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Column(children: [
      Icon(Icons.inbox_rounded, size: 40,
          color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
      const SizedBox(height: 12),
      Text('No new requests right now', style: TextStyle(
          color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
          fontSize: 14)),
    ]),
  );
}

class _ReqCard extends StatelessWidget {
  final String bookingId, userName, serviceName;
  final double    amount;
  final DateTime? createdAt;
  final bool      isDark;
  const _ReqCard({required this.bookingId, required this.userName,
    required this.serviceName, required this.amount,
    required this.createdAt, required this.isDark});

  String get _ago {
    if (createdAt == null) return 'just now';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Column(children: [
      Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color:        AppColors.gradientEnd.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_rounded,
              color: AppColors.cyanAccent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(userName, style: TextStyle(
            color:      isDark ? Colors.white : AppColors.textDarkLight,
            fontSize:   15, fontWeight: FontWeight.w700,
          )),
          Text('$serviceName  •  ₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 12,
              )),
        ])),
        Text(_ago, style: TextStyle(
            color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
            fontSize: 11)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: () => _accept(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Accept', style: TextStyle(fontSize: 13)),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(
          onPressed: _decline,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            foregroundColor:
            isDark ? AppColors.textMidDark : AppColors.textMidLight,
          ),
          child: const Text('Decline', style: TextStyle(fontSize: 13)),
        )),
      ]),
    ]),
  );

  Future<void> _accept(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'status':     'accepted',
      'helperId':   auth.helper?.uid,
      'helperName': auth.helper?.name,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      Navigator.push(context, SmoothRoute(
          page: IncomingBookingDetail(bookingId: bookingId)));
    }
  }

  Future<void> _decline() async {
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'status': 'declined', 'declinedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _ActivityList extends StatelessWidget {
  final String uid; final bool isDark;
  const _ActivityList({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Center(child: Text('No activity yet', style: TextStyle(
                color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 14))),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color:        isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(children: snap.data!.docs.asMap().entries.map((e) {
            final doc    = e.value;
            final d      = doc.data() as Map<String, dynamic>;
            final status = (d['status'] ?? 'pending') as String;
            final svc    = (d['serviceName'] ?? 'Service') as String;
            final amount = ((d['amount'] ?? 0) as num).toDouble();
            final ts     = (d['createdAt'] as Timestamp?)?.toDate();
            final isLast = e.key == snap.data!.docs.length - 1;

            final (icon, color) = _icon(status);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(svc, style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDarkLight,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(status.toUpperCase(), style: TextStyle(
                        color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                        fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      status == 'completed'
                          ? '+₹${amount.toStringAsFixed(0)}'
                          : '₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color:      status == 'completed' ? AppColors.success
                            : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                        fontSize:   14, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (ts != null)
                      Text(_ago(ts), style: TextStyle(
                          color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                          fontSize: 10)),
                  ]),
                ]),
              ),
              if (!isLast) Divider(height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  indent: 16, endIndent: 16),
            ]);
          }).toList()),
        );
      },
    );
  }

  (IconData, Color) _icon(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return (Icons.check_circle_rounded, AppColors.success);
      case 'accepted':  return (Icons.handshake_rounded,    AppColors.brandPurple);
      case 'pending':   return (Icons.pending_rounded,      AppColors.warning);
      default:          return (Icons.cancel_rounded,       AppColors.danger);
    }
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}