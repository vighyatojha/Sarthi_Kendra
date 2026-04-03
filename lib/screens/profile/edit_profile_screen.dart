// lib/screens/profile/edit_profile_screen.dart
//
// Complete rewrite — All features:
//   · Profile photo upload (Camera / Gallery → Firebase Storage)
//   · Experience slider (0–30 yrs)
//   · Pricing per visit + Negotiable toggle
//   · Availability: working days + time-slot chips
//   · Language selector: EN / हिं / ગુ
//   · 12 category cards (3-per-row), tap to expand services below
//   · Service chips in 3-per-row grid + Select All
//   · Live search across all services
//   · Profile completion progress bar (reactive)
//   · Sticky save button with mini progress
//   · Full Firestore write: name, phone, area, bio, exp, price,
//     negotiable, available, services, days, slots, lang, photoUrl
//
// pubspec.yaml (add if missing):
//   image_picker: ^1.1.2
//   firebase_storage: ^11.6.0

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

// ─── Translation helper ────────────────────────────────────────────────────────
String _t(String l, String en, String hi, String gu) =>
    l == 'hi' ? hi : l == 'gu' ? gu : en;

extension _Op on Color {
  Color op(double a) => withValues(alpha: a);
}

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _purple     = Color(0xFF7C3AED);
const _purpleDeep = Color(0xFF5B21B6);
const _purpleLight= Color(0xFFEDE9FE);
const _bgLight    = Color(0xFFF2F4F8);
const _bgDark     = Color(0xFF0F0F14);
const _cardDark   = Color(0xFF1A1A24);
const _border     = Color(0xFFE8E4F3);
const _borderDark = Color(0xFF2D2D3D);

// ─── Static data ───────────────────────────────────────────────────────────────
const _kDays  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
const _kSlots = ['Morning','Afternoon','Evening','Night'];

class _Svc {
  final String en, hi, gu;
  final IconData icon;
  const _Svc(this.en, this.hi, this.gu, this.icon);
}

class _Cat {
  final String en, hi, gu;
  final IconData icon;
  final Color color, bg;
  final List<_Svc> svcs;
  const _Cat({required this.en, required this.hi, required this.gu,
    required this.icon, required this.color, required this.bg,
    required this.svcs});
}

