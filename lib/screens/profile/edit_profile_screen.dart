// lib/screens/profile/edit_profile_screen.dart
// FIXED: Full light theme, curved section cards, curved header divider,
//        all functionality preserved from original

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/helper_model.dart';

// ── Translation ───────────────────────────────────────────────────────────────
String _t(String l, String en, String hi, String gu) =>
    l == 'hi' ? hi : l == 'gu' ? gu : en;

extension _Op on Color {
  Color op(double a) => withValues(alpha: a);
}

// ── Tokens (light-only) ───────────────────────────────────────────────────────
const _kPurple = Color(0xFF5B21D4);
const _kPurpleD = Color(0xFF4C1D95);
const _kBg     = Color(0xFFF4F3FF);
const _kWhite  = Colors.white;
const _kBorder = Color(0xFFEBE8F9);
const _kInputBg= Color(0xFFF3F0FD);
const _kText1  = Color(0xFF1A0A3C);
const _kText2  = Color(0xFF4B5563);
const _kText3  = Color(0xFF9CA3AF);

// ── Static data (preserved exactly) ──────────────────────────────────────────
const _kDays  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
const _kSlots = ['Morning','Afternoon','Evening','Night'];

class _Svc { final String en, hi, gu; final IconData icon;
const _Svc(this.en, this.hi, this.gu, this.icon); }
class _Cat { final String en, hi, gu; final IconData icon;
final Color color, bg; final List<_Svc> svcs;
const _Cat({required this.en,required this.hi,required this.gu,
  required this.icon,required this.color,required this.bg,required this.svcs}); }

