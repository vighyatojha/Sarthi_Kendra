// lib/screens/profile/helper_profile_screen.dart
// Full backend + bilingual EN/HI + real-time Firebase integration
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/helper_model.dart';
import '../../utils/smooth_route.dart';
import '../auth/helper_login_screen.dart';
import '../kyc/kyc_screen.dart';
import '../support/support_screen.dart';
import 'edit_profile_screen.dart';

class HelperProfileScreen extends StatefulWidget {
  const HelperProfileScreen({super.key});
  @override
  State<HelperProfileScreen> createState() => _HelperProfileScreenState();
}

class _HelperProfileScreenState extends State<HelperProfileScreen> {
  // ── Local prefs ─────────────────────────────────────────────────────────────
  bool _notifEnabled  = true;
  bool _soundEnabled  = true;
  bool _loadingNotif  = false;
  bool _loadingSound  = false;

  static const _kNotif = 'sarthi_notif_enabled';
  static const _kSound = 'sarthi_sound_enabled';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifEnabled = p.getBool(_kNotif) ?? true;
        _soundEnabled = p.getBool(_kSound) ?? true;
      });
    }
  }

  // ── Toggle push notifications ────────────────────────────────────────────
  Future<void> _toggleNotifications(bool val) async {
    setState(() => _loadingNotif = true);
    try {
      final uid = context.read<AuthProvider>().helper?.uid;
      if (val) {
        // Subscribe & save FCM token
        final token = await FirebaseMessaging.instance.getToken();
        if (uid != null && token != null) {
          await FirebaseFirestore.instance.collection('helpers').doc(uid).update({
            'fcmToken':     token,
            'notifEnabled': true,
          });
        }
        await FirebaseMessaging.instance.subscribeToTopic('helpers');
      } else {
        // Unsubscribe & clear token
        if (uid != null) {
          await FirebaseFirestore.instance.collection('helpers').doc(uid).update({
            'fcmToken':     FieldValue.delete(),
            'notifEnabled': false,
          });
        }
        await FirebaseMessaging.instance.unsubscribeFromTopic('helpers');
      }
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kNotif, val);
      if (mounted) setState(() => _notifEnabled = val);
    } catch (e) {
      debugPrint('notif toggle: $e');
    }
    if (mounted) setState(() => _loadingNotif = false);
  }

  // ── Toggle sound ─────────────────────────────────────────────────────────
  Future<void> _toggleSound(bool val) async {
    setState(() => _loadingSound = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSound, val);
    if (mounted) setState(() { _soundEnabled = val; _loadingSound = false; });
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang   = context.read<LanguageProvider>();
    final hi     = lang.isHindi;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Text(hi ? 'लॉगआउट' : 'Logout',
              style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
            hi ? 'क्या आप वाकई लॉगआउट करना चाहते हैं?'
                : 'Are you sure you want to log out?',
            style: TextStyle(
                color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(hi ? 'रद्द करें' : 'Cancel',
                  style: const TextStyle(color: AppColors.brandPurple))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor:  AppColors.danger,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(hi ? 'हाँ, लॉगआउट' : 'Yes, Logout',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Clear FCM token before logout
      final uid = context.read<AuthProvider>().helper?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('helpers').doc(uid)
              .update({'fcmToken': FieldValue.delete(), 'isOnline': false});
        } catch (_) {}
      }
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            SmoothRoute(page: const HelperLoginScreen()), (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final helper  = context.watch<AuthProvider>().helper;
    final lang    = context.watch<LanguageProvider>();
    final hi      = lang.isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF2F3F8),
      body: RefreshIndicator(
        color:       AppColors.brandPurple,
        onRefresh:   () => context.read<AuthProvider>().refreshProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(
              helper: helper, isDark: isDark, hi: hi,
              onEdit: () => Navigator.push(context,
                  SmoothRoute(page: const EditProfileScreen())).then((_) =>
                  context.read<AuthProvider>().refreshProfile()),
            )),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                // ── Live stats from Firestore ──────────────────
                _LiveStatsRow(uid: helper?.uid ?? '', isDark: isDark),
                const SizedBox(height: 24),

                // ── SECTION: App Settings ──────────────────────
                _SectionLabel(hi ? 'ऐप सेटिंग' : 'APP SETTINGS', isDark: isDark),
                const SizedBox(height: 10),
                _ThemeToggleTile(isDark: isDark, hi: hi),
                const SizedBox(height: 8),
                _LanguageToggleTile(isDark: isDark),
                const SizedBox(height: 8),
                _SwitchTile(
                  icon:     Icons.notifications_rounded,
                  color:    AppColors.brandPurple,
                  title:    hi ? 'पुश नोटिफिकेशन' : 'Push Notifications',
                  subtitle: hi ? 'नई बुकिंग की सूचना पाएं' : 'Get alerts for new bookings',
                  value:    _notifEnabled,
                  loading:  _loadingNotif,
                  isDark:   isDark,
                  onChanged: _toggleNotifications,
                ),
                const SizedBox(height: 8),
                _SwitchTile(
                  icon:     Icons.volume_up_rounded,
                  color:    AppColors.cyanAccent,
                  title:    hi ? 'साउंड अलर्ट' : 'Sound Alerts',
                  subtitle: hi ? 'बुकिंग पर बीप की आवाज़' : 'Beep on incoming bookings',
                  value:    _soundEnabled,
                  loading:  _loadingSound,
                  isDark:   isDark,
                  onChanged: _toggleSound,
                ),

                const SizedBox(height: 24),
                // ── SECTION: Account ──────────────────────────
                _SectionLabel(hi ? 'अकाउंट' : 'ACCOUNT', isDark: isDark),
                const SizedBox(height: 10),
                _NavTile(
                  icon:  Icons.manage_accounts_rounded,
                  color: AppColors.brandPurple,
                  title: hi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile',
                  isDark: isDark,
                  onTap: () => Navigator.push(context,
                      SmoothRoute(page: const EditProfileScreen())).then((_) =>
                      context.read<AuthProvider>().refreshProfile()),
                ),
                const SizedBox(height: 8),
                _KycNavTile(helper: helper, isDark: isDark, hi: hi),
                const SizedBox(height: 8),
                _NavTile(
                  icon:  Icons.account_balance_rounded,
                  color: AppColors.success,
                  title: hi ? 'बैंक विवरण' : 'Bank Details',
                  badge: hi ? 'जल्द आएगा' : 'Coming Soon',
                  isDark: isDark,
                  onTap: () => _snack(
                      hi ? 'बैंक विवरण जल्द आएगा' : 'Bank details coming soon'),
                ),

                const SizedBox(height: 24),
                // ── SECTION: Support ──────────────────────────
                _SectionLabel(hi ? 'सहायता' : 'SUPPORT', isDark: isDark),
                const SizedBox(height: 10),
                _NavTile(
                  icon:  Icons.headset_mic_rounded,
                  color: AppColors.warning,
                  title: hi ? 'सहायता और FAQ' : 'Help & Support',
                  isDark: isDark,
                  onTap: () => Navigator.push(context,
                      SmoothRoute(page: const SupportScreen())),
                ),
                const SizedBox(height: 8),
                _NavTile(
                  icon:  Icons.star_rounded,
                  color: AppColors.warning,
                  title: hi ? 'ऐप को रेट करें' : 'Rate the App',
                  isDark: isDark,
                  onTap: () => _snack(
                      hi ? 'Play Store की रेटिंग जल्द आएगी' : 'Play Store rating coming soon'),
                ),
                const SizedBox(height: 8),
                _NavTile(
                  icon:  Icons.privacy_tip_rounded,
                  color: AppColors.textMidDark,
                  title: hi ? 'गोपनीयता नीति' : 'Privacy Policy',
                  isDark: isDark,
                  onTap: () => _snack(hi ? 'जल्द आएगा' : 'Coming soon'),
                ),

                const SizedBox(height: 28),
                // ── Logout ────────────────────────────────────
                _LogoutButton(isDark: isDark, hi: hi, onTap: _logout),
                const SizedBox(height: 14),
                Center(child: Column(children: [
                  Text('Sarthi Kendra v1.0.0',
                      style: TextStyle(
                          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                          fontSize: 11)),
                  Text('© 2024 Trouble Sarthi Platform',
                      style: TextStyle(
                          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                          fontSize: 11)),
                ])),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColors.brandPurple,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER — gradient, avatar, name, stats
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final HelperModel? helper;
  final bool isDark, hi;
  final VoidCallback onEdit;
  const _Header({
    required this.helper, required this.isDark,
    required this.hi, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF0891B2)],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Text(hi ? 'मेरी प्रोफ़ाइल' : 'My Profile',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              // Edit button
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(hi ? 'संपादित करें' : 'Edit',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // Avatar
          Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.cyanAccent.withOpacity(0.3),
                    AppColors.brandPurple.withOpacity(0.4),
                  ],
                ),
                border: Border.all(
                    color: AppColors.cyanAccent.withOpacity(0.6), width: 2.5),
                boxShadow: [BoxShadow(
                    color: AppColors.cyanAccent.withOpacity(0.25),
                    blurRadius: 20, spreadRadius: 2)],
              ),
              child: Center(child: Text(helper?.initials ?? 'SK',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800))),
            ),
            // Online indicator
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: helper?.isOnline == true
                    ? AppColors.onlineGreen : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(
                    color: (helper?.isOnline == true
                        ? AppColors.onlineGreen : Colors.grey).withOpacity(0.5),
                    blurRadius: 8)],
              ),
            ),
          ]),

          const SizedBox(height: 14),

          Text(helper?.name ?? 'Sarthi Helper',
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),

          const SizedBox(height: 6),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        AppColors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
              ),
              child: Text(helper?.displayId ?? 'SK-0000',
                  style: const TextStyle(
                      color: AppColors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(helper?.status ?? 'pending').withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _statusColor(helper?.status ?? 'pending').withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color:  _statusColor(helper?.status ?? 'pending'),
                      shape:  BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(_statusLabel(helper?.status ?? 'pending', hi),
                    style: TextStyle(
                        color:      _statusColor(helper?.status ?? 'pending'),
                        fontSize:   11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),

          const SizedBox(height: 10),

          // Email + area
          if (helper?.email.isNotEmpty ?? false)
            Text(helper!.email,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),

          if (helper?.area.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.cyanAccent, size: 13),
              const SizedBox(width: 4),
              Text(helper!.area,
                  style: const TextStyle(
                      color: AppColors.cyanAccent, fontSize: 12)),
            ]),
          ],

          // Services chips
          if (helper?.services.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6, runSpacing: 6,
                children: helper!.services.take(4).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(s, style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                )).toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return AppColors.onlineGreen;
      case 'rejected': return AppColors.danger;
      case 'submitted': return AppColors.brandPurple;
      default:          return AppColors.warning;
    }
  }

  String _statusLabel(String s, bool hi) {
    switch (s) {
      case 'approved':  return hi ? 'स्वीकृत' : 'APPROVED';
      case 'rejected':  return hi ? 'अस्वीकृत' : 'REJECTED';
      case 'submitted': return hi ? 'समीक्षाधीन' : 'UNDER REVIEW';
      default:          return hi ? 'अपूर्ण' : 'PENDING KYC';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LIVE STATS ROW — real-time Firestore stream
// ══════════════════════════════════════════════════════════════════════════════
class _LiveStatsRow extends StatelessWidget {
  final String uid; final bool isDark;
  const _LiveStatsRow({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hi = context.watch<LanguageProvider>().isHindi;
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('helpers').doc(uid).snapshots(),
      builder: (context, snap) {
        final d          = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rating     = ((d['rating']    ?? 0.0) as num).toDouble();
        final totalJobs  = ((d['totalJobs'] ?? 0)   as num).toInt();
        final balance    = ((d['totalBalance'] ?? 0.0) as num).toDouble();

        return Row(children: [
          _StatCard(
              icon:   Icons.star_rounded,
              color:  AppColors.warning,
              value:  rating == 0 ? '—' : rating.toStringAsFixed(1),
              label:  hi ? 'रेटिंग' : 'Rating',
              isDark: isDark),
          const SizedBox(width: 10),
          _StatCard(
              icon:   Icons.check_circle_rounded,
              color:  AppColors.success,
              value:  '$totalJobs',
              label:  hi ? 'काम पूरे' : 'Jobs Done',
              isDark: isDark),
          const SizedBox(width: 10),
          _StatCard(
              icon:   Icons.wallet_rounded,
              color:  AppColors.brandPurple,
              value:  '₹${balance.toStringAsFixed(0)}',
              label:  hi ? 'बैलेंस' : 'Balance',
              isDark: isDark),
        ]);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String value, label; final bool isDark;
  const _StatCard({
    required this.icon, required this.color,
    required this.value, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
            color:      isDark ? Colors.white : AppColors.textDarkLight,
            fontSize:   16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(
            color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
            fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME TOGGLE TILE
// ══════════════════════════════════════════════════════════════════════════════
class _ThemeToggleTile extends StatelessWidget {
  final bool isDark, hi;
  const _ThemeToggleTile({required this.isDark, required this.hi});

  @override
  Widget build(BuildContext context) {
    final themeProvider  = context.watch<ThemeProvider>();
    final isCurrentlyDark = themeProvider.isDark;

    return _BaseTile(
      isDark: isDark,
      child: Row(children: [
        Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: (isCurrentlyDark ? AppColors.brandPurple : AppColors.warning)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
                isCurrentlyDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: isCurrentlyDark ? AppColors.brandPurple : AppColors.warning,
                size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hi ? 'ऐप थीम' : 'App Theme',
              style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(isCurrentlyDark
              ? (hi ? 'डार्क मोड' : 'Dark Mode')
              : (hi ? 'लाइट मोड' : 'Light Mode'),
              style: TextStyle(
                  color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                  fontSize: 12)),
        ])),
        // Animated toggle
        GestureDetector(
          onTap: themeProvider.toggleTheme,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 62, height: 34,
            decoration: BoxDecoration(
              color:        isCurrentlyDark
                  ? AppColors.gradientEnd : AppColors.warning.withOpacity(0.85),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(Icons.wb_sunny_rounded, size: 16,
                      color: !isCurrentlyDark ? Colors.white : Colors.white.withOpacity(0.3)),
                  Icon(Icons.nightlight_round, size: 16,
                      color: isCurrentlyDark ? Colors.white : Colors.white.withOpacity(0.3)),
                ]),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: isCurrentlyDark ? 31 : 3, top: 3,
                child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Icon(
                        isCurrentlyDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                        size: 16,
                        color: isCurrentlyDark ? AppColors.gradientEnd : AppColors.warning)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LANGUAGE TOGGLE TILE
// ══════════════════════════════════════════════════════════════════════════════
class _LanguageToggleTile extends StatelessWidget {
  final bool isDark;
  const _LanguageToggleTile({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final hi   = lang.isHindi;

    return _BaseTile(
      isDark: isDark,
      child: Row(children: [
        Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color:        AppColors.cyanAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.translate_rounded,
                color: AppColors.cyanAccent, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hi ? 'भाषा' : 'Language',
              style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(hi ? 'हिन्दी / English' : 'English / हिन्दी',
              style: TextStyle(
                  color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                  fontSize: 12)),
        ])),
        // EN / HI segmented control
        Container(
          decoration: BoxDecoration(
              color:        isDark ? AppColors.surfaceDark : const Color(0xFFF2F3F8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _LangChip(code: 'en', label: 'EN', selected: !hi, isDark: isDark,
                onTap: () => lang.setLanguage('en')),
            _LangChip(code: 'hi', label: 'हि', selected: hi, isDark: isDark,
                onTap: () => lang.setLanguage('hi')),
          ]),
        ),
      ]),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String code, label;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _LangChip({required this.code, required this.label,
    required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color:        selected ? AppColors.brandPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(
            color:      selected ? Colors.white
                : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
            fontSize:   13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// KYC NAV TILE — shows live status from Firestore
// ══════════════════════════════════════════════════════════════════════════════
class _KycNavTile extends StatelessWidget {
  final HelperModel? helper; final bool isDark, hi;
  const _KycNavTile({required this.helper, required this.isDark, required this.hi});

  @override
  Widget build(BuildContext context) {
    final uid     = helper?.uid ?? '';
    final status  = helper?.status ?? 'pending';
    Color  badgeColor;
    String badgeLabel;
    IconData badgeIcon;

    switch (status) {
      case 'approved':
        badgeColor = AppColors.success;
        badgeLabel = hi ? 'सत्यापित' : 'Verified';
        badgeIcon  = Icons.verified_rounded;
        break;
      case 'rejected':
        badgeColor = AppColors.danger;
        badgeLabel = hi ? 'अस्वीकृत' : 'Rejected';
        badgeIcon  = Icons.cancel_rounded;
        break;
      case 'submitted':
        badgeColor = AppColors.brandPurple;
        badgeLabel = hi ? 'समीक्षाधीन' : 'In Review';
        badgeIcon  = Icons.pending_rounded;
        break;
      default:
        badgeColor = AppColors.warning;
        badgeLabel = hi ? 'अपूर्ण' : 'Pending';
        badgeIcon  = Icons.warning_rounded;
    }

    return GestureDetector(
      onTap: status == 'approved' ? null
          : () => Navigator.push(context, SmoothRoute(page: const KycScreen())),
      child: _BaseTile(
        isDark: isDark,
        child: Row(children: [
          Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color:        badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.verified_user_rounded, color: badgeColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hi ? 'KYC स्थिति' : 'KYC Status',
                style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(hi ? 'पहचान सत्यापन' : 'Identity verification',
                style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color:        badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(badgeIcon, color: badgeColor, size: 12),
              const SizedBox(width: 4),
              Text(badgeLabel, style: TextStyle(
                  color:      badgeColor,
                  fontSize:   11, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (status != 'approved') ...[
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 13,
                color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _BaseTile extends StatelessWidget {
  final Widget child; final bool isDark;
  const _BaseTile({required this.child, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, subtitle;
  final bool value, loading, isDark;
  final void Function(bool) onChanged;
  const _SwitchTile({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
    required this.value, required this.loading,
    required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      isDark: isDark,
      child: Row(children: [
        Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 12)),
        ])),
        loading
            ? const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.brandPurple))
            : Switch(
          value:     value,
          onChanged: onChanged,
          activeColor: AppColors.brandPurple,
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon; final Color color;
  final String title; final bool isDark;
  final VoidCallback onTap; final String? badge;
  const _NavTile({
    required this.icon, required this.color,
    required this.title, required this.isDark,
    required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _BaseTile(
        isDark: isDark,
        child: Row(children: [
          Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   14, fontWeight: FontWeight.w600))),
          if (badge != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color:        AppColors.textSoftDark.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(badge!, style: TextStyle(
                  color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                  fontSize: 10, fontWeight: FontWeight.w600))),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 13,
              color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text; final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(children: [
        Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
                color: AppColors.brandPurple,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(
            color:      isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
            fontSize:   11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      ]),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool isDark, hi; final VoidCallback onTap;
  const _LogoutButton({required this.isDark, required this.hi, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        AppColors.danger.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Text(hi ? 'लॉगआउट' : 'Logout',
              style: const TextStyle(
                  color: AppColors.danger, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}