const _kCats = <_Cat>[
  _Cat(en:'Home Services',hi:'घर सेवाएं',gu:'ઘર સેવા',
      icon:Icons.home_repair_service_rounded,
      color:Color(0xFF7C3AED),bg:Color(0xFFEDE9FE),
      svcs:[
        _Svc('Plumber','प्लंबर','પ્લ\u0bae\u0bcd\u0baa\u0bb0\u0bcd',Icons.water_drop_outlined),
        _Svc('Electrician','इलेक्ट्रीशियन','ઇલે\u0a95\u0acd\u0aa4\u0acd\u0ab0\u0abf\u0ab6\u0abf\u0aaf\u0aa8',Icons.bolt_outlined),
        _Svc('Carpenter','बढ़ई','સ\u0ac1\u0aa5\u0abe\u0ab0',Icons.carpenter),
        _Svc('AC Repair','एसी रिपेयर','AC \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.ac_unit_outlined),
        _Svc('RO Repair','आरओ रिपेयर','RO \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.water_outlined),
        _Svc('Appliance Repair','उपकरण मरम्मत','\u0a89\u0aaa\u0a95\u0ab0\u0aa3 \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.kitchen_outlined),
        _Svc('Painter','पेंटर','\u0aaa\u0ac7\u0a87\u0aa8\u0acd\u0a9f\u0ab0',Icons.format_paint_outlined),
        _Svc('Cleaner','सफाईकर्मी','\u0ab8\u0aab\u0abe\u0a88 \u0a95\u0ab0\u0acd\u0aae\u0ac0',Icons.cleaning_services_outlined),
      ]),
  _Cat(en:'Vehicle',hi:'वाहन सेवाएं',gu:'વ\u0abe\u0ab9\u0aa8',
      icon:Icons.directions_car_rounded,
      color:Color(0xFF0284C7),bg:Color(0xFFE0F2FE),
      svcs:[
        _Svc('Car Mechanic','कार मैकेनिक','\u0a95\u0abe\u0ab0 \u0aae\u0abf\u0a95\u0ac7\u0aa8\u0abf\u0a95',Icons.car_repair),
        _Svc('Bike Mechanic','बाइक मैकेनिक','\u0aac\u0abe\u0a87\u0a95 \u0aae\u0abf\u0a95\u0ac7\u0aa8\u0abf\u0a95',Icons.two_wheeler),
        _Svc('Towing Service','टोइंग सेवा','\u0a9f\u0acb\u0a87\u0a82\u0a97 \u0ab8\u0ac7\u0ab5\u0abe',Icons.local_shipping_outlined),
        _Svc('Puncture Repair','पंचर रिपेयर','\u0aaa\u0a82\u0a9a\u0ab0 \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.tire_repair),
        _Svc('Car Wash','कार वॉश','\u0a95\u0abe\u0ab0 \u0ab5\u0acb\u0ab6',Icons.local_car_wash_outlined),
        _Svc('Battery Jumpstart','बैटरी जंपस्टार्ट','\u0aac\u0ac7\u0a9f\u0ab0\u0ac0 \u0a9c\u0a82\u0aaa',Icons.battery_charging_full_outlined),
      ]),
  _Cat(en:'Emergency',hi:'आपातकाल',gu:'\u0a95\u0a9f\u0acb\u0a95\u0a9f\u0ac0',
      icon:Icons.local_hospital_rounded,
      color:Color(0xFFDC2626),bg:Color(0xFFFEE2E2),
      svcs:[
        _Svc('Ambulance','एम्बुलेंस','\u0aae\u0acd\u0aac\u0ac1\u0ab2\u0aa8\u0acd\u0ab8',Icons.local_hospital_outlined),
        _Svc('First Aid','प्राथमिक चिकित्सा','\u0aaa\u0acd\u0ab0\u0abe\u0aa5\u0aae\u0abf\u0a95 \u0ab8\u0abe\u0ab0\u0ab5\u0abe\u0ab0',Icons.medical_services_outlined),
        _Svc('Blood Donor','रक्तदाता','\u0ab0\u0a95\u0acd\u0aa4 \u0aa6\u0abe\u0aa4\u0abe',Icons.bloodtype_outlined),
        _Svc('Fire Help','अग्नि सहायता','\u0a85\u0a97\u0acd\u0aa8\u0abf \u0ab8\u0ab9\u0abe\u0aaf',Icons.local_fire_department_outlined),
        _Svc('Disaster Support','आपदा सहायता','\u0a86\u0aaa\u0aa4\u0acd\u0aa4\u0abf \u0ab8\u0ab9\u0abe\u0aaf',Icons.warning_amber_outlined),
        _Svc('Mid-Night Emergency','मध्यरात्रि आपातकाल','\u0aae\u0aa7\u0acd\u0aaf \u0ab0\u0abe\u0aa4\u0acd\u0ab0\u0abf',Icons.nights_stay_rounded),
      ]),
  _Cat(en:'Delivery',hi:'डिलीवरी',gu:'\u0aa1\u0abf\u0ab2\u0abf\u0ab5\u0ab0\u0ac0',
      icon:Icons.local_shipping_rounded,
      color:Color(0xFFD97706),bg:Color(0xFFFEF3C7),
      svcs:[
        _Svc('Parcel Pickup','पार्सल पिकअप','\u0aaa\u0abe\u0ab0\u0acd\u0ab8\u0ab2 \u0aaa\u0abf\u0a95\u0a85\u0aaa',Icons.local_post_office_outlined),
        _Svc('Grocery Delivery','किराना डिलीवरी','\u0a95\u0ab0\u0abf\u0aaf\u0abe\u0aa3\u0abe \u0aa1\u0abf\u0ab2\u0abf\u0ab5\u0ab0\u0ac0',Icons.shopping_basket_outlined),
        _Svc('Medicine Delivery','दवा डिलीवरी','\u0aa6\u0ab5\u0abe \u0aa1\u0abf\u0ab2\u0abf\u0ab5\u0ab0\u0ac0',Icons.medication_outlined),
        _Svc('Document Courier','दस्तावेज़ कूरियर','\u0aa6\u0ab8\u0acd\u0aa4\u0abe\u0ab5\u0ac7\u0a9c \u0a95\u0ac2\u0ab0\u0abf\u0aaf\u0ab0',Icons.description_outlined),
        _Svc('Local Shifting','स्थानीय शिफ्टिंग','\u0ab8\u0acd\u0aa5\u0abe\u0aa8\u0abf\u0a95 \u0ab6\u0abf\u0aab\u0acd\u0a9f\u0abf\u0a82\u0a97',Icons.move_to_inbox_outlined),
      ]),
  _Cat(en:'Technical',hi:'तकनीकी',gu:'\u0a9f\u0ac7\u0a95\u0acd\u0aa8\u0abf\u0a95\u0ab2',
      icon:Icons.build_rounded,
      color:Color(0xFF0891B2),bg:Color(0xFFCFFAFE),
      svcs:[
        _Svc('Mobile Repair','मोबाइल रिपेयर','\u0aae\u0acb\u0aac\u0abe\u0a87\u0ab2 \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.phone_android_outlined),
        _Svc('Laptop Repair','लैपटॉप रिपेयर','\u0ab2\u0ac7\u0aaa\u0a9f\u0acb\u0aaa \u0ab0\u0abf\u0aaa\u0ac7\u0ab0',Icons.laptop_outlined),
        _Svc('CCTV Install','सीसीटीवी इंस्टॉल','CCTV \u0a87\u0aa8\u0acd\u0ab8\u0acd\u0a9f\u0acb\u0ab2',Icons.videocam_outlined),
        _Svc('WiFi Install','वाईफाई इंस्टॉल','WiFi \u0a87\u0aa8\u0acd\u0ab8\u0acd\u0a9f\u0acb\u0ab2',Icons.wifi_outlined),
        _Svc('Software Help','सॉफ्टवेयर सहायता','\u0ab8\u0acb\u0aab\u0acd\u0a9f\u0ab5\u0ac7\u0ab0 \u0ab8\u0ab9\u0abe\u0aaf',Icons.code_outlined),
      ]),
  _Cat(en:'Personal',hi:'व्यक्तिगत',gu:'\u0ab5\u0acd\u0aaf\u0a95\u0acd\u0aa4\u0abf\u0a97\u0aa4',
      icon:Icons.school_rounded,
      color:Color(0xFF059669),bg:Color(0xFFD1FAE5),
      svcs:[
        _Svc('Home Tutor','होम ट्यूटर','\u0ab9\u0acb\u0aae \u0a9f\u0acd\u0aaf\u0ac1\u0a9f\u0ab0',Icons.school_outlined),
        _Svc('Fitness Trainer','फिटनेस ट्रेनर','\u0aab\u0abf\u0a9f\u0aa8\u0ac7\u0ab8 \u0a9f\u0acd\u0ab0\u0ac7\u0a87\u0aa8\u0ab0',Icons.fitness_center_outlined),
        _Svc('Yoga Instructor','योग प्रशिक्षक','\u0aaf\u0acb\u0a97 \u0ab6\u0abf\u0a95\u0acd\u0ab7\u0a95',Icons.self_improvement_outlined),
        _Svc('Caretaker','देखभालकर्मी','\u0ab8\u0a82\u0aad\u0abe\u0ab3 \u0ab0\u0abe\u0a96\u0aa8\u0abe\u0ab0',Icons.elderly_outlined),
        _Svc('Babysitter','बेबीसिटर','\u0aac\u0ac7\u0aac\u0ac0\u0ab8\u0abf\u0a9f\u0ab0',Icons.child_care_outlined),
      ]),
  _Cat(en:'Events',hi:'इवेंट्स',gu:'\u0a87\u0ab5\u0ac7\u0aa8\u0acd\u0a9f',
      icon:Icons.celebration_rounded,
      color:Color(0xFFDB2777),bg:Color(0xFFFCE7F3),
      svcs:[
        _Svc('Photographer','फोटोग्राफर','\u0aab\u0acb\u0a9f\u0acb\u0a97\u0acd\u0ab0\u0abe\u0aab\u0ab0',Icons.camera_alt_outlined),
        _Svc('Videographer','वीडियोग्राफर','\u0ab5\u0abf\u0aa1\u0abf\u0a93\u0a97\u0acd\u0ab0\u0abe\u0aab\u0ab0',Icons.videocam_outlined),
        _Svc('DJ','डीजे','DJ',Icons.music_note_outlined),
        _Svc('Decoration','सजावट','\u0ab8\u0a9c\u0abe\u0ab5\u0a9f',Icons.auto_awesome_outlined),
        _Svc('Catering','कैटरिंग','\u0a95\u0ac7\u0a9f\u0ab0\u0abf\u0a82\u0a97',Icons.restaurant_outlined),
      ]),
  _Cat(en:'Construction',hi:'निर्माण',gu:'\u0aac\u0abe\u0a82\u0aa7\u0a95\u0abe\u0aae',
      icon:Icons.foundation_rounded,
      color:Color(0xFF92400E),bg:Color(0xFFFDE68A),
      svcs:[
        _Svc('Mason','राजमिस्त्री','\u0ab0\u0abe\u0a9c \u0aae\u0abf\u0ab8\u0acd\u0aa4\u0acd\u0ab0\u0ac0',Icons.foundation_outlined),
        _Svc('Interior Design','इंटीरियर डिज़ाइन','\u0a87\u0aa8\u0acd\u0a9f\u0abf\u0ab0\u0abf\u0aaf\u0ab0 \u0aa1\u0abf\u0a9d\u0abe\u0a87\u0aa8',Icons.design_services_outlined),
        _Svc('Tiles Worker','टाइल्स वर्कर','\u0a9f\u0abe\u0a87\u0ab2\u0acd\u0ab8 \u0ab5\u0ab0\u0acd\u0a95\u0ab0',Icons.grid_on_outlined),
        _Svc('Architect Help','आर्किटेक्ट सहायता','\u0a86\u0ab0\u0acd\u0a95\u0abf\u0a9f\u0ac7\u0a95\u0acd\u0a9f \u0ab8\u0ab9\u0abe\u0aaf',Icons.architecture_outlined),
        _Svc('Fabrication','फैब्रिकेशन','\u0aab\u0ac7\u0aac\u0acd\u0ab0\u0abf\u0a95\u0ac7\u0ab6\u0aa8',Icons.handyman_outlined),
      ]),
  _Cat(en:'Cleaning',hi:'सफाई',gu:'\u0ab8\u0aab\u0abe\u0a88',
      icon:Icons.cleaning_services_rounded,
      color:Color(0xFF0D9488),bg:Color(0xFFCCFBF1),
      svcs:[
        _Svc('Deep Cleaning','डीप क्लीनिंग','\u0aa1\u0ac0\u0aaa \u0a95\u0acd\u0ab2\u0abf\u0aa8\u0abf\u0a82\u0a97',Icons.clean_hands_outlined),
        _Svc('Bathroom Clean','बाथरूम सफाई','\u0aac\u0abe\u0aa5\u0ab0\u0ac2\u0aae \u0ab8\u0aab\u0abe\u0a88',Icons.bathroom_outlined),
        _Svc('Sofa Cleaning','सोफा सफाई','\u0ab8\u0acb\u0aab\u0abe \u0ab8\u0aab\u0abe\u0a88',Icons.chair_outlined),
        _Svc('Pest Control','कीट नियंत्रण','\u0a9c\u0ac0\u0ab5\u0abe\u0aa4 \u0aa8\u0abf\u0aaf\u0aa8\u0acd\u0aa4\u0acd\u0ab0\u0aa3',Icons.pest_control_outlined),
        _Svc('Water Tank','पानी की टंकी','\u0aaa\u0abe\u0aa3\u0ac0\u0aa8\u0ac0 \u0a9f\u0abe\u0a82\u0a95\u0ac0',Icons.water_outlined),
      ]),
  _Cat(en:'Professional',hi:'पेशेवर',gu:'\u0ab5\u0acd\u0aaf\u0ab5\u0ab8\u0abe\u0aaf\u0abf\u0a95',
      icon:Icons.gavel_rounded,
      color:Color(0xFF4338CA),bg:Color(0xFFE0E7FF),
      svcs:[
        _Svc('Lawyer Consult','वकील परामर्श','\u0ab5\u0a95\u0ac0\u0ab2 \u0ab8\u0ab2\u0abe\u0ab9',Icons.gavel_outlined),
        _Svc('CA / Tax Help','CA / टैक्स सहायता','CA / \u0a9f\u0ac7\u0a95\u0acd\u0ab8',Icons.calculate_outlined),
        _Svc('Insurance','बीमा','\u0ab5\u0ac0\u0aae\u0acb',Icons.shield_outlined),
        _Svc('Real Estate','रियल एस्टेट','\u0ab0\u0abf\u0aaf\u0ab2 \u0a8f\u0ab8\u0acd\u0a9f\u0ac7\u0a9f',Icons.apartment_outlined),
      ]),
  _Cat(en:'Outdoor',hi:'बाहरी सेवाएं',gu:'\u0a86\u0a89\u0a9f\u0aa1\u0acb\u0ab0',
      icon:Icons.park_rounded,
      color:Color(0xFF16A34A),bg:Color(0xFFDCFCE7),
      svcs:[
        _Svc('Gardener','माली','\u0aae\u0abe\u0ab3\u0ac0',Icons.yard_outlined),
        _Svc('Security Guard','सुरक्षा गार्ड','\u0ab8\u0ac1\u0ab0\u0a95\u0acd\u0ab7\u0abe \u0a97\u0abe\u0ab0\u0acd\u0aa1',Icons.security_outlined),
        _Svc('Driver on Hire','किराये पर ड्राइवर','\u0aad\u0abe\u0aa1\u0ac7 \u0aa1\u0acd\u0ab0\u0abe\u0a87\u0ab5\u0ab0',Icons.directions_car_outlined),
        _Svc('Scrap Collector','कबाड़ संग्रहकर्ता','\u0aad\u0a82\u0a97\u0abe\u0ab0 \u0ab8\u0a82\u0a97\u0acd\u0ab0\u0ab9',Icons.recycling_outlined),
      ]),
  _Cat(en:'Community',hi:'सामुदायिक',gu:'\u0ab8\u0abe\u0aae\u0ac1\u0aa6\u0abe\u0aaf\u0abf\u0a95',
      icon:Icons.volunteer_activism_rounded,
      color:Color(0xFF7C3AED),bg:Color(0xFFF3E8FF),
      svcs:[
        _Svc('Volunteer Help','स्वयंसेवक सहायता','\u0ab8\u0acd\u0ab5\u0ac8\u0a9a\u0acd\u0a9b\u0abf\u0a95 \u0ab8\u0ab9\u0abe\u0aaf',Icons.volunteer_activism_outlined),
        _Svc('Senior Support','वरिष्ठ नागरिक सहायता','\u0ab5\u0ac3\u0aa6\u0acd\u0aa7 \u0ab8\u0ab9\u0abe\u0aaf',Icons.elderly_outlined),
        _Svc('Student Helper','छात्र सहायक','\u0ab5\u0abf\u0aa6\u0acd\u0aaf\u0abe\u0ab0\u0acd\u0aa5\u0ac0 \u0ab8\u0ab9\u0abe\u0aaf\u0a95',Icons.school_outlined),
        _Svc('NGO Support','एनजीओ सहायता','NGO \u0ab8\u0ab9\u0abe\u0aaf',Icons.favorite_border),
      ]),
];

// ─── Screen ────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {

  // Controllers
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl  = TextEditingController();
  final _bioCtrl   = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _searchCtrl= TextEditingController();

  // Profile state
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final lp = context.read<LanguageProvider>();
    _lang = lp.isHindi ? 'hi' : 'en';
    _searchCtrl.addListener(
            () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim()));
    for (final c in [_nameCtrl, _phoneCtrl, _areaCtrl, _bioCtrl, _priceCtrl]) {
      c.addListener(() => setState(() {})); // keep completion bar live
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _areaCtrl, _bioCtrl,
      _priceCtrl, _searchCtrl]) { c.dispose(); }
    super.dispose();
  }

  // ── Data load ──────────────────────────────────────────────────────────────
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

  // ── Photo ──────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.pop(context);
    final xf = await ImagePicker().pickImage(
        source: source, imageQuality: 82, maxWidth: 900);
    if (xf == null || !mounted) return;
    setState(() { _photoFile = File(xf.path); _uploadingPhoto = true; });
    try {
      final uid = context.read<AuthProvider>().helper?.uid ?? 'tmp';
      final ref = FirebaseStorage.instance.ref('helpers/$uid/profile.jpg');
      await ref.putFile(_photoFile!,
          SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('helpers').doc(uid).update({'photoUrl': url});
      if (mounted) setState(() => _photoUrl = url);
    } catch (_) {
      // silent – photo stays local only
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? _cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20,
            MediaQuery.of(context).padding.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(_t(_lang,'Change Photo','फोटो बदलें','ફોટો બદલો'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _SheetOption(icon: Icons.camera_alt_rounded, color: _purple,
              label: _t(_lang,'Camera','कैमरा','કૅમેરો'),
              onTap: () => _pickPhoto(ImageSource.camera)),
          const SizedBox(height: 8),
          _SheetOption(icon: Icons.photo_library_rounded,
              color: const Color(0xFF0891B2),
              label: _t(_lang,'Gallery','गैलरी','ગૅલેરી'),
              onTap: () => _pickPhoto(ImageSource.gallery)),
        ]),
      ),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected.isEmpty) {
      _snack(_t(_lang,
          'Select at least one service',
          'कम से कम एक सेवा चुनें',
          'ઓછામાં ઓછી એક સેવા પસંદ કરો'), err: true);
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
        'skills':            _selected.toList(), // ← skills = services list
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
        _snack(_t(_lang,'Profile saved!','प्रोफ़ाइल सहेजी!','પ્રોફ\u0a87\u0ab2 \u0ab8\u0ac7\u0ab5 \u0aa5\u0aaf\u0ac1\u0a82!'));
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

  // ── Completion score ───────────────────────────────────────────────────────
  double get _pct {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final area  = _areaCtrl.text.trim();
    final bio   = _bioCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;

    // These 9 fields make up 95% of the score
    final checks = [
      name.isNotEmpty,
      phone.length == 10,
      area.isNotEmpty,
      bio.isNotEmpty,
      _expYears > 0,
      price > 0,
      _selected.isNotEmpty,
      _availDays.isNotEmpty,
      _availSlots.isNotEmpty,
    ];
    final baseScore = (checks.where((b) => b).length / checks.length) * 95;

    // Photo is worth 5%
    final photoScore = (_photoUrl != null || _photoFile != null) ? 5.0 : 0.0;

    return ((baseScore + photoScore) / 100).clamp(0.0, 1.0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _bgDark : _bgLight,
      body: Column(children: [
        _buildHeader(isDark),
        if (!_loaded)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: _purple, strokeWidth: 2)))
        else
          Expanded(child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(children: [
                _buildPhotoAndProgress(isDark),
                _buildLangSelector(isDark),
                _buildPersonalInfo(isDark),
                _buildWorkDetails(isDark),
                _buildServicesSection(isDark),
                const SizedBox(height: 12),
              ]),
            ),
          )),
        _buildStickyBar(isDark),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final helper = context.watch<AuthProvider>().helper;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
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
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(_lang,'Edit Profile','प्रोफ़ाइल संपादित करें',
                    '\u0aaa\u0acd\u0ab0\u0acb\u0aab\u0abe\u0a87\u0ab2 \u0ab8\u0a82\u0aaa\u0abe\u0aa6\u0abf\u0aa4'),
                style: const TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (helper != null)
                Text(helper.displayId,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.50), fontSize: 11)),
            ],
          )),
          // quick-save in header
          _saving
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.30)),
              ),
              child: Text(_t(_lang,'Save','सहेजें','સ\u0ac7\u0ab5'),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      )),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Photo + Completion
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhotoAndProgress(bool isDark) {
    final helper = context.watch<AuthProvider>().helper;
    final pct    = _pct;
    final pctInt = (pct * 100).round();
    final progColor = pct >= 0.8 ? const Color(0xFF059669) : _purple;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Row(children: [
        // ── Photo avatar ───────────────────────────────────────────────────
        GestureDetector(
          onTap: _showPhotoPicker,
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purpleLight,
                border: Border.all(color: _purple.op(0.35), width: 2.5),
                image: _photoFile != null
                    ? DecorationImage(
                    image: FileImage(_photoFile!), fit: BoxFit.cover)
                    : (_photoUrl != null
                    ? DecorationImage(
                    image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                    : null),
              ),
              child: (_photoFile == null && _photoUrl == null)
                  ? Center(child: Text(
                helper?.initials ?? 'SK',
                style: const TextStyle(color: _purpleDeep,
                    fontSize: 24, fontWeight: FontWeight.w900),
              ))
                  : (_uploadingPhoto
                  ? const Center(child: SizedBox(width: 28, height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _purple)))
                  : null),
            ),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF9333EA), Color(0xFF7C3AED)]),
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark ? _bgDark : Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 12),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        // ── Info + progress ────────────────────────────────────────────────
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              helper?.name.isNotEmpty == true
                  ? helper!.name
                  : _t(_lang,'Your Profile','आपकी प्रोफ़ाइल','\u0aa4\u0aae\u0abe\u0ab0\u0ac0 \u0aaa\u0acd\u0ab0\u0acb\u0aab\u0abe\u0a87\u0ab2'),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1F2937)),
            ),
            if (helper?.area.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 11,
                    color: isDark ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280)),
                const SizedBox(width: 3),
                Text(helper!.area,
                    style: TextStyle(fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 7,
                  backgroundColor: _purple.op(0.12),
                  valueColor: AlwaysStoppedAnimation(progColor),
                ),
              )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: progColor.op(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$pctInt%',
                    style: TextStyle(color: progColor, fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 5),
            Text(
              pct >= 1.0
                  ? _t(_lang,'Profile complete 🎉','प्रोफ़ाइल पूर्ण 🎉','\u0aaa\u0acd\u0ab0\u0acb\u0aab\u0abe\u0a87\u0ab2 \u0aaa\u0ac2\u0ab0\u0acd\u0aa3 🎉')
                  : _t(_lang,
                  '${10 - pctInt ~/ 10} more fields to boost visibility',
                  'अभी ${(10 - pct * 10).ceil()} क्षेत्र शेष हैं',
                  '\u0aac\u0abe\u0a95\u0ac0 \u0a95\u0abe\u0aae \u0aaa\u0ac2\u0ab0\u0ac1 \u0a95\u0ab0\u0acb'),
              style: TextStyle(fontSize: 11,
                  color: isDark ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280)),
            ),
          ],
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Language selector
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLangSelector(bool isDark) {
    return _Sec(
      isDark: isDark, margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.language_rounded, iconColor: const Color(0xFF0891B2),
      title: _t(_lang,'App Language','भाषा चुनें','\u0aad\u0abe\u0ab7\u0abe \u0aaa\u0ab8\u0a82\u0aa6 \u0a95\u0ab0\u0acb'),
      child: Row(children: [
        Expanded(child: _LangBtn(
          label: 'English', active: _lang == 'en', isDark: isDark,
          onTap: () => setState(() => _lang = 'en'),
        )),
        const SizedBox(width: 8),
        Expanded(child: _LangBtn(
          label: 'हिंदी', active: _lang == 'hi', isDark: isDark,
          onTap: () => setState(() => _lang = 'hi'),
        )),
        const SizedBox(width: 8),
        Expanded(child: _LangBtn(
          label: '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0',
          active: _lang == 'gu', isDark: isDark,
          onTap: () => setState(() => _lang = 'gu'),
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Personal Info
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPersonalInfo(bool isDark) {
    return _Sec(
      isDark: isDark, margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.person_outline_rounded, iconColor: _purple,
      title: _t(_lang,'Personal Information','व्यक्तिगत जानकारी','\u0ab5\u0acd\u0aaf\u0a95\u0acd\u0aa4\u0abf\u0a97\u0aa4 \u0aae\u0abe\u0ab9\u0abf\u0aa4\u0ac0'),
      child: Column(children: [
        _FF(ctrl:_nameCtrl, isDark:isDark,
            label:_t(_lang,'Full Name','पूरा नाम','\u0aaa\u0ac2\u0ab0\u0ac1\u0a82 \u0aa8\u0abe\u0aae'),
            hint:_t(_lang,'Ramesh Kumar','रमेश कुमार','\u0ab0\u0aae\u0ac7\u0ab6 \u0a95\u0ac1\u0aae\u0abe\u0ab0'),
            icon:Icons.badge_outlined, color:_purple,
            valid:(v) => v!.trim().isEmpty ? _t(_lang,'Required','आवश्यक','\u0a9c\u0ab0\u0ac2\u0ab0\u0ac0') : null),
        const SizedBox(height: 12),
        _FF(ctrl:_phoneCtrl, isDark:isDark,
            label:_t(_lang,'Mobile Number','मोबाइल नंबर','\u0aae\u0acb\u0aac\u0abe\u0a87\u0ab2 \u0aa8\u0a82\u0aac\u0ab0'),
            hint:'9876543210',
            icon:Icons.phone_android_rounded, color:const Color(0xFF0284C7),
            inputType:TextInputType.phone,
            formatters:[FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)],
            valid:(v) {
              if (v!.isEmpty) return _t(_lang,'Required','आवश्यक','\u0a9c\u0ab0\u0ac2\u0ab0\u0ac0');
              if (v.length != 10) return _t(_lang,'Enter 10 digits','10 अंक','10 \u0a85\u0a82\u0a95');
              return null;
            }),
        const SizedBox(height: 12),
        _FF(ctrl:_areaCtrl, isDark:isDark,
            label:_t(_lang,'Service Area','सेवा क्षेत्र','\u0ab8\u0ac7\u0ab5\u0abe \u0ab5\u0abf\u0ab8\u0acd\u0aa4\u0abe\u0ab0'),
            hint:_t(_lang,'Vesu, Surat','वेसू, सूरत','\u0ab5\u0ac7\u0ab8\u0ac1, \u0ab8\u0ac1\u0ab0\u0aa4'),
            icon:Icons.location_on_outlined, color:const Color(0xFF059669),
            valid:(v) => v!.trim().isEmpty ? _t(_lang,'Required','आवश्यक','\u0a9c\u0ab0\u0ac2\u0ab0\u0ac0') : null),
        const SizedBox(height: 12),
        _FF(ctrl:_bioCtrl, isDark:isDark, maxLines:3,
            label:_t(_lang,'About You','अपने बारे में','\u0aa4\u0aae\u0abe\u0ab0\u0abe \u0ab5\u0abf\u0ab6\u0ac7'),
            hint:_t(_lang,
                'I am a professional with 5 years experience...',
                'मैं 5 साल के अनुभव वाला पेशेवर हूं...',
                '\u0ab9\u0ac1\u0a82 5 \u0ab5\u0ab0\u0acd\u0ab7\u0aa8\u0abe \u0a85\u0aa8\u0ac1\u0aad\u0ab5 \u0ab8\u0abe\u0aa5\u0ac7...'),
            icon:Icons.info_outline_rounded, color:const Color(0xFF0891B2)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Work Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWorkDetails(bool isDark) {
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final txt = isDark ? Colors.white : const Color(0xFF111827);

    return _Sec(
      isDark: isDark, margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.work_outline_rounded, iconColor: const Color(0xFFD97706),
      title: _t(_lang,'Work Details','कार्य विवरण','\u0a95\u0abe\u0aae \u0ab5\u0abf\u0a97\u0aa4'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Experience slider ──────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.timeline_rounded, size: 13, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(_t(_lang,'Experience','अनुभव','\u0a85\u0aa8\u0ac1\u0aad\u0ab5'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub)),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _expYears == 0
                  ? _t(_lang,'Fresher','नया','\u0aa8\u0ab5\u0acb')
                  : '$_expYears ${_t(_lang,'yrs','वर्ष','\u0ab5\u0ab0\u0acd\u0ab7')}',
              style: const TextStyle(color: Color(0xFFD97706),
                  fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        const SizedBox(height: 2),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0','5','10','15','20','25','30'].map((v) =>
                Text(v, style: TextStyle(fontSize: 9, color: sub))).toList()),

        _divider(isDark),

        // ── Price per visit ────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(_t(_lang,'Price / Visit','प्रति विज़िट शुल्क',
              '\u0aaa\u0acd\u0ab0\u0aa4\u0abf \u0aae\u0ac1\u0ab2\u0abe\u0a95\u0abe\u0aa4 \u0a9a\u0abe\u0ab0\u0acd\u0a9c'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: txt, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '₹ 150',
              hintStyle: TextStyle(color: sub.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.currency_rupee_rounded,
                  color: Color(0xFF059669), size: 18),
              filled: true,
              fillColor: isDark ? const Color(0xFF23232F)
                  : const Color(0xFF059669).withOpacity(0.04),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? _borderDark
                    : const Color(0xFF059669).withOpacity(0.20)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDC2626))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              isDense: true,
            ),
          )),
          const SizedBox(width: 8),
          // Negotiable toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isNegotiable = !_isNegotiable);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: _isNegotiable ? const Color(0xFF059669)
                    : (isDark ? const Color(0xFF23232F) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isNegotiable ? const Color(0xFF059669)
                        : (isDark ? _borderDark : const Color(0xFFE5E7EB))),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.handshake_outlined, size: 14,
                    color: _isNegotiable ? Colors.white : sub),
                const SizedBox(width: 5),
                Text(_t(_lang,'Nego.','नेगो','\u0aa8\u0ac7\u0a97\u0acb'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _isNegotiable ? Colors.white : sub)),
              ]),
            ),
          ),
        ]),

        _divider(isDark),

        // ── Availability toggle ────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.toggle_on_rounded, size: 13, color: _purple),
          const SizedBox(width: 6),
          Expanded(child: Text(
            _t(_lang,'Available for Bookings','बुकिंग के लिए उपलब्ध',
                '\u0aac\u0ac1\u0a95\u0abf\u0a82\u0a97 \u0aae\u0abe\u0a9f\u0ac7 \u0a89\u0aaa\u0ab2\u0aac\u0acd\u0aa7'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub),
          )),
          Transform.scale(scale: 0.82, child: Switch(
            value: _isAvailable, activeColor: _purple,
            onChanged: (v) => setState(() => _isAvailable = v),
          )),
        ]),

        const SizedBox(height: 10),

        // ── Working days ───────────────────────────────────────────────────
        _subLabel(Icons.calendar_today_rounded,
            _t(_lang,'Working Days','कार्य दिवस','\u0a95\u0abe\u0aae\u0a95\u0abe\u0a9c\u0aa8\u0abe \u0aa6\u0abf\u0ab5\u0ab8'),
            const Color(0xFF0891B2), sub),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _kDays.map((d) {
          final sel = _availDays.contains(d);
          return _ToggleChip(
            label: _localDay(d), selected: sel,
            color: const Color(0xFF0891B2), isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => sel ? _availDays.remove(d) : _availDays.add(d));
            },
          );
        }).toList()),

        const SizedBox(height: 12),

        // ── Time slots ─────────────────────────────────────────────────────
        _subLabel(Icons.schedule_rounded,
            _t(_lang,'Working Hours','कार्य समय','\u0a95\u0abe\u0aae \u0ab8\u0aae\u0aaf'),
            const Color(0xFFDB2777), sub),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _kSlots.map((s) {
          final sel = _availSlots.contains(s);
          return _ToggleChip(
            label: _localSlot(s), selected: sel,
            leadingIcon: _slotIcon(s),
            color: const Color(0xFFDB2777), isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => sel ? _availSlots.remove(s) : _availSlots.add(s));
            },
          );
        }).toList()),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Services
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildServicesSection(bool isDark) {
    return _Sec(
      isDark: isDark, margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      icon: Icons.home_repair_service_rounded, iconColor: _purple,
      title: _t(_lang,'Services You Offer','आप कौन सी सेवाएं देते हैं?',
          '\u0aa4\u0aae\u0ac7 \u0a95\u0ac0 \u0ab8\u0ac7\u0ab5\u0abe\u0a93 \u0a86\u0aaa\u0acb \u0a9b\u0acb?'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _purple.op(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(
          '${_selected.length} ${_t(_lang,'selected','चुनी','\u0aaa\u0ab8\u0a82\u0aa6')}',
          style: const TextStyle(color: _purple, fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search bar
        _buildSearchBar(isDark),
        const SizedBox(height: 14),

        if (_searchQuery.isNotEmpty)
          _buildSearchResults(isDark)
        else ...[
          _buildCategoryGrid(isDark),
          if (_activeCatIdx != null) ...[
            const SizedBox(height: 12),
            _buildServicePanel(isDark),
          ],
        ],
      ]),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      controller: _searchCtrl,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF111827), fontSize: 13),
      decoration: InputDecoration(
        hintText: _t(_lang,'Search services...','सेवा खोजें...',
            '\u0ab8\u0ac7\u0ab5\u0abe \u0ab6\u0acb\u0aa7\u0acb...'),
        hintStyle: TextStyle(
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFFADB5BD),
            fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _purple, size: 18),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
          onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
          child: const Icon(Icons.close_rounded, size: 16, color: _purple),
        ) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF23232F) : _purple.op(0.04),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _purple.op(0.18))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _purple, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  // ── 12 Category grid (3 per row) ───────────────────────────────────────────
  Widget _buildCategoryGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8,
        mainAxisSpacing: 8, childAspectRatio: 1.0,
      ),
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
              color: active ? cat.color.op(0.12)
                  : (isDark ? const Color(0xFF23232F) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? cat.color
                    : (hasAny ? cat.color.op(0.40)
                    : (isDark ? _borderDark : _border)),
                width: (active || hasAny) ? 1.5 : 1.0,
              ),
              boxShadow: active ? [BoxShadow(
                  color: cat.color.op(0.22), blurRadius: 10,
                  offset: const Offset(0, 3))] : [],
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: active ? cat.color.op(0.18)
                              : (isDark ? cat.color.op(0.15) : cat.bg),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 19),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _t(_lang, cat.en, cat.hi, cat.gu),
                        textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: (active || hasAny)
                              ? FontWeight.w700 : FontWeight.w500,
                          color: active ? cat.color
                              : (isDark ? Colors.white : const Color(0xFF374151)),
                        ),
                      ),
                    ]),
              ),
              // Count badge
              if (hasAny)
                Positioned(top: 4, right: 4, child: Container(
                  width: 17, height: 17,
                  decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                  child: Center(child: Text('$count',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.bold))),
                )),
              // Expand arrow
              if (active)
                Positioned(bottom: 3, right: 3, child: Icon(
                    Icons.keyboard_arrow_up_rounded, size: 13,
                    color: cat.color.op(0.80))),
            ]),
          ),
        );
      },
    );
  }

  // ── Service panel (3-per-row chips) ────────────────────────────────────────
  Widget _buildServicePanel(bool isDark) {
    final cat      = _kCats[_activeCatIdx!];
    final allSel   = cat.svcs.every((s) => _selected.contains(s.en));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cat.color.op(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cat.color.op(0.28)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Panel header
        Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(
              color: isDark ? cat.color.op(0.20) : cat.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, color: cat.color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _t(_lang, cat.en, cat.hi, cat.gu),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: cat.color),
          )),
          // Select All / Deselect All
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (allSel) {
                  for (final s in cat.svcs) _selected.remove(s.en);
                } else {
                  for (final s in cat.svcs) _selected.add(s.en);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: allSel ? cat.color : cat.color.op(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(allSel ? Icons.deselect_rounded : Icons.select_all_rounded,
                    size: 11,
                    color: allSel ? Colors.white : cat.color),
                const SizedBox(width: 4),
                Text(
                  allSel
                      ? _t(_lang,'Clear All','सब हटाएं','\u0aac\u0aa7\u0abe \u0a95\u0abe\u0aa2\u0acb')
                      : _t(_lang,'Select All','सब चुनें','\u0aac\u0aa7\u0abe \u0aaa\u0ab8\u0a82\u0aa6'),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: allSel ? Colors.white : cat.color),
                ),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 10),

        // 3-per-row chip grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6,
            mainAxisSpacing: 6, childAspectRatio: 2.6,
          ),
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
                  color: sel ? cat.color
                      : (isDark ? const Color(0xFF1A1A24) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: sel ? cat.color : cat.color.op(0.28)),
                  boxShadow: sel ? [BoxShadow(color: cat.color.op(0.28),
                      blurRadius: 6, offset: const Offset(0, 2))] : [],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(sel ? Icons.check_rounded : svc.icon,
                          size: 11,
                          color: sel ? Colors.white : cat.color),
                      const SizedBox(width: 4),
                      Flexible(child: Text(
                        _t(_lang, svc.en, svc.hi, svc.gu),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white
                              : (isDark ? Colors.white.withOpacity(0.85) : cat.color),
                        ),
                      )),
                    ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  // ── Search results (3 per row) ─────────────────────────────────────────────
  Widget _buildSearchResults(bool isDark) {
    final results = <({int catIdx, _Svc svc})>[];
    for (var i = 0; i < _kCats.length; i++) {
      for (final svc in _kCats[i].svcs) {
        if (svc.en.toLowerCase().contains(_searchQuery) ||
            svc.hi.contains(_searchQuery) ||
            svc.gu.contains(_searchQuery)) {
          results.add((catIdx: i, svc: svc));
        }
      }
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Column(children: [
          Icon(Icons.search_off_rounded, size: 40,
              color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          Text(_t(_lang,'No services found','कोई सेवा नहीं मिली',
              '\u0a95\u0acb\u0a88 \u0ab8\u0ac7\u0ab5\u0abe \u0aae\u0ab3\u0ac0 \u0aa8\u0aa5\u0ac0'),
              style: TextStyle(color: isDark ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF))),
        ])),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${results.length} ${_t(_lang,'result(s)','परिणाम','\u0aaa\u0ab0\u0abf\u0aa3\u0abe\u0aae')}',
          style: TextStyle(fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 6,
          mainAxisSpacing: 6, childAspectRatio: 2.6,
        ),
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
                color: sel ? cat.color : (isDark ? _cardDark : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? cat.color : cat.color.op(0.28)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(sel ? Icons.check_rounded : svc.icon,
                    size: 11, color: sel ? Colors.white : cat.color),
                const SizedBox(width: 4),
                Flexible(child: Text(
                  _t(_lang, svc.en, svc.hi, svc.gu),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white
                          : (isDark ? Colors.white.withOpacity(0.85) : cat.color)),
                )),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION: Sticky Save Bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStickyBar(bool isDark) {
    final pct      = _pct;
    final progColor= pct >= 0.8 ? const Color(0xFF059669) : _purple;
    final botPad   = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, botPad + 12),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        border: Border(top: BorderSide(
            color: isDark ? _borderDark : _border)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(pct * 100).round()}% ${_t(_lang,'complete','पूर्ण','\u0aaa\u0ac2\u0ab0\u0acd\u0aa3')}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: progColor),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: _purple.op(0.12),
                valueColor: AlwaysStoppedAnimation(progColor),
              ),
            ),
          ],
        )),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 50, width: 158,
            decoration: BoxDecoration(
              gradient: _saving
                  ? const LinearGradient(
                  colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
                  : const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _saving ? [] : [BoxShadow(
                  color: _purple.op(0.38), blurRadius: 14,
                  offset: const Offset(0, 5))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_saving)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.save_alt_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 8),
              Text(
                _saving
                    ? _t(_lang,'Saving...','सहेज रहा...','\u0ab8\u0ac7\u0ab5 \u0aa5\u0abe\u0aaf \u0a9b\u0ac7...')
                    : _t(_lang,'Save Changes','सहेजें','\u0ab8\u0ac7\u0ab5 \u0a95\u0ab0\u0acb'),
                style: const TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────
  Widget _divider(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1,
        color: isDark ? _borderDark : const Color(0xFFEEEAF8)),
  );

  Widget _subLabel(IconData icon, String text, Color color, Color sub) =>
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sub)),
      ]);

  String _localDay(String d) {
    const en = {'Mon':'Mon','Tue':'Tue','Wed':'Wed','Thu':'Thu',
      'Fri':'Fri','Sat':'Sat','Sun':'Sun'};
    const hi = {'Mon':'सोम','Tue':'मंग','Wed':'बुध','Thu':'गुरु',
      'Fri':'शुक्र','Sat':'शनि','Sun':'रवि'};
    const gu = {'Mon':'\u0ab8\u0acb\u0aae','Tue':'\u0aae\u0a82\u0a97',
      'Wed':'\u0aac\u0ac1\u0aa7','Thu':'\u0a97\u0ac1\u0ab0\u0ac1',
      'Fri':'\u0ab6\u0ac1\u0a95\u0acd\u0ab0','Sat':'\u0ab6\u0aa8\u0abf',
      'Sun':'\u0ab0\u0ab5\u0abf'};
    if (_lang == 'hi') return hi[d] ?? d;
    if (_lang == 'gu') return gu[d] ?? d;
    return en[d] ?? d;
  }

  String _localSlot(String s) {
    switch (s) {
      case 'Morning':   return _t(_lang,'Morning','सुबह','\u0ab8\u0ab5\u0abe\u0ab0');
      case 'Afternoon': return _t(_lang,'Afternoon','दोपहर','\u0aac\u0aaa\u0acb\u0ab0');
      case 'Evening':   return _t(_lang,'Evening','शाम','\u0ab8\u0abe\u0a82\u0a9c');
      case 'Night':     return _t(_lang,'Night','रात','\u0ab0\u0abe\u0aa4');
      default:          return s;
    }
  }

  IconData _slotIcon(String s) {
    switch (s) {
      case 'Morning':   return Icons.wb_sunny_outlined;
      case 'Afternoon': return Icons.wb_cloudy_outlined;
      case 'Evening':   return Icons.nights_stay_outlined;
      case 'Night':     return Icons.bedtime_outlined;
      default:          return Icons.schedule_rounded;
    }
  }

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
    color: isDark ? _cardDark : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: isDark ? _borderDark : _border),
    boxShadow: [BoxShadow(
        color: _purple.op(isDark ? 0.08 : 0.05),
        blurRadius: 16, offset: const Offset(0, 4))],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Section card ──────────────────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? margin;

  const _Sec({
    required this.isDark, required this.icon,
    required this.iconColor, required this.title,
    required this.child, this.trailing, this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? _borderDark : _border),
        boxShadow: [BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.08 : 0.05),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header strip
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(
                color: isDark ? _borderDark : _border)),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ))),
            if (trailing != null) trailing!,
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