// (All category data preserved — abbreviated here for clarity, see original file)
// ── 12 Categories (full list) ─────────────────────────────────────────────
const _kCats = <_Cat>[
  // 1 ── Home Services
  _Cat(
    en: 'Home Services', hi: 'घर सेवाएं', gu: 'ઘર સેવા',
    icon: Icons.home_repair_service_rounded,
    color: Color(0xFF7C3AED), bg: Color(0xFFEDE9FE),
    svcs: [
      _Svc('Plumber',         'प्लंबर',            'પ્લમ્બર',         Icons.water_drop_outlined),
      _Svc('Electrician',     'इलेक्ट्रीशियन',      'ઇલેક્ટ્રિશિયન',   Icons.bolt_outlined),
      _Svc('Carpenter',       'बढ़ई',               'સુથાર',           Icons.carpenter),
      _Svc('AC Repair',       'एसी रिपेयर',         'AC રિપેર',        Icons.ac_unit_outlined),
      _Svc('RO Repair',       'आरओ रिपेयर',         'RO રિપેર',        Icons.water_outlined),
      _Svc('Appliance Repair','अप्लायंस रिपेयर',    'ઉપકરણ રિપેર',    Icons.kitchen_outlined),
      _Svc('Painter',         'पेंटर',              'પેઇન્ટર',         Icons.format_paint_outlined),
      _Svc('Cleaner',         'सफाईकर्मी',          'સફાઈ કર્મી',      Icons.cleaning_services_outlined),
    ],
  ),

  // 2 ── Vehicle Services
  _Cat(
    en: 'Vehicle Services', hi: 'वाहन सेवाएं', gu: 'વાહન સેવા',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7), bg: Color(0xFFE0F2FE),
    svcs: [
      _Svc('Car Mechanic',    'कार मैकेनिक',        'કાર મિકેનિક',     Icons.car_repair),
      _Svc('Bike Mechanic',   'बाइक मैकेनिक',       'બાઇક મિકેનિક',    Icons.two_wheeler),
      _Svc('Towing Service',  'टोइंग सेवा',          'ટોઇંગ સેવા',      Icons.local_shipping_outlined),
      _Svc('Puncture Repair', 'पंचर रिपेयर',         'પંચર રિપેર',      Icons.tire_repair),
      _Svc('Car Wash',        'कार वॉश',             'કાર વૉશ',         Icons.local_car_wash_outlined),
      _Svc('Battery Jump Start','बैटरी जम्प',        'બૅટ્રી જમ્પ',     Icons.battery_charging_full_outlined),
    ],
  ),

  // 3 ── Emergency
  _Cat(
    en: 'Emergency', hi: 'आपातकाल', gu: 'કટોકટી',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFDC2626), bg: Color(0xFFFEE2E2),
    svcs: [
      _Svc('Ambulance',               'एम्बुलेंस',         'એમ્બ્યુલન્સ',      Icons.local_hospital_outlined),
      _Svc('First Aid',               'प्राथमिक चिकित्सा', 'પ્રાથમિક સારવાર',  Icons.medical_services_outlined),
      _Svc('Blood Donor',             'रक्तदाता',           'રક્ત દાતા',         Icons.bloodtype_outlined),
      _Svc('Fire Help',               'अग्नि सहायता',       'અગ્નિ સહાય',        Icons.local_fire_department_outlined),
      _Svc('Disaster Support',        'आपदा सहायता',        'આફત સહાય',          Icons.crisis_alert_outlined),
      _Svc('Mid-Night Vehicle Emergency','मध्यरात्रि वाहन', 'મધ્ય-રાત્રિ વાહન', Icons.directions_car_outlined),
    ],
  ),

  // 4 ── Delivery & Pickup
  _Cat(
    en: 'Delivery & Pickup', hi: 'डिलीवरी', gu: 'ડિલિવરી',
    icon: Icons.local_shipping_rounded,
    color: Color(0xFFD97706), bg: Color(0xFFFEF3C7),
    svcs: [
      _Svc('Parcel Pickup',      'पार्सल पिकअप',     'પાર્સલ પિકઅપ',       Icons.local_post_office_outlined),
      _Svc('Grocery Delivery',   'किराना डिलीवरी',   'કરિયાણા ડિલિવરી',    Icons.shopping_basket_outlined),
      _Svc('Medicine Delivery',  'दवा डिलीवरी',      'દવા ડિલિવરી',         Icons.medication_outlined),
      _Svc('Document Courier',   'दस्तावेज़ कूरियर', 'ડૉક્યૂ. કૂરિયર',     Icons.description_outlined),
      _Svc('Local Shifting',     'लोकल शिफ्टिंग',    'સ્થાનિક શિફ્ટિંગ',   Icons.move_to_inbox_outlined),
    ],
  ),

  // 5 ── Technical Services
  _Cat(
    en: 'Technical', hi: 'तकनीकी', gu: 'ટેકનિકલ',
    icon: Icons.build_rounded,
    color: Color(0xFF0891B2), bg: Color(0xFFCFFAFE),
    svcs: [
      _Svc('Mobile Repair',  'मोबाइल रिपेयर',  'મોબાઇલ રિપેર',  Icons.phone_android_outlined),
      _Svc('Laptop Repair',  'लैपटॉप रिपेयर',  'લેપટોપ રિપેર',  Icons.laptop_outlined),
      _Svc('CCTV Install',   'सीसीटीवी इंस्टॉल','CCTV ઇન્સ્ટોલ', Icons.videocam_outlined),
      _Svc('WiFi Install',   'वाईफाई इंस्टॉल', 'WiFi ઇન્સ્ટોલ', Icons.wifi_outlined),
      _Svc('Software Help',  'सॉफ्टवेयर सहायता','સૉફ્ટ. સહાય',   Icons.computer_outlined),
    ],
  ),

  // 6 ── Personal Assistance
  _Cat(
    en: 'Personal Assistance', hi: 'व्यक्तिगत सहायता', gu: 'વ્યક્તિગત',
    icon: Icons.support_agent_rounded,
    color: Color(0xFF7C3AED), bg: Color(0xFFF3E8FF),
    svcs: [
      _Svc('Home Tutor',        'होम ट्यूटर',        'હોમ ટ્યૂટર',    Icons.menu_book_outlined),
      _Svc('Fitness Trainer',   'फिटनेस ट्रेनर',     'ફિટ. ટ્રેઇનર',  Icons.fitness_center_outlined),
      _Svc('Yoga Instructor',   'योग प्रशिक्षक',      'યોગ ઇન્સ.',     Icons.self_improvement_outlined),
      _Svc('Caretaker',         'देखभाल करने वाला',  'કૅરટૅકર',       Icons.volunteer_activism_outlined),
      _Svc('Babysitter',        'बेबीसिटर',           'બૅબીસિટર',      Icons.child_care_outlined),
    ],
  ),

  // 7 ── Events & Occasions
  _Cat(
    en: 'Events', hi: 'इवेंट्स', gu: 'ઇવેન્ટ',
    icon: Icons.celebration_rounded,
    color: Color(0xFFDB2777), bg: Color(0xFFFCE7F3),
    svcs: [
      _Svc('Photographer',  'फोटोग्राफर', 'ફોટોગ્રાફર', Icons.camera_alt_outlined),
      _Svc('Videographer',  'वीडियोग्राफर','વિડિઓ.',     Icons.videocam_outlined),
      _Svc('DJ',            'डीजे',        'DJ',          Icons.music_note_outlined),
      _Svc('Decoration',    'सजावट',       'સજાવટ',       Icons.auto_awesome_outlined),
      _Svc('Catering',      'कैटरिंग',     'કેટરિંગ',     Icons.restaurant_outlined),
    ],
  ),

  // 8 ── Construction
  _Cat(
    en: 'Construction', hi: 'निर्माण', gu: 'બાંધકામ',
    icon: Icons.construction_rounded,
    color: Color(0xFFB45309), bg: Color(0xFFFEF9C3),
    svcs: [
      _Svc('Mason',           'राजमिस्त्री',     'કડિયો',         Icons.foundation_outlined),
      _Svc('Interior Design', 'इंटीरियर डिज़ाइन','ઇન્ટ. ડિઝાઇન',  Icons.design_services_outlined),
      _Svc('Tiles Worker',    'टाइल्स मजदूर',    'ટાઇલ્સ',        Icons.grid_on_outlined),
      _Svc('Architect Help',  'आर्किटेक्ट',      'આર્કિ.',         Icons.architecture_outlined),
      _Svc('Fabrication',     'फैब्रिकेशन',       'ફૅબ્રિ.',       Icons.handyman_outlined),
    ],
  ),

  // 9 ── Cleaning
  _Cat(
    en: 'Cleaning', hi: 'सफाई', gu: 'સફાઈ',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFF0D9488), bg: Color(0xFFCCFBF1),
    svcs: [
      _Svc('Deep Cleaning',      'डीप क्लीनिंग',    'ડીપ ક્લિ.',       Icons.clean_hands_outlined),
      _Svc('Bathroom Clean',     'बाथरूम सफाई',     'બાથ. સફાઈ',       Icons.bathroom_outlined),
      _Svc('Sofa Cleaning',      'सोफा सफाई',        'સોફા ક્લિ.',      Icons.chair_outlined),
      _Svc('Pest Control',       'कीट नियंत्रण',    'જીવાત',           Icons.pest_control_outlined),
      _Svc('Water Tank Cleaning','टैंक सफाई',        'ટૅન્ક ક્લિ.',     Icons.water_damage_outlined),
    ],
  ),

  // 10 ── Professional
  _Cat(
    en: 'Professional', hi: 'पेशेवर सेवाएं', gu: 'વ્યાવ. સેવા',
    icon: Icons.business_center_rounded,
    color: Color(0xFF1D4ED8), bg: Color(0xFFDBEAFE),
    svcs: [
      _Svc('Lawyer Consult', 'वकील परामर्श',  'વકીલ.',    Icons.gavel_outlined),
      _Svc('CA / Tax Help',  'CA / टैक्स',    'CA / ટૅક્સ',Icons.account_balance_outlined),
      _Svc('Insurance',      'बीमा',           'વીમો',     Icons.shield_outlined),
      _Svc('Real Estate',    'रियल एस्टेट',    'રિ. એસ.',  Icons.apartment_outlined),
    ],
  ),

  // 11 ── Outdoor & More
  _Cat(
    en: 'Outdoor & More', hi: 'बाहरी सेवाएं', gu: 'આઉટડોર',
    icon: Icons.park_rounded,
    color: Color(0xFF16A34A), bg: Color(0xFFDCFCE7),
    svcs: [
      _Svc('Gardener',       'माली',               'માળી',          Icons.yard_outlined),
      _Svc('Security Guard', 'सुरक्षा गार्ड',       'સુ. ગાર્ડ',    Icons.security_outlined),
      _Svc('Driver on Hire', 'किराये पर ड्राइवर',  'ભાડે ડ્રાઇ.',  Icons.directions_car_outlined),
      _Svc('Scrap Collector','कबाड़ीवाला',           'ભંગાર.',       Icons.recycling_outlined),
    ],
  ),

  // 12 ── Community Help
  _Cat(
    en: 'Community Help', hi: 'सामुदायिक सहायता', gu: 'સમુ. સહાય',
    icon: Icons.groups_rounded,
    color: Color(0xFF9333EA), bg: Color(0xFFF3E8FF),
    svcs: [
      _Svc('Volunteer Help',  'स्वयंसेवी',      'સ્વૈ. સહા.',  Icons.favorite_outline_rounded),
      _Svc('Senior Support',  'बुजुर्ग सहायता', 'વૃ. સહાય',    Icons.elderly_outlined),
      _Svc('Student Helper',  'छात्र सहायक',    'વિ. સહ.',     Icons.school_outlined),
      _Svc('NGO Support',     'एनजीओ सहायता',   'NGO સહ.',     Icons.handshake_outlined),
    ],
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _areaCtrl   = TextEditingController();
  final _bioCtrl    = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _searchCtrl = TextEditingController();

  String      _lang         = 'en';
  int         _expYears     = 0;
  bool        _isNegotiable = false;
  bool        _isAvailable  = true;
  Set<String> _selected     = {};
  Set<String> _availDays    = {};
  Set<String> _availSlots   = {};
  int?        _activeCatIdx;
  File?       _photoFile;
  String?     _photoUrl;
  bool        _uploadingPhoto = false;
  bool        _saving         = false;
  bool        _loaded         = false;
  String      _searchQuery    = '';

  @override
  void initState() {
    super.initState();
    final lp = context.read<LanguageProvider>();
    _lang = lp.isHindi ? 'hi' : 'en';
    _searchCtrl.addListener(
            () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim()));
    for (final c in [_nameCtrl, _phoneCtrl, _areaCtrl, _bioCtrl, _priceCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _areaCtrl, _bioCtrl, _priceCtrl, _searchCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final h = context.read<AuthProvider>().helper;
    if (h == null) return;
    _nameCtrl.text  = h.name;
    _phoneCtrl.text = h.phone;
    _areaCtrl.text  = h.area;
    _selected       = Set.from(h.services);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('helpers').doc(h.uid).get();
      final d = doc.data() ?? {};
      _bioCtrl.text   = (d['bio'] ?? d['description'] ?? '') as String;
      _expYears       = ((d['experience'] ?? 0) as num).toInt();
      final p         = ((d['pricePerVisit'] ?? 0) as num).toInt();
      _priceCtrl.text = p > 0 ? '$p' : '';
      _isNegotiable   = d['isNegotiable'] as bool? ?? false;
      _isAvailable    = d['isAvailable']  as bool? ?? true;
      _availDays      = Set<String>.from(d['availDays']  ?? []);
      _availSlots     = Set<String>.from(d['availSlots'] ?? []);
      _photoUrl       = d['photoUrl'] as String?;
      final sl        = d['preferredLanguage'] as String?;
      if (sl != null && ['en','hi','gu'].contains(sl)) _lang = sl;
    } catch (_) {}

    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    final xf = await ImagePicker().pickImage(
        source: source, imageQuality: 82, maxWidth: 900);
    if (xf == null || !mounted) return;
    setState(() { _photoFile = File(xf.path); _uploadingPhoto = true; });
    try {
      final uid = context.read<AuthProvider>().helper?.uid ?? 'tmp';
      final ref = FirebaseStorage.instance.ref('helpers/$uid/profile.jpg');
      await ref.putFile(_photoFile!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('helpers').doc(uid).update({'photoUrl': url});
      if (mounted) setState(() => _photoUrl = url);
    } catch (_) {}
    finally { if (mounted) setState(() => _uploadingPhoto = false); }
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20,
            MediaQuery.of(context).padding.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(_t(_lang,'Change Photo','फोटो बदलें','ફોટો બદલો'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: _kText1)),
          const SizedBox(height: 14),
          _SheetOpt(icon: Icons.camera_alt_rounded, color: _kPurple,
              label: _t(_lang,'Camera','कैमरा','કૅમેરો'),
              onTap: () => _pickPhoto(ImageSource.camera)),
          const SizedBox(height: 8),
          _SheetOpt(icon: Icons.photo_library_rounded,
              color: const Color(0xFF0891B2),
              label: _t(_lang,'Gallery','गैलरी','ગૅલેરી'),
              onTap: () => _pickPhoto(ImageSource.gallery)),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected.isEmpty) {
      _snack(_t(_lang,'Select at least one service',
          'कम से कम एक सेवा चुनें','ઓછામાં ઓછી એક સેવા'), err: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final auth  = context.read<AuthProvider>();
    final uid   = auth.helper?.uid ?? '';
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;

    try {
      await FirebaseFirestore.instance.collection('helpers').doc(uid).update({
        'name':              _nameCtrl.text.trim(),
        'phone':             _phoneCtrl.text.trim(),
        'phoneNumber':       _phoneCtrl.text.trim(),
        'area':              _areaCtrl.text.trim(),
        'location':          _areaCtrl.text.trim(),
        'bio':               _bioCtrl.text.trim(),
        'description':       _bioCtrl.text.trim(),
        'experience':        _expYears,
        'pricePerVisit':     price,
        'isNegotiable':      _isNegotiable,
        'isAvailable':       _isAvailable,
        'services':          _selected.toList(),
        'subcategory':       _selected.isNotEmpty ? _selected.first : '',
        'serviceType':       _selected.isNotEmpty ? _selected.first : '',
        'skills':            _selected.toList(),
        'availDays':         _availDays.toList(),
        'availSlots':        _availSlots.toList(),
        'preferredLanguage': _lang,
        'updatedAt':         FieldValue.serverTimestamp(),
      });
      await auth.refreshProfile();
      if (_lang == 'en' || _lang == 'hi') {
        context.read<LanguageProvider>().setLanguage(_lang);
      }
      if (mounted) {
        _snack(_t(_lang,'Profile saved!','प्रोफ़ाइल सहेजी!','પ્રોફાઇલ સેવ થઈ!'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Save failed', err: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));

  double get _pct {
    final checks = [
      _nameCtrl.text.trim().isNotEmpty,
      _phoneCtrl.text.trim().length == 10,
      _areaCtrl.text.trim().isNotEmpty,
      _bioCtrl.text.trim().isNotEmpty,
      _expYears > 0,
      (int.tryParse(_priceCtrl.text.trim()) ?? 0) > 0,
      _selected.isNotEmpty,
      _availDays.isNotEmpty,
      _availSlots.isNotEmpty,
    ];
    final base  = (checks.where((b) => b).length / checks.length) * 95;
    final photo = (_photoUrl != null || _photoFile != null) ? 5.0 : 0.0;
    return ((base + photo) / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildHeader(),
        if (!_loaded)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2)))
        else
          Expanded(child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(children: [
                _buildPhotoAndProgress(),
                _buildLangSelector(),
                _buildPersonalInfo(),
                _buildWorkDetails(),
                _buildServicesSection(),
                const SizedBox(height: 12),
              ]),
            ),
          )),
        _buildStickyBar(),
      ]),
    );
  }

  // ── Header (purple, curved bottom) ────────────────────────────────────────
  Widget _buildHeader() {
    final helper = context.watch<AuthProvider>().helper;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 16, 18),
        child: Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t(_lang,'Edit Profile','प्रोफ़ाइल संपादित करें','પ્રોફાઇલ સંપાદિત'),
                style: const TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w800)),
            if (helper != null)
              Text(helper.displayId,
                  style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 11)),
          ])),
          _saving
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.30)),
              ),
              child: Text(_t(_lang,'Save','सहेजें','સેવ'),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      )),
    );
  }

  // ── Photo + Progress ──────────────────────────────────────────────────────
  Widget _buildPhotoAndProgress() {
    final helper   = context.watch<AuthProvider>().helper;
    final pct      = _pct;
    final pctInt   = (pct * 100).round();
    final progColor= pct >= 0.8 ? const Color(0xFF059669) : _kPurple;

    return _Card(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(children: [
        GestureDetector(
          onTap: _showPhotoPicker,
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEDE9FE),
                border: Border.all(color: _kPurple.op(0.35), width: 2.5),
                image: _photoFile != null
                    ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                    : (_photoUrl != null
                    ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                    : null),
              ),
              child: (_photoFile == null && _photoUrl == null)
                  ? Center(child: Text(helper?.initials ?? 'SK',
                  style: const TextStyle(color: _kPurpleD,
                      fontSize: 22, fontWeight: FontWeight.w900)))
                  : (_uploadingPhoto ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple))) : null),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: _kPurple, shape: BoxShape.circle,
                border: Border.all(color: _kWhite, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(helper?.name.isNotEmpty == true ? helper!.name
              : _t(_lang,'Your Profile','आपकी प्रोफ़ाइल','તમારી પ્રોફાઇલ'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText1)),
          if (helper?.area.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 11, color: _kText3),
              const SizedBox(width: 3),
              Text(helper!.area, style: const TextStyle(fontSize: 11, color: _kText3)),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: pct, minHeight: 6,
                backgroundColor: _kPurple.op(0.10),
                valueColor: AlwaysStoppedAnimation(progColor),
              ),
            )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: progColor.op(0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$pctInt%', style: TextStyle(
                  color: progColor, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(pct >= 1.0
              ? _t(_lang,'Profile complete 🎉','प्रोफ़ाइल पूर्ण 🎉','પ્રોફાઇલ પૂર્ણ 🎉')
              : _t(_lang,'Fill more to boost visibility',
              'और भरें','વધુ ભરો'),
              style: const TextStyle(fontSize: 11, color: _kText3)),
        ])),
      ]),
    );
  }

  // ── Language selector ──────────────────────────────────────────────────────
  Widget _buildLangSelector() {
    return _SecCard(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.language_rounded, iconColor: const Color(0xFF0891B2),
      title: _t(_lang,'App Language','भाषा चुनें','ભાષા પસંદ કરો'),
      child: Row(children: [
        Expanded(child: _LangBtn(label: 'English', active: _lang == 'en',
            onTap: () => setState(() => _lang = 'en'))),
        const SizedBox(width: 8),
        Expanded(child: _LangBtn(label: 'हिंदी', active: _lang == 'hi',
            onTap: () => setState(() => _lang = 'hi'))),
        const SizedBox(width: 8),
        Expanded(child: _LangBtn(label: 'ગુજરાતી', active: _lang == 'gu',
            onTap: () => setState(() => _lang = 'gu'))),
      ]),
    );
  }

  // ── Personal info ──────────────────────────────────────────────────────────
  Widget _buildPersonalInfo() {
    return _SecCard(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.person_outline_rounded, iconColor: _kPurple,
      title: _t(_lang,'Personal Information','व्यक्तिगत जानकारी','વ્યક્તિગત માહિતી'),
      child: Column(children: [
        _LF(ctrl:_nameCtrl, label:_t(_lang,'Full Name','पूरा नाम','પૂરું નામ'),
            hint:_t(_lang,'Ramesh Kumar','रमेश कुमार','રમેશ કુમાર'),
            icon:Icons.badge_outlined, color:_kPurple,
            valid:(v) => v!.trim().isEmpty ? _t(_lang,'Required','आवश्यक','જરૂરી') : null),
        const SizedBox(height: 12),
        _LF(ctrl:_phoneCtrl, label:_t(_lang,'Mobile Number','मोबाइल नंबर','મોબાઇલ નંબર'),
            hint:'9876543210', icon:Icons.phone_android_rounded,
            color:const Color(0xFF0284C7), inputType:TextInputType.phone,
            formatters:[FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)],
            valid:(v) {
              if (v!.isEmpty) return _t(_lang,'Required','आवश्यक','જરૂરી');
              if (v.length != 10) return _t(_lang,'Enter 10 digits','10 अंक','10 અંક');
              return null;
            }),
        const SizedBox(height: 12),
        _LF(ctrl:_areaCtrl, label:_t(_lang,'Service Area','सेवा क्षेत्र','સેવા વિસ્તાર'),
            hint:_t(_lang,'Vesu, Surat','वेसू, सूरत','વેસુ, સુરત'),
            icon:Icons.location_on_outlined, color:const Color(0xFF059669),
            valid:(v) => v!.trim().isEmpty ? _t(_lang,'Required','आवश्यक','જરૂરી') : null),
        const SizedBox(height: 12),
        _LF(ctrl:_bioCtrl, label:_t(_lang,'About You','अपने बारे में','તમારા વિશે'),
            hint:_t(_lang,'I am a professional with 5 years experience...',
                'मैं 5 साल के अनुभव वाला पेशेवर हूं...','5 વર્ષ અનુભવ સાથે...'),
            icon:Icons.info_outline_rounded, color:const Color(0xFF0891B2),
            maxLines:3),
      ]),
    );
  }

  // ── Work details ───────────────────────────────────────────────────────────
  Widget _buildWorkDetails() {
    return _SecCard(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.work_outline_rounded, iconColor: const Color(0xFFD97706),
      title: _t(_lang,'Work Details','कार्य विवरण','કામ વિગત'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Experience
        Row(children: [
          const Icon(Icons.timeline_rounded, size: 12, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(_t(_lang,'Experience','अनुभव','અનુભવ'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              _expYears == 0 ? _t(_lang,'Fresher','नया','નવો')
                  : '$_expYears ${_t(_lang,'yrs','वर्ष','વર્ષ')}',
              style: const TextStyle(color: Color(0xFFD97706),
                  fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFD97706),
            inactiveTrackColor: const Color(0xFFD97706).withOpacity(0.15),
            thumbColor: const Color(0xFFD97706),
            overlayColor: const Color(0xFFD97706).withOpacity(0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: _expYears.toDouble(), min: 0, max: 30, divisions: 30,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _expYears = v.round());
            },
          ),
        ),

        const Divider(height: 28, color: Color(0xFFF0EEFF)),

        // Price
        Row(children: [
          const Icon(Icons.currency_rupee_rounded, size: 12, color: Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(_t(_lang,'Price / Visit','प्रति विज़िट','પ્રતિ મુલાકાત ચાર્જ'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText2)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: _kText1, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '₹ 150',
              hintStyle: const TextStyle(color: _kText3),
              prefixIcon: const Icon(Icons.currency_rupee_rounded,
                  color: Color(0xFF059669), size: 18),
              filled: true, fillColor: _kInputBg,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDC2626))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              isDense: true,
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isNegotiable = !_isNegotiable);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: _isNegotiable ? const Color(0xFF059669) : _kInputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isNegotiable ? const Color(0xFF059669) : _kBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.handshake_outlined, size: 14,
                    color: _isNegotiable ? Colors.white : _kText3),
                const SizedBox(width: 5),
                Text(_t(_lang,'Nego.','नेगो','નેગો'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _isNegotiable ? Colors.white : _kText3)),
              ]),
            ),
          ),
        ]),

        const Divider(height: 28, color: Color(0xFFF0EEFF)),

        // Availability toggle
        Row(children: [
          const Icon(Icons.toggle_on_rounded, size: 12, color: _kPurple),
          const SizedBox(width: 6),
          Expanded(child: Text(
            _t(_lang,'Available for Bookings','बुकिंग के लिए उपलब्ध','બુકિંગ માટે ઉપલબ્ધ'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText2),
          )),
          Transform.scale(scale: 0.82, child: Switch(
            value: _isAvailable, activeColor: _kPurple,
            onChanged: (v) => setState(() => _isAvailable = v),
          )),
        ]),

        const SizedBox(height: 10),

        // Working days
        _SubLabel(Icons.calendar_today_rounded,
            _t(_lang,'Working Days','कार्य दिवस','કામકાજના દિવસ'),
            const Color(0xFF0891B2)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _kDays.map((d) {
          final sel = _availDays.contains(d);
          return _Chip(label: _localDay(d), selected: sel,
              color: const Color(0xFF0891B2),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => sel ? _availDays.remove(d) : _availDays.add(d));
              });
        }).toList()),

        const SizedBox(height: 12),

        _SubLabel(Icons.schedule_rounded,
            _t(_lang,'Working Hours','कार्य समय','કામ સમય'),
            const Color(0xFFDB2777)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _kSlots.map((s) {
          final sel = _availSlots.contains(s);
          return _Chip(label: _localSlot(s), selected: sel,
              color: const Color(0xFFDB2777),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => sel ? _availSlots.remove(s) : _availSlots.add(s));
              });
        }).toList()),
      ]),
    );
  }

  // ── Services section ───────────────────────────────────────────────────────
  Widget _buildServicesSection() {
    return _SecCard(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.home_repair_service_rounded, iconColor: _kPurple,
      title: _t(_lang,'Services You Offer','आप कौन सी सेवाएं देते हैं?','તમે કઈ સેવાઓ આપો છો?'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _kPurple.op(0.10), borderRadius: BorderRadius.circular(20)),
        child: Text('${_selected.length} ${_t(_lang,'selected','चुनी','પસંદ')}',
            style: const TextStyle(color: _kPurple, fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSearchBar(),
        const SizedBox(height: 14),
        if (_searchQuery.isNotEmpty)
          _buildSearchResults()
        else ...[
          _buildCategoryGrid(),
          if (_activeCatIdx != null) ...[
            const SizedBox(height: 12),
            _buildServicePanel(),
          ],
        ],
      ]),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: _kText1, fontSize: 13),
      decoration: InputDecoration(
        hintText: _t(_lang,'Search services...','सेवा खोजें...','સેવા શોધો...'),
        hintStyle: const TextStyle(color: _kText3, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _kPurple, size: 18),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
          onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
          child: const Icon(Icons.close_rounded, size: 16, color: _kPurple),
        ) : null,
        filled: true, fillColor: _kInputBg,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _kPurple.op(0.18))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kPurple, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8,
          mainAxisSpacing: 8, childAspectRatio: 1.0),
      itemCount: _kCats.length,
      itemBuilder: (_, i) {
        final cat    = _kCats[i];
        final active = _activeCatIdx == i;
        final count  = cat.svcs.where((s) => _selected.contains(s.en)).length;
        final hasAny = count > 0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _activeCatIdx = active ? null : i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: active ? cat.color.op(0.10) : _kWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? cat.color
                    : (hasAny ? cat.color.op(0.40) : _kBorder),
                width: (active || hasAny) ? 1.5 : 1.0,
              ),
              boxShadow: active ? [BoxShadow(
                  color: cat.color.op(0.15), blurRadius: 10,
                  offset: const Offset(0, 3))] : [],
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: active ? cat.color.op(0.15) : cat.bg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 18),
                  ),
                  const SizedBox(height: 5),
                  Text(_t(_lang, cat.en, cat.hi, cat.gu),
                      textAlign: TextAlign.center,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10,
                          fontWeight: (active || hasAny) ? FontWeight.w700 : FontWeight.w500,
                          color: active ? cat.color : _kText1)),
                ]),
              ),
              if (hasAny) Positioned(top: 4, right: 4, child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                child: Center(child: Text('$count',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 9, fontWeight: FontWeight.bold))),
              )),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildServicePanel() {
    final cat    = _kCats[_activeCatIdx!];
    final allSel = cat.svcs.every((s) => _selected.contains(s.en));

    return Container(
      decoration: BoxDecoration(
        color: cat.color.op(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cat.color.op(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28,
              decoration: BoxDecoration(color: cat.bg,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(cat.icon, color: cat.color, size: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(_t(_lang, cat.en, cat.hi, cat.gu),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cat.color))),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (allSel) { for (final s in cat.svcs) _selected.remove(s.en); }
                else { for (final s in cat.svcs) _selected.add(s.en); }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: allSel ? cat.color : cat.color.op(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(allSel
                  ? _t(_lang,'Clear All','सब हटाएं','બધા કાઢો')
                  : _t(_lang,'Select All','सब चुनें','બધા પસંદ'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: allSel ? Colors.white : cat.color)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 6,
              mainAxisSpacing: 6, childAspectRatio: 2.6),
          itemCount: cat.svcs.length,
          itemBuilder: (_, i) {
            final svc = cat.svcs[i];
            final sel = _selected.contains(svc.en);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => sel ? _selected.remove(svc.en) : _selected.add(svc.en));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: sel ? cat.color : _kWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? cat.color : cat.color.op(0.28)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(sel ? Icons.check_rounded : svc.icon,
                      size: 11, color: sel ? Colors.white : cat.color),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_t(_lang, svc.en, svc.hi, svc.gu),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white : cat.color))),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildSearchResults() {
    final results = <({int catIdx, _Svc svc})>[];
    for (var i = 0; i < _kCats.length; i++) {
      for (final svc in _kCats[i].svcs) {
        if (svc.en.toLowerCase().contains(_searchQuery) ||
            svc.hi.contains(_searchQuery) || svc.gu.contains(_searchQuery)) {
          results.add((catIdx: i, svc: svc));
        }
      }
    }
    if (results.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No services found',
              style: TextStyle(color: _kText3))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${results.length} result(s)',
          style: const TextStyle(fontSize: 11, color: _kText3)),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6,
            mainAxisSpacing: 6, childAspectRatio: 2.6),
        itemCount: results.length,
        itemBuilder: (_, i) {
          final cat = _kCats[results[i].catIdx];
          final svc = results[i].svc;
          final sel = _selected.contains(svc.en);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => sel ? _selected.remove(svc.en) : _selected.add(svc.en));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: sel ? cat.color : _kWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? cat.color : cat.color.op(0.28)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(sel ? Icons.check_rounded : svc.icon,
                    size: 11, color: sel ? Colors.white : cat.color),
                const SizedBox(width: 4),
                Flexible(child: Text(_t(_lang, svc.en, svc.hi, svc.gu),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : cat.color))),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  // ── Sticky Save Bar ────────────────────────────────────────────────────────
  Widget _buildStickyBar() {
    final pct      = _pct;
    final progColor= pct >= 0.8 ? const Color(0xFF059669) : _kPurple;
    final botPad   = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, botPad + 12),
      decoration: const BoxDecoration(
        color: _kWhite,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: [BoxShadow(
            color: Color(0x12000000), blurRadius: 18,
            offset: Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(_pct * 100).round()}% ${_t(_lang,'complete','पूर्ण','પૂર્ણ')}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: progColor)),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: _kPurple.op(0.10),
                valueColor: AlwaysStoppedAnimation(progColor),
              )),
        ])),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 50, width: 155,
            decoration: BoxDecoration(
              gradient: _saving
                  ? const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
                  : const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_kPurpleD, _kPurple, Color(0xFF9333EA)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _saving ? [] : [BoxShadow(
                  color: _kPurple.op(0.35), blurRadius: 14,
                  offset: const Offset(0, 5))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_saving)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.save_alt_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(_saving
                  ? _t(_lang,'Saving...','सहेज रहा...','સેવ થઈ રહ્યો...')
                  : _t(_lang,'Save Changes','सहेजें','સેવ કરો'),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Local helpers ──────────────────────────────────────────────────────────
  String _localDay(String d) {
    const hi = {'Mon':'सोम','Tue':'मंग','Wed':'बुध','Thu':'गुरु',
      'Fri':'शुक्र','Sat':'शनि','Sun':'रवि'};
    const gu = {'Mon':'સોમ','Tue':'મંગ','Wed':'બુધ','Thu':'ગુરુ',
      'Fri':'શુક્ર','Sat':'શનિ','Sun':'રવિ'};
    if (_lang == 'hi') return hi[d] ?? d;
    if (_lang == 'gu') return gu[d] ?? d;
    return d;
  }
  String _localSlot(String s) {
    switch (s) {
      case 'Morning':   return _t(_lang,'Morning','सुबह','સવાર');
      case 'Afternoon': return _t(_lang,'Afternoon','दोपहर','બપોર');
      case 'Evening':   return _t(_lang,'Evening','शाम','સાંજ');
      case 'Night':     return _t(_lang,'Night','रात','રાત');
      default:          return s;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED PRIVATE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Light plain card ──────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  const _Card({required this.child, this.margin});
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEBE8F9)),
      boxShadow: [BoxShadow(color: const Color(0xFF5B21D4).withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

// ── Section card with header strip ────────────────────────────────────────────
class _SecCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? margin;
  const _SecCard({required this.icon, required this.iconColor,
    required this.title, required this.child, this.trailing, this.margin});

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEBE8F9)),
      boxShadow: [BoxShadow(color: const Color(0xFF5B21D4).withOpacity(0.05),
          blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.05),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(bottom: BorderSide(color: Color(0xFFF0EEFF))),
        ),
        child: Row(children: [
          Container(width: 30, height: 30,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: iconColor)),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          if (trailing != null) trailing!,
        ]),
      ),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

