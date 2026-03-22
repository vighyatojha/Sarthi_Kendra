// lib/screens/support/support_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(children: [
        _buildHeader(context, isDark, isHindi),
        // Tab bar
        Container(
          color: isDark ? AppColors.cardDark : Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor:         AppColors.brandPurple,
            unselectedLabelColor: isDark ? AppColors.textMidDark : AppColors.textMidLight,
            indicatorColor:     AppColors.brandPurple,
            indicatorWeight:    3,
            labelStyle:   const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: isHindi ? 'सहायता गाइड' : 'Help Guide'),
              Tab(text: isHindi ? 'टिकट दर्ज करें' : 'Raise Ticket'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _HelpGuide(isDark: isDark, isHindi: isHindi),
              _RaiseTicket(isDark: isDark, isHindi: isHindi),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext ctx, bool isDark, bool isHindi) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 12,
        bottom: 16, left: 8, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF3B0764), Color(0xFF5B21B6), AppColors.brandPurple],
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.maybePop(ctx),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isHindi ? 'सहायता केंद्र' : 'Help & Support',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(isHindi ? 'हम यहाँ आपकी मदद के लिए हैं' : 'We\'re here to help you',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.support_agent_rounded, color: Colors.white, size: 14),
            SizedBox(width: 5),
            Text('24/7', style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

// ── Help Guide Tab ────────────────────────────────────────────────────────────
class _HelpGuide extends StatelessWidget {
  final bool isDark, isHindi;
  const _HelpGuide({required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // App Introduction Card
        _IntroCard(isDark: isDark, isHindi: isHindi),
        const SizedBox(height: 16),

        // Section: Getting Started
        _SectionHeading(
            text: isHindi ? 'शुरुआत कैसे करें' : 'Getting Started',
            isDark: isDark),
        const SizedBox(height: 10),
        ..._gettingStarted(isHindi).map((q) => _FaqItem(
            question: q.$1, answer: q.$2, isDark: isDark)),

        const SizedBox(height: 16),
        _SectionHeading(
            text: isHindi ? 'लॉगिन और साइनअप' : 'Login & Sign Up',
            isDark: isDark),
        const SizedBox(height: 10),
        ..._loginFaq(isHindi).map((q) => _FaqItem(
            question: q.$1, answer: q.$2, isDark: isDark)),

        const SizedBox(height: 16),
        _SectionHeading(
            text: isHindi ? 'काम और बुकिंग' : 'Jobs & Bookings',
            isDark: isDark),
        const SizedBox(height: 10),
        ..._jobsFaq(isHindi).map((q) => _FaqItem(
            question: q.$1, answer: q.$2, isDark: isDark)),

        const SizedBox(height: 16),
        _SectionHeading(
            text: isHindi ? 'भुगतान और कमाई' : 'Payments & Earnings',
            isDark: isDark),
        const SizedBox(height: 10),
        ..._paymentFaq(isHindi).map((q) => _FaqItem(
            question: q.$1, answer: q.$2, isDark: isDark)),

        const SizedBox(height: 20),
        // Contact info
        _ContactCard(isDark: isDark, isHindi: isHindi),
      ],
    );
  }

  List<(String, String)> _gettingStarted(bool hi) => hi ? [
    ('सार्थी केंद्र क्या है?',
    'सार्थी केंद्र एक प्लेटफ़ॉर्म है जो घर सेवा प्रदाताओं (हेल्पर्स) को ग्राहकों से जोड़ता है। आप प्लंबर, इलेक्ट्रीशियन, सफाई और अन्य सेवाएं प्रदान कर सकते हैं।'),
    ('ऑनलाइन/ऑफलाइन टॉगल कैसे काम करता है?',
    'होम स्क्रीन पर "Service Status" टॉगल को चालू करें जब आप काम लेने के लिए तैयार हों। बंद करने पर आपको नई बुकिंग नहीं मिलेगी।'),
    ('KYC क्यों जरूरी है?',
    'KYC (आधार + PAN) से आपकी पहचान सत्यापित होती है। बिना KYC के कुछ सुविधाएं सीमित रहेंगी। KYC प्रोफ़ाइल सेक्शन से करें।'),
  ] : [
    ('What is Sarthi Kendra?',
    'Sarthi Kendra connects home service helpers (plumbers, electricians, cleaners, etc.) with customers on the Trouble Sarthi platform. You receive bookings and earn money by completing them.'),
    ('How does the Online/Offline toggle work?',
    'On the Home screen, turn the "Service Status" toggle ON when you\'re ready to accept jobs. Turn it OFF when you\'re unavailable — you won\'t receive new bookings while offline.'),
    ('Why is KYC required?',
    'KYC (Aadhaar + PAN) verifies your identity and is required by law for financial transactions. Complete it from your Profile to unlock all features and get approved faster.'),
  ];

  List<(String, String)> _loginFaq(bool hi) => hi ? [
    ('साइन इन कैसे करें?',
    'अपना रजिस्टर्ड ईमेल या यूजरनेम और पासवर्ड डालें। "Google से जारी रखें" बटन से Google अकाउंट से भी लॉगिन कर सकते हैं।'),
    ('पासवर्ड भूल गए?',
    'लॉगिन पेज पर "Forgot Password?" लिंक पर टैप करें। ईमेल फील्ड में अपना ईमेल डालें, फिर लिंक पर टैप करें। आपके ईमेल पर रीसेट लिंक आएगा।'),
    ('Google से कैसे लॉगिन करें?',
    '"Continue with Google" बटन पर टैप करें। अपना Google अकाउंट चुनें। पहली बार लॉगिन पर एक नया हेल्पर प्रोफ़ाइल बनेगा।'),
    ('नया अकाउंट कैसे बनाएं?',
    'लॉगिन पेज पर "Register as Sarthi" पर टैप करें। Step 1 में नाम, फोन, ईमेल और पासवर्ड भरें। Step 2 में अपनी सेवाएं और क्षेत्र चुनें।'),
  ] : [
    ('How do I sign in?',
    'Enter your registered email address or username and password, then tap "Sign In". You can also use the "Continue with Google" button to sign in with your Google account.'),
    ('I forgot my password. What do I do?',
    'On the login screen, type your email in the identifier field, then tap "Forgot password?". A reset link will be sent to your email. Check your spam folder if you don\'t see it.'),
    ('How does Google Sign-In work?',
    'Tap "Continue with Google", select your Google account, and you\'re in. If you\'re new, a helper profile is automatically created. If you already have an account with the same email, it will be linked.'),
    ('How do I create a new account?',
    'Tap "Register as Sarthi" on the login screen. Step 1: fill in your name, phone, email and password. Step 2: select services you offer and your service area. After registration, complete KYC for full approval.'),
  ];

  List<(String, String)> _jobsFaq(bool hi) => hi ? [
    ('बुकिंग कैसे स्वीकार करें?',
    'नई बुकिंग होम स्क्रीन पर "New Requests" में दिखेगी। "Accept" बटन दबाएं। 60 सेकंड में जवाब न देने पर बुकिंग अपने आप समाप्त हो जाएगी।'),
    ('काम शुरू और पूरा कैसे करें?',
    'बुकिंग स्वीकार करने के बाद Jobs टैब पर जाएं। ग्राहक के पास पहुंचने पर "Start Job" दबाएं। काम पूरा होने पर "Mark as Complete" दबाएं।'),
  ] : [
    ('How do I accept a booking?',
    'New bookings appear in "New Requests" on the Home screen. Tap "Accept" to take the job. You have 60 seconds to respond — the request auto-expires if not accepted.'),
    ('How do I start and complete a job?',
    'After accepting, go to the Jobs tab to see your ongoing job. Tap "Start Job" when you arrive at the customer\'s location. Once the work is done, tap "Mark as Complete" and confirm to close the job.'),
  ];

  List<(String, String)> _paymentFaq(bool hi) => hi ? [
    ('पैसे कब मिलते हैं?',
    'काम पूरा होने पर भुगतान आपके Sarthi वॉलेट में क्रेडिट होता है। Earnings टैब पर बैलेंस देखें।'),
    ('पैसे निकालने की प्रक्रिया क्या है?',
    'Earnings टैब पर "Withdraw" बटन दबाएं। राशि दर्ज करें और बैंक खाता सत्यापित करें। 1-2 कार्य दिवसों में ट्रांसफर होगा।'),
  ] : [
    ('When do I get paid?',
    'Payment is credited to your Sarthi Wallet once a booking is marked complete. Check your balance in the Earnings tab. Withdrawals are processed within 1-2 business days.'),
    ('How do I withdraw my earnings?',
    'Go to Earnings → tap "Withdraw". Enter the amount and verify your bank details. Transfers take 1-2 business days. Minimum withdrawal amount is ₹100.'),
  ];
}