// ─── Form field ────────────────────────────────────────────────────────────────
class _FF extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final String label, hint;
  final IconData icon;
  final Color color;
  final int maxLines;
  final TextInputType? inputType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? valid;

  const _FF({
    required this.ctrl, required this.isDark,
    required this.label, required this.hint,
    required this.icon, required this.color,
    this.maxLines = 1, this.inputType, this.formatters, this.valid,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor  = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: subColor)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, maxLines: maxLines,
        keyboardType: inputType, inputFormatters: formatters,
        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
              fontSize: 13),
          prefixIcon: maxLines == 1
              ? Icon(icon, color: color, size: 16) : null,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: maxLines > 1 ? 12 : 11),
          isDense: true, filled: true,
          fillColor: isDark ? const Color(0xFF23232F)
              : color.withOpacity(0.03),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? _borderDark : color.withOpacity(0.18)),
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
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
        ),
        validator: valid,
      ),
    ]);
  }
}

// ─── Language button ────────────────────────────────────────────────────────────
class _LangBtn extends StatelessWidget {
  final String label;
  final bool active, isDark;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.active,
    required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: active ? const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF9333EA)]) : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active
                ? Colors.transparent
                : (isDark ? _borderDark : _border)),
      ),
      child: Center(child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? Colors.white
            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
      ))),
    ),
  );
}

// ─── Toggle chip (days / slots) ────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected, isDark;
  final Color color;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  const _ToggleChip({
    required this.label, required this.selected, required this.isDark,
    required this.color, required this.onTap, this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? color : (isDark ? _borderDark : const Color(0xFFE5E7EB))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 11,
              color: selected ? Colors.white
                  : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: selected ? Colors.white
              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        )),
      ]),
    ),
  );
}

// ─── Photo picker sheet option ─────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.color,
    required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, size: 12,
            color: color.withOpacity(0.45)),
      ]),
    ),
  );
}