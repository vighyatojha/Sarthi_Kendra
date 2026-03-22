// lib/screens/earnings/earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _selectedPeriod = 0; // 0 = Weekly, 1 = Monthly

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final helperId  = context.watch<AuthProvider>().helper?.uid ?? ''; // ← fixed: uid not id

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAppBar(context, isDark)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildBalanceCard(helperId, isDark),
                const SizedBox(height: 16),
                _buildPeriodSelector(isDark),
                const SizedBox(height: 16),
                _buildAnalyticsCard(isDark),
                const SizedBox(height: 20),
                _buildSectionHeader('Recent Activity', isDark),
                const SizedBox(height: 12),
                _buildActivityList(isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        bottom: 14, left: 8, right: 16,
      ),
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textDarkLight, size: 20),
        ),
        Expanded(child: Text('Earnings & Analytics', style: TextStyle(
          color:      isDark ? Colors.white : AppColors.textDarkLight,
          fontSize:   18, fontWeight: FontWeight.w700,
        ))),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.help_outline_rounded,
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight),
        ),
      ]),
    );
  }

  Widget _buildBalanceCard(String helperId, bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: helperId.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('helpers')
          .doc(helperId)
          .snapshots(),
      builder: (context, snap) {
        final data    = snap.data?.data() as Map<String, dynamic>? ?? {};
        final balance = ((data['totalBalance'] ?? 12450.0) as num).toDouble();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientMid],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL BALANCE', style: TextStyle(
              color:      Colors.white.withOpacity(0.6),
              fontSize:   11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
            const SizedBox(height: 10),
            Text('₹${NumberFormat('#,##0.00').format(balance)}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 34,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Row(children: [
              Icon(Icons.trending_up_rounded,
                  size: 14, color: AppColors.onlineGreen),
              SizedBox(width: 4),
              Text('+12% from last week', style: TextStyle(
                  color: AppColors.onlineGreen, fontSize: 13,
                  fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _showWithdrawSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon:  const Icon(Icons.account_balance_rounded, size: 18),
                label: const Text('Withdraw',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 12),
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.history_rounded,
                    color: Colors.white, size: 22),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    const periods = ['Weekly', 'Monthly'];
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: periods.asMap().entries.map((entry) {
          final selected = _selectedPeriod == entry.key;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _selectedPeriod = entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:        selected ? AppColors.brandPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(child: Text(entry.value, style: TextStyle(
                color:      selected
                    ? Colors.white
                    : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                fontSize:   13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ))),
            ),
          ));
        }).toList(),
      ),
    );
  }

  Widget _buildAnalyticsCard(bool isDark) {
    const weeklyData = [1200.0, 1800.0, 1100.0, 2800.0, 2200.0, 1600.0, 400.0];
    const days       = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const maxVal     = 2800.0;
    const thisWeek   = 3240.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly Analytics', style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 2),
            Text('Dec 1 - Dec 7', style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 12,
            )),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${NumberFormat('#,##0').format(thisWeek)}',
                style: const TextStyle(
                    color: AppColors.brandPurple,
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text('THIS WEEK', style: TextStyle(
              color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1,
            )),
          ]),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weeklyData.asMap().entries.map((entry) {
              final i         = entry.key;
              final val       = entry.value;
              final isHighest = val == maxVal;
              final barHeight = (val / maxVal) * 100;

              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300 + i * 60),
                      height:   barHeight,
                      decoration: BoxDecoration(
                        color:        isHighest
                            ? AppColors.brandPurple
                            : AppColors.brandPurple.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(days[i], style: TextStyle(
                      color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 10,
                    )),
                  ],
                ),
              ));
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(children: [
      Text(title, style: TextStyle(
        color:      isDark ? Colors.white : AppColors.textDarkLight,
        fontSize:   18, fontWeight: FontWeight.w700,
      )),
      const Spacer(),
      TextButton(
        onPressed: () {},
        child: const Text('View All', style: TextStyle(
            color: AppColors.brandPurple, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildActivityList(bool isDark) {
    const transactions = [
      _Transaction(
        icon:     Icons.cleaning_services_rounded,
        iconColor: AppColors.brandPurple,
        title:    'Home Cleaning Service',
        subtitle: 'Today, 2:30 PM',
        amount:   '+₹450.00',
        status:   'COMPLETED',
        isCredit: true,
      ),
      _Transaction(
        icon:     Icons.electrical_services_rounded,
        iconColor: AppColors.warning,
        title:    'Electric Repair',
        subtitle: 'Yesterday, 11:15 AM',
        amount:   '+₹850.00',
        status:   'COMPLETED',
        isCredit: true,
      ),
      _Transaction(
        icon:     Icons.account_balance_rounded,
        iconColor: AppColors.textMidDark,
        title:    'Bank Withdrawal',
        subtitle: '02 Dec, 5:00 PM',
        amount:   '-₹2,000.00',
        status:   'SENT TO BANK',
        isCredit: false,
      ),
    ];

    return Column(
      children: transactions
          .map((t) => _TransactionCard(transaction: t, isDark: isDark))
          .toList(),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context:         context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),
              Text('Withdraw Earnings', style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   20, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 6),
              Text('Enter the amount you want to withdraw', style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13,
              )),
              const SizedBox(height: 20),
              TextFormField(
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   20, fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  prefixText:  '₹ ',
                  prefixStyle: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   20, fontWeight: FontWeight.w700,
                  ),
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Request Withdrawal'),
                ),
              ),
            ]),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────
class _Transaction {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final String   amount;
  final String   status;
  final bool     isCredit;
  const _Transaction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.isCredit,
  });
}

class _TransactionCard extends StatelessWidget {
  final _Transaction transaction;
  final bool         isDark;
  const _TransactionCard({required this.transaction, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        t.iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(t.icon, color: t.iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: TextStyle(
            color:      isDark ? Colors.white : AppColors.textDarkLight,
            fontSize:   14, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 2),
          Text(t.subtitle, style: TextStyle(
            color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
            fontSize: 12,
          )),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(t.amount, style: TextStyle(
            color:      t.isCredit ? AppColors.success : AppColors.textMidDark,
            fontSize:   15, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 3),
          Text(t.status, style: TextStyle(
            color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
            fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          )),
        ]),
      ]),
    );
  }
}