// ── Form field ────────────────────────────────────────────────────────────────
class _LF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final Color color;
  final int maxLines;
  final TextInputType? inputType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? valid;

  const _LF({required this.ctrl, required this.label, required this.hint,
    required this.icon, required this.color, this.maxLines = 1,
    this.inputType, this.formatters, this.valid});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kText2)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, maxLines: maxLines,
        keyboardType: inputType, inputFormatters: formatters,
        style: const TextStyle(color: _kText1, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kText3, fontSize: 13),
          prefixIcon: maxLines == 1 ? Icon(icon, color: color, size: 16) : null,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: maxLines > 1 ? 12 : 11),
          isDense: true, filled: true, fillColor: _kInputBg,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        ),
        validator: valid,
      ),
    ],
  );
}

// ── Language button ───────────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _LangBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(
            colors: [Color(0xFF4C1D95), _kPurple]) : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? Colors.transparent : _kBorder),
      ),
      child: Center(child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Colors.white : _kText3))),
    ),
  );
}

// ── Toggle chip ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label; final bool selected; final Color color;
  final VoidCallback onTap; final IconData? leadingIcon;
  const _Chip({required this.label, required this.selected,
    required this.color, required this.onTap, this.leadingIcon});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 11,
              color: selected ? Colors.white : _kText3),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kText3)),
      ]),
    ),
  );
}

// ── Sub-label ─────────────────────────────────────────────────────────────────
class _SubLabel extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _SubLabel(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 12, color: color), const SizedBox(width: 5),
    Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  ]);
}

// ── Photo picker sheet option ─────────────────────────────────────────────────
class _SheetOpt extends StatelessWidget {
  final IconData icon; final Color color;
  final String label; final VoidCallback onTap;
  const _SheetOpt({required this.icon, required this.color,
    required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, size: 12,
            color: color.withOpacity(0.40)),
      ]),
    ),
  );
}