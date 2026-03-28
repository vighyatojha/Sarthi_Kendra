// lib/screens/profile/edit_profile_screen.dart
//
// DROP-IN REPLACEMENT — uses your existing LanguageProvider.
// No new files needed. Delete language_notifier.dart if you downloaded it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/helper_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BILINGUAL HELPER
// ─────────────────────────────────────────────────────────────────────────────

String _t(bool isHindi, String en, String hi) => isHindi ? hi : en;

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE DATA — 12 categories matching home_screen.dart exactly
// ─────────────────────────────────────────────────────────────────────────────

class _Svc {
  final String en, hi;
  final IconData icon;
  const _Svc(this.en, this.hi, this.icon);
}

class _Cat {
  final String titleEn, titleHi;
  final IconData icon;
  final Color color, bgColor;
  final List<_Svc> svcs;
  const _Cat({
    required this.titleEn,
    required this.titleHi,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.svcs,
  });
}

const List<_Cat> _kCats = [
  _Cat(
    titleEn: 'Home Services', titleHi: 'घर की सेवाएं',
    icon: Icons.home_repair_service_rounded,
    color: Color(0xFF7C3AED), bgColor: Color(0xFFEDE9FE),
    svcs: [
      _Svc('Plumber',         'प्लंबर',          Icons.water_drop_outlined),
      _Svc('Electrician',     'इलेक्ट्रीशियन',    Icons.bolt_outlined),
      _Svc('Carpenter',       'बढ़ई',             Icons.carpenter),
      _Svc('AC Repair',       'एसी रिपेयर',       Icons.ac_unit_outlined),
      _Svc('RO Repair',       'आरओ रिपेयर',       Icons.water_outlined),
      _Svc('Appliance Repair','उपकरण मरम्मत',     Icons.kitchen_outlined),
      _Svc('Painter',         'पेंटर',            Icons.format_paint_outlined),
      _Svc('Cleaner',         'सफाईकर्मी',        Icons.cleaning_services_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Vehicle Services', titleHi: 'वाहन सेवाएं',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7), bgColor: Color(0xFFE0F2FE),
    svcs: [
      _Svc('Car Mechanic',        'कार मैकेनिक',       Icons.car_repair),
      _Svc('Bike Mechanic',       'बाइक मैकेनिक',      Icons.two_wheeler),
      _Svc('Towing Service',      'टोइंग सेवा',        Icons.local_shipping_outlined),
      _Svc('Puncture Repair',     'पंचर रिपेयर',       Icons.tire_repair),
      _Svc('Car Wash',            'कार वॉश',           Icons.local_car_wash_outlined),
      _Svc('Battery Jump Start',  'बैटरी जंप स्टार्ट', Icons.battery_charging_full_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Emergency', titleHi: 'आपातकाल',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFDC2626), bgColor: Color(0xFFFEE2E2),
    svcs: [
      _Svc('Ambulance',          'एम्बुलेंस',          Icons.local_hospital_outlined),
      _Svc('First Aid',          'प्राथमिक चिकित्सा',  Icons.medical_services_outlined),
      _Svc('Blood Donor',        'रक्तदाता',           Icons.bloodtype_outlined),
      _Svc('Fire Help',          'अग्नि सहायता',       Icons.local_fire_department_outlined),
      _Svc('Disaster Support',   'आपदा सहायता',        Icons.warning_amber_outlined),
      _Svc('Mid-Night Emergency','मध्यरात्रि आपातकाल', Icons.nights_stay_rounded),
    ],
  ),
  _Cat(
    titleEn: 'Delivery & Pickup', titleHi: 'डिलीवरी और पिकअप',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFFD97706), bgColor: Color(0xFFFEF3C7),
    svcs: [
      _Svc('Parcel Pickup',     'पार्सल पिकअप',    Icons.local_post_office_outlined),
      _Svc('Grocery Delivery',  'किराना डिलीवरी',  Icons.shopping_basket_outlined),
      _Svc('Medicine Delivery', 'दवा डिलीवरी',     Icons.medication_outlined),
      _Svc('Document Courier',  'दस्तावेज़ कूरियर', Icons.description_outlined),
      _Svc('Local Shifting',    'स्थानीय शिफ्टिंग', Icons.move_to_inbox_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Technical Services', titleHi: 'तकनीकी सेवाएं',
    icon: Icons.build_rounded,
    color: Color(0xFF0891B2), bgColor: Color(0xFFCFFAFE),
    svcs: [
      _Svc('Mobile Repair', 'मोबाइल रिपेयर',    Icons.phone_android_outlined),
      _Svc('Laptop Repair', 'लैपटॉप रिपेयर',    Icons.laptop_outlined),
      _Svc('CCTV Install',  'सीसीटीवी इंस्टॉल', Icons.videocam_outlined),
      _Svc('WiFi Install',  'वाईफाई इंस्टॉल',   Icons.wifi_outlined),
      _Svc('Software Help', 'सॉफ्टवेयर सहायता', Icons.code_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Personal Assistance', titleHi: 'व्यक्तिगत सहायता',
    icon: Icons.school_rounded,
    color: Color(0xFF059669), bgColor: Color(0xFFD1FAE5),
    svcs: [
      _Svc('Home Tutor',      'होम ट्यूटर',    Icons.school_outlined),
      _Svc('Fitness Trainer', 'फिटनेस ट्रेनर', Icons.fitness_center_outlined),
      _Svc('Yoga Instructor', 'योग प्रशिक्षक', Icons.self_improvement_outlined),
      _Svc('Caretaker',       'देखभालकर्मी',   Icons.elderly_outlined),
      _Svc('Babysitter',      'बेबीसिटर',      Icons.child_care_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Events & Occasions', titleHi: 'कार्यक्रम और अवसर',
    icon: Icons.celebration_rounded,
    color: Color(0xFFDB2777), bgColor: Color(0xFFFCE7F3),
    svcs: [
      _Svc('Photographer', 'फोटोग्राफर',  Icons.camera_alt_outlined),
      _Svc('Videographer', 'वीडियोग्राफर', Icons.videocam_outlined),
      _Svc('DJ',           'डीजे',         Icons.music_note_outlined),
      _Svc('Decoration',   'सजावट',        Icons.auto_awesome_outlined),
      _Svc('Catering',     'कैटरिंग',      Icons.restaurant_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Construction', titleHi: 'निर्माण कार्य',
    icon: Icons.foundation_rounded,
    color: Color(0xFF92400E), bgColor: Color(0xFFFDE68A),
    svcs: [
      _Svc('Mason',           'राजमिस्त्री',       Icons.foundation_outlined),
      _Svc('Interior Design', 'इंटीरियर डिज़ाइन',  Icons.design_services_outlined),
      _Svc('Tiles Worker',    'टाइल्स वर्कर',      Icons.grid_on_outlined),
      _Svc('Architect Help',  'आर्किटेक्ट सहायता', Icons.architecture_outlined),
      _Svc('Fabrication',     'फैब्रिकेशन',        Icons.handyman_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Cleaning', titleHi: 'सफाई सेवाएं',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFF0D9488), bgColor: Color(0xFFCCFBF1),
    svcs: [
      _Svc('Deep Cleaning',  'डीप क्लीनिंग', Icons.clean_hands_outlined),
      _Svc('Bathroom Clean', 'बाथरूम सफाई',  Icons.bathroom_outlined),
      _Svc('Sofa Cleaning',  'सोफा सफाई',    Icons.chair_outlined),
      _Svc('Pest Control',   'कीट नियंत्रण', Icons.pest_control_outlined),
      _Svc('Water Tank',     'पानी की टंकी', Icons.water_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Professional', titleHi: 'पेशेवर सेवाएं',
    icon: Icons.gavel_rounded,
    color: Color(0xFF4338CA), bgColor: Color(0xFFE0E7FF),
    svcs: [
      _Svc('Lawyer Consult', 'वकील परामर्श',      Icons.gavel_outlined),
      _Svc('CA / Tax Help',  'CA / टैक्स सहायता', Icons.calculate_outlined),
      _Svc('Insurance',      'बीमा',               Icons.shield_outlined),
      _Svc('Real Estate',    'रियल एस्टेट',        Icons.apartment_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Outdoor & More', titleHi: 'बाहरी सेवाएं',
    icon: Icons.park_rounded,
    color: Color(0xFF16A34A), bgColor: Color(0xFFDCFCE7),
    svcs: [
      _Svc('Gardener',        'माली',              Icons.yard_outlined),
      _Svc('Security Guard',  'सुरक्षा गार्ड',      Icons.security_outlined),
      _Svc('Driver on Hire',  'किराये पर ड्राइवर',  Icons.directions_car_outlined),
      _Svc('Scrap Collector', 'कबाड़ संग्रहकर्ता',  Icons.recycling_outlined),
    ],
  ),
  _Cat(
    titleEn: 'Community Help', titleHi: 'सामुदायिक सहायता',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFF7C3AED), bgColor: Color(0xFFF3E8FF),
    svcs: [
      _Svc('Volunteer Help', 'स्वयंसेवक सहायता',     Icons.volunteer_activism_outlined),
      _Svc('Senior Support', 'वरिष्ठ नागरिक सहायता', Icons.elderly_outlined),
      _Svc('Student Helper', 'छात्र सहायक',           Icons.school_outlined),
      _Svc('NGO Support',    'एनजीओ सहायता',          Icons.favorite_border),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl  = TextEditingController();

  final Set<String> _selected = {};
  final Set<int>    _expanded = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final helper = context.read<AuthProvider>().helper;
    if (helper != null) {
      _nameCtrl.text  = helper.name;
      _phoneCtrl.text = helper.phone;
      _areaCtrl.text  = helper.area;
      _selected.addAll(helper.services);
    }
    _expanded.addAll([0, 1]);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lang = context.read<LanguageProvider>();
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      _snack(_t(lang.isHindi, 'Select at least one service',
          'कम से कम एक सेवा चुनें'), error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final auth    = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name:     _nameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      area:     _areaCtrl.text.trim(),
      services: _selected.toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      _snack(_t(lang.isHindi, 'Profile updated!', 'प्रोफ़ाइल अपडेट हुई!'));
      Navigator.pop(context);
    } else {
      _snack(auth.errorMessage ??
          _t(lang.isHindi, 'Update failed.', 'अपडेट विफल।'), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));

  @override
  Widget build(BuildContext context) {
    final lang    = context.watch<LanguageProvider>();
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final helper  = context.watch<AuthProvider>().helper;
    final isHindi = lang.isHindi;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF2F4F8),
      body: Column(children: [
        _buildHeader(isDark, isHindi, helper),
        Expanded(
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [

                // ── Progress banner ──────────────────────────────────
                SliverToBoxAdapter(
                  child: _ProgressBanner(
                      isDark: isDark, isHindi: isHindi,
                      count: _selected.length),
                ),

                // ── Personal info ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _PersonalInfoCard(
                      isDark: isDark, isHindi: isHindi,
                      nameCtrl: _nameCtrl, phoneCtrl: _phoneCtrl,
                      areaCtrl: _areaCtrl,
                    ),
                  ),
                ),

                // ── Section heading ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(isHindi, 'Services You Offer',
                                  'आप कौन सी सेवाएं देते हैं?'),
                              style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _t(isHindi,
                                  'Tap a category to expand and pick services',
                                  'श्रेणी पर टैप करें और सेवाएं चुनें'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.25)),
                        ),
                        child: Text(
                          _t(isHindi, '${_selected.length} selected',
                              '${_selected.length} चुनी'),
                          style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                ),

                // ── Category accordion cards ─────────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    childCount: _kCats.length,
                        (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: _CatCard(
                        cat: _kCats[i], isDark: isDark,
                        isHindi: isHindi,
                        isExpanded: _expanded.contains(i),
                        selected: _selected,
                        onToggleExpand: () => setState(() =>
                        _expanded.contains(i)
                            ? _expanded.remove(i)
                            : _expanded.add(i)),
                        onToggle: (en) => setState(() =>
                        _selected.contains(en)
                            ? _selected.remove(en)
                            : _selected.add(en)),
                      ),
                    ),
                  ),
                ),

                // ── Save button ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                    child: _SaveButton(
                      isDark: isDark, isHindi: isHindi,
                      isSaving: _isSaving, onSave: _save,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(bool isDark, bool isHindi, HelperModel? helper) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(isHindi, 'Edit Profile', 'प्रोफ़ाइल संपादित करें'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                    if (helper != null) ...[
                      const SizedBox(height: 2),
                      Text(helper.displayId,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.50),
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.30), width: 2),
                ),
                child: Center(
                  child: Text(helper?.initials ?? 'SK',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ]),
          ),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF2F4F8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBanner extends StatelessWidget {
  final bool isDark, isHindi;
  final int count;
  const _ProgressBanner(
      {required this.isDark, required this.isHindi, required this.count});

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: empty ? const Color(0xFFFEF2F2) : const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: empty
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFC4B5FD),
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: empty
                  ? const Color(0xFFDC2626).withOpacity(0.12)
                  : const Color(0xFF7C3AED).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              empty
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: empty ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty
                      ? _t(isHindi, 'No services selected', 'कोई सेवा नहीं चुनी')
                      : _t(isHindi, '$count services selected',
                      '$count सेवाएं चुनी गई हैं'),
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: empty
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF4C1D95),
                  ),
                ),
                Text(
                  _t(isHindi,
                      'Tap a category below to expand and select',
                      'नीचे श्रेणी पर टैप करके सेवाएं चुनें'),
                  style: TextStyle(
                    fontSize: 11,
                    color: empty
                        ? const Color(0xFFDC2626).withOpacity(0.70)
                        : const Color(0xFF6D28D9).withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          if (!empty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSONAL INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  final bool isDark, isHindi;
  final TextEditingController nameCtrl, phoneCtrl, areaCtrl;
  const _PersonalInfoCard({
    required this.isDark, required this.isHindi,
    required this.nameCtrl, required this.phoneCtrl, required this.areaCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D3D) : const Color(0xFFE8E4F3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.10 : 0.06),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2D2D3D)
                    : const Color(0xFFE8E4F3),
              ),
            ),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 16, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 10),
            Text(
              _t(isHindi, 'Personal Information', 'व्यक्तिगत जानकारी'),
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ]),
        ),

        // Fields
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _Field(
              ctrl: nameCtrl, isDark: isDark,
              label: _t(isHindi, 'Full Name', 'पूरा नाम'),
              hint:  _t(isHindi, 'Your full name', 'आपका पूरा नाम'),
              icon: Icons.badge_outlined, color: const Color(0xFF7C3AED),
              validator: (v) => v!.trim().isEmpty
                  ? _t(isHindi, 'Name is required', 'नाम आवश्यक है')
                  : null,
            ),
            const SizedBox(height: 12),
            _Field(
              ctrl: phoneCtrl, isDark: isDark,
              label: _t(isHindi, 'Mobile Number', 'मोबाइल नंबर'),
              hint: '9876543210',
              icon: Icons.phone_android_rounded, color: const Color(0xFF0284C7),
              inputType: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v!.isEmpty)
                  return _t(isHindi, 'Phone required', 'फ़ोन आवश्यक है');
                if (v.length != 10)
                  return _t(isHindi, 'Enter 10-digit number', '10 अंक दर्ज करें');
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(
              ctrl: areaCtrl, isDark: isDark,
              label: _t(isHindi, 'Service Area', 'सेवा क्षेत्र'),
              hint:  _t(isHindi, 'e.g. Vesu, Surat', 'उदा. वेसू, सूरत'),
              icon: Icons.location_on_outlined, color: const Color(0xFF059669),
              validator: (v) => v!.trim().isEmpty
                  ? _t(isHindi, 'Area is required', 'क्षेत्र आवश्यक है')
                  : null,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextInputType? inputType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl, required this.isDark,
    required this.label, required this.hint,
    required this.icon, required this.color,
    this.inputType, this.formatters, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563))),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        inputFormatters: formatters,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF111827),
          fontSize: 14, fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark
                  ? const Color(0xFF484F58)
                  : const Color(0xFFADB5BD),
              fontSize: 14),
          prefixIcon: Icon(icon, color: color, size: 18),
          filled: true,
          fillColor: isDark ? const Color(0xFF23232F) : color.withOpacity(0.04),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2D2D3D)
                    : color.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC2626)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          isDense: true,
        ),
        validator: validator,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY ACCORDION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CatCard extends StatelessWidget {
  final _Cat cat;
  final bool isDark, isHindi, isExpanded;
  final Set<String> selected;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onToggle;

  const _CatCard({
    required this.cat, required this.isDark, required this.isHindi,
    required this.isExpanded, required this.selected,
    required this.onToggleExpand, required this.onToggle,
  });

  int get _count => cat.svcs.where((s) => selected.contains(s.en)).length;
  bool get _hasAny => _count > 0;

  @override
  Widget build(BuildContext context) {
    final c  = cat.color;
    final bg = cat.bgColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasAny
              ? c.withOpacity(0.40)
              : (isDark ? const Color(0xFF2D2D3D) : const Color(0xFFE8E4F3)),
          width: _hasAny ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasAny
                ? c.withOpacity(0.10)
                : Colors.black.withOpacity(0.03),
            blurRadius: _hasAny ? 12 : 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: isDark ? c.withOpacity(0.15) : bg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: c.withOpacity(_hasAny ? 0.35 : 0.15)),
                ),
                child: Icon(cat.icon, color: c, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? cat.titleHi : cat.titleEn,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasAny
                          ? _t(isHindi,
                          '$_count of ${cat.svcs.length} selected',
                          '${cat.svcs.length} में से $_count चुनी')
                          : _t(isHindi,
                          '${cat.svcs.length} services',
                          '${cat.svcs.length} सेवाएं'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _hasAny ? FontWeight.w600 : FontWeight.w400,
                        color: _hasAny
                            ? c
                            : (isDark
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasAny)
                Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$_count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: isDark
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF)),
              ),
            ]),
          ),
        ),

        // Chips
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve:  Curves.easeOutCubic,
          secondCurve: Curves.easeInCubic,
          crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild:  const SizedBox.shrink(),
          secondChild: Column(children: [
            Divider(height: 1,
                color: isDark
                    ? const Color(0xFF2D2D3D)
                    : const Color(0xFFF0EDF8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: cat.svcs.map((svc) {
                  final sel = selected.contains(svc.en);
                  return GestureDetector(
                    onTap: () => onToggle(svc.en),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? c
                            : (isDark
                            ? const Color(0xFF23232F)
                            : bg.withOpacity(0.55)),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: sel ? c : c.withOpacity(0.22)),
                        boxShadow: sel
                            ? [BoxShadow(
                            color: c.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          sel ? Icons.check_circle_rounded : svc.icon,
                          size: 13,
                          color: sel ? Colors.white : c,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isHindi ? svc.hi : svc.en,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel
                                ? Colors.white
                                : (isDark
                                ? Colors.white.withOpacity(0.80)
                                : c),
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isDark, isHindi, isSaving;
  final VoidCallback onSave;
  const _SaveButton({
    required this.isDark, required this.isHindi,
    required this.isSaving, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSaving ? null : onSave,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          gradient: isSaving
              ? const LinearGradient(
              colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
              : const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF9333EA),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSaving ? [] : [
            BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.38),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isSaving)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          else
            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            isSaving
                ? _t(isHindi, 'Saving...', 'सहेजा जा रहा है...')
                : _t(isHindi, 'Save Changes', 'बदलाव सहेजें'),
            style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
        ]),
      ),
    );
  }
}