class _IntroCard extends StatelessWidget {
  final bool isDark, isHindi;
  const _IntroCard({required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF7C3AED)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isHindi ? 'सार्थी केंद्र में आपका स्वागत है' : 'Welcome to Sarthi Kendra',
                style: const TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(isHindi ? 'अपना सार्थी, अपना रोज़गार' : 'APNA SARTHI, APNA ROZGAR',
                style: TextStyle(
                    color: const Color(0xFF14FFEC), fontSize: 11, fontWeight: FontWeight.w600)),
          ])),
        ]),
        const SizedBox(height: 14),
        Text(
            isHindi
                ? 'सार्थी केंद्र एक ऐप है जो आपको घर सेवा बुकिंग प्राप्त करने, प्रबंधित करने और कमाई ट्रैक करने में मदद करता है। इस ऐप से आप — ऑनलाइन होकर नई बुकिंग प्राप्त कर सकते हैं, काम स्वीकार करके पूरा कर सकते हैं, और अपनी कमाई देख और निकाल सकते हैं।'
                : 'Sarthi Kendra is your helper-side companion for receiving, managing, and completing home service bookings. Through this app you can — go online to receive new job requests, accept and complete bookings, track your daily and weekly earnings, and manage your profile and KYC status.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.55)),
        const SizedBox(height: 12),
        // Quick feature chips
        Wrap(spacing: 8, runSpacing: 6, children: [
          _FeaturePill(label: isHindi ? '📱 ऑनलाइन टॉगल' : '📱 Online Toggle'),
          _FeaturePill(label: isHindi ? '✅ बुकिंग स्वीकार' : '✅ Accept Bookings'),
          _FeaturePill(label: isHindi ? '💰 कमाई ट्रैक' : '💰 Track Earnings'),
          _FeaturePill(label: isHindi ? '🔒 KYC वेरिफाई' : '🔒 KYC Verify'),
          _FeaturePill(label: isHindi ? '⭐ रेटिंग' : '⭐ Ratings'),
        ]),
      ]),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text; final bool isDark;
  const _SectionHeading({required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(
              color: AppColors.brandPurple,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          color:      isDark ? Colors.white : AppColors.textDarkLight,
          fontSize:   14, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _FaqItem extends StatefulWidget {
  final String question, answer;
  final bool isDark;
  const _FaqItem({required this.question, required this.answer, required this.isDark});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}
class _FaqItemState extends State<_FaqItem> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        widget.isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _open
                ? AppColors.brandPurple.withOpacity(0.3)
                : (widget.isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(widget.question, style: TextStyle(
                    color:      widget.isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   14, fontWeight: FontWeight.w600))),
                Icon(
                    _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.brandPurple, size: 22),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve:    Curves.easeOut,
                child: _open ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(widget.answer, style: TextStyle(
                      color:    widget.isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 13, height: 1.55)),
                ) : const SizedBox.shrink(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final bool isDark, isHindi;
  const _ContactCard({required this.isDark, required this.isHindi});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.headset_mic_rounded, color: AppColors.brandPurple, size: 22),
          const SizedBox(width: 10),
          Text(isHindi ? '24/7 सहायता' : '24/7 Support',
              style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        _ContactRow(
            icon: Icons.email_outlined,
            label: 'support@sarthikendra.in',
            isDark: isDark),
        const SizedBox(height: 8),
        _ContactRow(
            icon: Icons.phone_rounded,
            label: isHindi ? 'कॉल करें: 1800-XXX-XXXX (निःशुल्क)' : 'Call: 1800-XXX-XXXX (Toll Free)',
            isDark: isDark),
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon; final String label; final bool isDark;
  const _ContactRow({required this.icon, required this.label, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.brandPurple, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(
          color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
          fontSize: 13))),
    ]);
  }
}

