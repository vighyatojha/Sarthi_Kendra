// lib/screens/profile/helper_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/helper_model.dart';
import '../auth/helper_login_screen.dart';

class HelperProfileScreen extends StatelessWidget {
  const HelperProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final helper  = context.watch<AuthProvider>().helper;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildProfileHeader(context, helper, isDark),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats row
                _buildStatsRow(helper, isDark),
                const SizedBox(height: 20),

                // Settings section label
                _SectionLabel('App Settings', isDark: isDark),
                const SizedBox(height: 10),

                // ── THEME TOGGLE ─────────────────────────────────
                _buildThemeToggle(context, isDark),
                const SizedBox(height: 8),

                // Notifications
                _buildSettingTile(
                  icon:    Icons.notifications_outlined,
                  title:   'Push Notifications',
                  isDark:  isDark,
                  trailing: Switch(
                    value:    true,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 8),

                // Sound
                _buildSettingTile(
                  icon:    Icons.volume_up_outlined,
                  title:   'Sound Alerts',
                  isDark:  isDark,
                  trailing: Switch(
                    value:    true,
                    onChanged: (_) {},
                  ),
                ),

                const SizedBox(height: 20),
                _SectionLabel('Account', isDark: isDark),
                const SizedBox(height: 10),

                _buildNavTile(
                  icon:    Icons.person_outline_rounded,
                  title:   'Edit Profile',
                  isDark:  isDark,
                  onTap:   () {},
                ),
                const SizedBox(height: 8),
                _buildNavTile(
                  icon:    Icons.verified_user_outlined,
                  title:   'KYC Status',
                  isDark:  isDark,
                  trailing: _KycBadge(status: helper?.status ?? 'pending'),
                  onTap:   () {},
                ),
                const SizedBox(height: 8),
                _buildNavTile(
                  icon:    Icons.account_balance_outlined,
                  title:   'Bank Details',
                  isDark:  isDark,
                  onTap:   () {},
                ),

                const SizedBox(height: 20),
                _SectionLabel('Support', isDark: isDark),
                const SizedBox(height: 10),

                _buildNavTile(
                  icon:    Icons.help_outline_rounded,
                  title:   'Help & FAQ',
                  isDark:  isDark,
                  onTap:   () {},
                ),
                const SizedBox(height: 8),
                _buildNavTile(
                  icon:    Icons.headset_mic_outlined,
                  title:   '24/7 Support',
                  isDark:  isDark,
                  onTap:   () {},
                ),
                const SizedBox(height: 8),
                _buildNavTile(
                  icon:    Icons.star_outline_rounded,
                  title:   'Rate the App',
                  isDark:  isDark,
                  onTap:   () {},
                ),

                const SizedBox(height: 24),

                // Logout button
                _buildLogoutButton(context, isDark),

                const SizedBox(height: 12),

                // App version
                Center(
                  child: Text(
                    'Sarthi Kendra v1.0.0 • APNA SARTHI, APNA ROZGAR',
                    style: TextStyle(
                      color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                      fontSize: 11,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, HelperModel? helper, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 20,
        bottom: 24,
        left:   20,
        right:  20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width:  84,
                height: 84,
                decoration: BoxDecoration(
                  color:  AppColors.cyanAccent.withOpacity(0.2),
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cyanAccent.withOpacity(0.5),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    helper?.initials ?? 'SK',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Container(
                width:  26,
                height: 26,
                decoration: BoxDecoration(
                  color:  AppColors.brandPurple,
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size:  13,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            helper?.name ?? 'Sarthi Helper',
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                helper?.displayId ?? 'SK-0000',
                style: TextStyle(color: AppColors.cyanAccent, fontSize: 13),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
              ),
              Text(
                helper?.email ?? '',
                style: TextStyle(
                  color:    Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Services chips
          if (helper?.services.isNotEmpty ?? false)
            Wrap(
              alignment: WrapAlignment.center,
              spacing:   6,
              runSpacing: 6,
              children: helper!.services.take(3).map((svc) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  svc,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(HelperModel? helper, bool isDark) {
    final stats = [
      (
      Icons.star_rounded,
      AppColors.warning,
      (helper?.rating ?? 0.0).toStringAsFixed(1),
      'Rating',
      ),
      (
      Icons.work_history_rounded,
      AppColors.brandPurple,
      '${helper?.totalJobs ?? 0}',
      'Total Jobs',
      ),
      (
      Icons.location_on_rounded,
      AppColors.cyanAccent,
      helper?.area ?? 'N/A',
      'Service Area',
      ),
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final (icon, color, value, label) = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left:  entry.key > 0 ? 8 : 0,
              right: entry.key < stats.length - 1 ? 0 : 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── THEME TOGGLE TILE ────────────────────────────────────────────────────
  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    final themeProvider = context.watch<ThemeProvider>();
    final isCurrentlyDark = themeProvider.isDark;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        (isCurrentlyDark
                    ? AppColors.brandPurple
                    : AppColors.warning)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCurrentlyDark
                    ? Icons.nightlight_round   // Moon icon for dark mode
                    : Icons.wb_sunny_rounded,  // Sun icon for light mode
                color: isCurrentlyDark ? AppColors.brandPurple : AppColors.warning,
                size:  20,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Theme',
                    style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCurrentlyDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // ── Sun / Moon animated toggle ────────────────────
            GestureDetector(
              onTap: () => themeProvider.toggleTheme(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width:    60,
                height:   32,
                decoration: BoxDecoration(
                  color:        isCurrentlyDark
                      ? AppColors.gradientEnd
                      : AppColors.warning.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Track icons (sun left, moon right)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            size:  16,
                            color: isCurrentlyDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white,
                          ),
                          Icon(
                            Icons.nightlight_round,
                            size:  16,
                            color: isCurrentlyDark
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),

                    // Thumb
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve:    Curves.easeInOut,
                      left:     isCurrentlyDark ? 30 : 2,
                      top:      2,
                      child: Container(
                        width:  28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:  Colors.white,
                          shape:  BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:       Colors.black.withOpacity(0.2),
                              blurRadius:  4,
                              offset:      const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isCurrentlyDark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          size:  16,
                          color: isCurrentlyDark
                              ? AppColors.gradientEnd
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String   title,
    required bool     isDark,
    required Widget   trailing,
    String?           subtitle,
  }) {
    return Container(
      padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:  BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color:        AppColors.brandPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.brandPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData  icon,
    required String    title,
    required bool      isDark,
    required VoidCallback onTap,
    Widget?            trailing,
    String?            subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:  BoxDecoration(
          color:        isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        AppColors.brandPurple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.brandPurple, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size:  14,
                  color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title:   Text(
              'Logout',
              style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:     const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:     ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          await context.read<AuthProvider>().logout();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HelperLoginScreen()),
                  (_) => false,
            );
          }
        }
      },
      child: Container(
        padding:     const EdgeInsets.symmetric(vertical: 16),
        decoration:  BoxDecoration(
          color:        AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: AppColors.danger.withOpacity(0.3),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                color:      AppColors.danger,
                fontSize:   15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KYC badge ────────────────────────────────────────────────────────────────
class _KycBadge extends StatelessWidget {
  final String status;
  const _KycBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color  color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        color = AppColors.success;
        label = 'Verified';
        icon  = Icons.verified_rounded;
        break;
      case 'rejected':
        color = AppColors.danger;
        label = 'Rejected';
        icon  = Icons.cancel_rounded;
        break;
      default:
        color = AppColors.warning;
        label = 'Pending';
        icon  = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool   isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color:      isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
        fontSize:   11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}