// ── Raise Ticket Tab ──────────────────────────────────────────────────────────
class _RaiseTicket extends StatefulWidget {
  final bool isDark, isHindi;
  const _RaiseTicket({required this.isDark, required this.isHindi});
  @override
  State<_RaiseTicket> createState() => _RaiseTicketState();
}

class _RaiseTicketState extends State<_RaiseTicket> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl     = TextEditingController();
  String? _category;
  bool _isSubmitting = false;

  @override
  void dispose() { _subjectCtrl.dispose(); _msgCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_category == null || _subjectCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      _snack(widget.isHindi
          ? 'कृपया सभी फ़ील्ड भरें'
          : 'Please fill all fields', error: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'uid':       uid,
        'category':  _category,
        'subject':   _subjectCtrl.text.trim(),
        'message':   _msgCtrl.text.trim(),
        'status':    'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _subjectCtrl.clear(); _msgCtrl.clear();
        setState(() { _category = null; _isSubmitting = false; });
        _snack(widget.isHindi
            ? 'टिकट सफलतापूर्वक दर्ज हुआ! हम 24 घंटे में जवाब देंगे।'
            : 'Ticket submitted! We\'ll respond within 24 hours.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _snack('Failed to submit ticket. Please try again.', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hi      = widget.isHindi;
    final isDark  = widget.isDark;
    final cats    = hi
        ? ['लॉगिन समस्या', 'बुकिंग समस्या', 'भुगतान समस्या', 'KYC समस्या', 'अन्य']
        : ['Login Issue', 'Booking Issue', 'Payment Issue', 'KYC Issue', 'Other'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.brandPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brandPurple.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.brandPurple, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
                hi
                    ? 'हमारी टीम 24 घंटे के भीतर आपसे संपर्क करेगी।'
                    : 'Our support team will respond within 24 hours.',
                style: TextStyle(
                    color:    isDark ? AppColors.lightPurple : AppColors.brandPurple,
                    fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 20),

        // Category
        Text(hi ? 'श्रेणी चुनें' : 'Select Category',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) {
          final sel = _category == c;
          return GestureDetector(
            onTap: () => setState(() => _category = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.brandPurple
                    : (isDark ? AppColors.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: sel ? AppColors.brandPurple
                        : (isDark ? AppColors.borderDark : AppColors.borderLight)),
              ),
              child: Text(c, style: TextStyle(
                  color:      sel ? Colors.white
                      : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                  fontSize:   13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        }).toList()),

        const SizedBox(height: 20),

        // Subject
        Text(hi ? 'विषय' : 'Subject',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _subjectCtrl,
          style: TextStyle(
              color:    isDark ? Colors.white : AppColors.textDarkLight, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hi ? 'समस्या का संक्षिप्त विवरण' : 'Brief description of the issue',
            hintStyle: TextStyle(
                color:    isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
                fontSize: 14),
          ),
        ),

        const SizedBox(height: 16),

        // Message
        Text(hi ? 'विस्तार में बताएं' : 'Describe in Detail',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller:  _msgCtrl,
          maxLines:    5,
          style: TextStyle(
              color:    isDark ? Colors.white : AppColors.textDarkLight, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hi
                ? 'अपनी समस्या विस्तार से लिखें...'
                : 'Describe your issue in detail...',
            hintStyle: TextStyle(
                color:    isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
                fontSize: 14),
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
                _isSubmitting
                    ? (hi ? 'भेजा जा रहा है...' : 'Submitting...')
                    : (hi ? 'टिकट दर्ज करें' : 'Submit Ticket'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}