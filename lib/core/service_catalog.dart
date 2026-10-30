// lib/core/service_catalog.dart
// Shared service catalog. This file is IDENTICAL in Trouble Sarthi and
// Sarthi Kendra, and matches functions/src/catalog.ts. Never rename an `id`:
// requests, helper skills and bookings store it.

import 'package:flutter/material.dart';

class ServiceSubcategory {
  final String id;
  final String categoryId;
  final String en, hi, gu;
  final IconData icon;
  final List<String> aliases;
  const ServiceSubcategory(this.id, this.categoryId, this.en, this.hi, this.gu, this.icon, [this.aliases = const []]);

  /// Name in the given language code ('en' | 'hi' | 'gu').
  String name(String lang) => lang == 'hi' ? hi : lang == 'gu' ? gu : en;
}

class ServiceCategory {
  final String id;
  final String en, hi, gu;
  /// false = emergency services: no pitching, route to emergency numbers.
  final bool biddable;
  final List<ServiceSubcategory> subs;
  const ServiceCategory(this.id, this.en, this.hi, this.gu, this.biddable, this.subs);
  String name(String lang) => lang == 'hi' ? hi : lang == 'gu' ? gu : en;
}

class ServiceCatalog {
  ServiceCatalog._();

  static const List<ServiceCategory> categories = [
    ServiceCategory('home_services', "Home Services", "घर सेवाएं", "ઘર સેવા", true, [
      ServiceSubcategory('plumber', 'home_services', "Plumber", "प्लंबर", "પ્લમ્બર", Icons.water_drop_outlined),
      ServiceSubcategory('electrician', 'home_services', "Electrician", "इलेक्ट्रीशियन", "ઇલેક્ટ્રિશિયન", Icons.bolt_outlined),
      ServiceSubcategory('carpenter', 'home_services', "Carpenter", "बढ़ई", "સુથાર", Icons.carpenter),
      ServiceSubcategory('ac_repair', 'home_services', "AC Repair", "एसी रिपेयर", "AC રિપેર", Icons.ac_unit_outlined),
      ServiceSubcategory('ro_repair', 'home_services', "RO Repair", "आरओ रिपेयर", "RO રિપેર", Icons.water_outlined),
      ServiceSubcategory('appliance_repair', 'home_services', "Appliance Repair", "अप्लायंस रिपेयर", "ઉપકરણ રિપેર", Icons.kitchen_outlined),
      ServiceSubcategory('painter', 'home_services', "Painter", "पेंटर", "પેઇન્ટર", Icons.format_paint_outlined),
      ServiceSubcategory('cleaner', 'home_services', "Cleaner", "सफाईकर्मी", "સફાઈ કર્મી", Icons.cleaning_services_outlined),
    ]),
    ServiceCategory('vehicle_services', "Vehicle Services", "वाहन सेवाएं", "વાહન સેવા", true, [
      ServiceSubcategory('car_mechanic', 'vehicle_services', "Car Mechanic", "कार मैकेनिक", "કાર મિકેનિક", Icons.car_repair),
      ServiceSubcategory('bike_mechanic', 'vehicle_services', "Bike Mechanic", "बाइक मैकेनिक", "બાઇક મિકેનિક", Icons.two_wheeler),
      ServiceSubcategory('towing_service', 'vehicle_services', "Towing Service", "टोइंग सेवा", "ટોઇંગ સેવા", Icons.local_shipping_outlined),
      ServiceSubcategory('puncture_repair', 'vehicle_services', "Puncture Repair", "पंचर रिपेयर", "પંચર રિપેર", Icons.tire_repair),
      ServiceSubcategory('car_wash', 'vehicle_services', "Car Wash", "कार वॉश", "કાર વૉશ", Icons.local_car_wash_outlined),
      ServiceSubcategory('battery_jump_start', 'vehicle_services', "Battery Jump Start", "बैटरी जम्प", "બૅટ્રી જમ્પ", Icons.battery_charging_full_outlined),
    ]),
    ServiceCategory('emergency', "Emergency", "आपातकाल", "કટોકટી", false, [
      ServiceSubcategory('ambulance', 'emergency', "Ambulance", "एम्बुलेंस", "એમ્બ્યુલન્સ", Icons.local_hospital_outlined),
      ServiceSubcategory('first_aid', 'emergency', "First Aid", "प्राथमिक चिकित्सा", "પ્રાથમિક સારવાર", Icons.medical_services_outlined),
      ServiceSubcategory('blood_donor', 'emergency', "Blood Donor", "रक्तदाता", "રક્ત દાતા", Icons.bloodtype_outlined),
      ServiceSubcategory('fire_help', 'emergency', "Fire Help", "अग्नि सहायता", "અગ્નિ સહાય", Icons.local_fire_department_outlined),
      ServiceSubcategory('disaster_support', 'emergency', "Disaster Support", "आपदा सहायता", "આફત સહાય", Icons.crisis_alert_outlined),
      ServiceSubcategory('mid_night_vehicle_emergency', 'emergency', "Mid-Night Vehicle Emergency", "मध्यरात्रि वाहन", "મધ્ય-રાત્રિ વાહન", Icons.directions_car_outlined),
    ]),
    ServiceCategory('delivery_pickup', "Delivery & Pickup", "डिलीवरी", "ડિલિવરી", true, [
      ServiceSubcategory('parcel_pickup', 'delivery_pickup', "Parcel Pickup", "पार्सल पिकअप", "પાર્સલ પિકઅપ", Icons.local_post_office_outlined),
      ServiceSubcategory('grocery_delivery', 'delivery_pickup', "Grocery Delivery", "किराना डिलीवरी", "કરિયાણા ડિલિવરી", Icons.shopping_basket_outlined),
      ServiceSubcategory('medicine_delivery', 'delivery_pickup', "Medicine Delivery", "दवा डिलीवरी", "દવા ડિલિવરી", Icons.medication_outlined),
      ServiceSubcategory('document_courier', 'delivery_pickup', "Document Courier", "दस्तावेज़ कूरियर", "ડૉક્યૂ. કૂરિયર", Icons.description_outlined),
      ServiceSubcategory('local_shifting', 'delivery_pickup', "Local Shifting", "लोकल शिफ्टिंग", "સ્થાનિક શિફ્ટિંગ", Icons.move_to_inbox_outlined),
    ]),
    ServiceCategory('technical_services', "Technical Services", "तकनीकी", "ટેકનિકલ", true, [
      ServiceSubcategory('mobile_repair', 'technical_services', "Mobile Repair", "मोबाइल रिपेयर", "મોબાઇલ રિપેર", Icons.phone_android_outlined),
      ServiceSubcategory('laptop_repair', 'technical_services', "Laptop Repair", "लैपटॉप रिपेयर", "લેપટોપ રિપેર", Icons.laptop_outlined),
      ServiceSubcategory('cctv_install', 'technical_services', "CCTV Install", "सीसीटीवी इंस्टॉल", "CCTV ઇન્સ્ટોલ", Icons.videocam_outlined),
      ServiceSubcategory('wifi_install', 'technical_services', "WiFi Install", "वाईफाई इंस्टॉल", "WiFi ઇન્સ્ટોલ", Icons.wifi_outlined),
      ServiceSubcategory('software_help', 'technical_services', "Software Help", "सॉफ्टवेयर सहायता", "સૉફ્ટ. સહાય", Icons.computer_outlined),
    ]),
    ServiceCategory('personal_assistance', "Personal Assistance", "व्यक्तिगत सहायता", "વ્યક્તિગત", true, [
      ServiceSubcategory('home_tutor', 'personal_assistance', "Home Tutor", "होम ट्यूटर", "હોમ ટ્યૂટર", Icons.menu_book_outlined),
      ServiceSubcategory('fitness_trainer', 'personal_assistance', "Fitness Trainer", "फिटनेस ट्रेनर", "ફિટ. ટ્રેઇનર", Icons.fitness_center_outlined),
      ServiceSubcategory('yoga_instructor', 'personal_assistance', "Yoga Instructor", "योग प्रशिक्षक", "યોગ ઇન્સ.", Icons.self_improvement_outlined),
      ServiceSubcategory('caretaker', 'personal_assistance', "Caretaker", "देखभाल करने वाला", "કૅરટૅકર", Icons.volunteer_activism_outlined),
      ServiceSubcategory('babysitter', 'personal_assistance', "Babysitter", "बेबीसिटर", "બૅબીસિટર", Icons.child_care_outlined),
    ]),
    ServiceCategory('events_occasions', "Events & Occasions", "इवेंट्स", "ઇવેન્ટ", true, [
      ServiceSubcategory('photographer', 'events_occasions', "Photographer", "फोटोग्राफर", "ફોટોગ્રાફર", Icons.camera_alt_outlined),
      ServiceSubcategory('videographer', 'events_occasions', "Videographer", "वीडियोग्राफर", "વિડિઓ.", Icons.videocam_outlined),
      ServiceSubcategory('dj', 'events_occasions', "DJ", "डीजे", "DJ", Icons.music_note_outlined),
      ServiceSubcategory('decoration', 'events_occasions', "Decoration", "सजावट", "સજાવટ", Icons.auto_awesome_outlined),
      ServiceSubcategory('catering', 'events_occasions', "Catering", "कैटरिंग", "કેટરિંગ", Icons.restaurant_outlined),
    ]),
    ServiceCategory('construction', "Construction", "निर्माण", "બાંધકામ", true, [
      ServiceSubcategory('mason', 'construction', "Mason", "राजमिस्त्री", "કડિયો", Icons.foundation_outlined),
      ServiceSubcategory('interior_design', 'construction', "Interior Design", "इंटीरियर डिज़ाइन", "ઇન્ટ. ડિઝાઇન", Icons.design_services_outlined),
      ServiceSubcategory('tiles_worker', 'construction', "Tiles Worker", "टाइल्स मजदूर", "ટાઇલ્સ", Icons.grid_on_outlined),
      ServiceSubcategory('architect_help', 'construction', "Architect Help", "आर्किटेक्ट", "આર્કિ.", Icons.architecture_outlined),
      ServiceSubcategory('fabrication', 'construction', "Fabrication", "फैब्रिकेशन", "ફૅબ્રિ.", Icons.handyman_outlined),
    ]),
    ServiceCategory('cleaning', "Cleaning", "सफाई", "સફાઈ", true, [
      ServiceSubcategory('deep_cleaning', 'cleaning', "Deep Cleaning", "डीप क्लीनिंग", "ડીપ ક્લિ.", Icons.clean_hands_outlined),
      ServiceSubcategory('bathroom_clean', 'cleaning', "Bathroom Clean", "बाथरूम सफाई", "બાથ. સફાઈ", Icons.bathroom_outlined),
      ServiceSubcategory('sofa_cleaning', 'cleaning', "Sofa Cleaning", "सोफा सफाई", "સોફા ક્લિ.", Icons.chair_outlined),
      ServiceSubcategory('pest_control', 'cleaning', "Pest Control", "कीट नियंत्रण", "જીવાત", Icons.pest_control_outlined),
      ServiceSubcategory('water_tank_cleaning', 'cleaning', "Water Tank Cleaning", "टैंक सफाई", "ટૅન્ક ક્લિ.", Icons.water_damage_outlined, ["Water Tank"]),
    ]),
    ServiceCategory('professional', "Professional", "पेशेवर सेवाएं", "વ્યાવ. સેવા", true, [
      ServiceSubcategory('lawyer_consult', 'professional', "Lawyer Consult", "वकील परामर्श", "વકીલ.", Icons.gavel_outlined),
      ServiceSubcategory('ca_tax_help', 'professional', "CA / Tax Help", "CA / टैक्स", "CA / ટૅક્સ", Icons.account_balance_outlined),
      ServiceSubcategory('insurance', 'professional', "Insurance", "बीमा", "વીમો", Icons.shield_outlined),
      ServiceSubcategory('real_estate', 'professional', "Real Estate", "रियल एस्टेट", "રિ. એસ.", Icons.apartment_outlined),
    ]),
    ServiceCategory('outdoor_more', "Outdoor & More", "बाहरी सेवाएं", "આઉટડોર", true, [
      ServiceSubcategory('gardener', 'outdoor_more', "Gardener", "माली", "માળી", Icons.yard_outlined),
      ServiceSubcategory('security_guard', 'outdoor_more', "Security Guard", "सुरक्षा गार्ड", "સુ. ગાર્ડ", Icons.security_outlined),
      ServiceSubcategory('driver_on_hire', 'outdoor_more', "Driver on Hire", "किराये पर ड्राइवर", "ભાડે ડ્રાઇ.", Icons.directions_car_outlined),
      ServiceSubcategory('scrap_collector', 'outdoor_more', "Scrap Collector", "कबाड़ीवाला", "ભંગાર.", Icons.recycling_outlined),
    ]),
    ServiceCategory('community_help', "Community Help", "सामुदायिक सहायता", "સમુ. સહાય", true, [
      ServiceSubcategory('volunteer_help', 'community_help', "Volunteer Help", "स्वयंसेवी", "સ્વૈ. સહા.", Icons.favorite_outline_rounded),
      ServiceSubcategory('senior_support', 'community_help', "Senior Support", "बुजुर्ग सहायता", "વૃ. સહાય", Icons.elderly_outlined),
      ServiceSubcategory('student_helper', 'community_help', "Student Helper", "छात्र सहायक", "વિ. સહ.", Icons.school_outlined),
      ServiceSubcategory('ngo_support', 'community_help', "NGO Support", "एनजीओ सहायता", "NGO સહ.", Icons.handshake_outlined),
    ]),
  ];

  static final Map<String, ServiceSubcategory> _byId = {
    for (final c in categories) for (final s in c.subs) s.id: s,
  };

  static final Map<String, ServiceSubcategory> _byName = {
    for (final c in categories)
      for (final s in c.subs)
        for (final n in [s.en, s.id, ...s.aliases]) n.trim().toLowerCase(): s,
  };

  static ServiceSubcategory? byId(String id) => _byId[id];

  /// Accepts an id or a legacy English name ("Plumber", "Water Tank").
  static ServiceSubcategory? lookup(String nameOrId) => _byName[nameOrId.trim().toLowerCase()];

  static ServiceCategory? categoryOf(String subId) {
    for (final c in categories) {
      if (c.subs.any((s) => s.id == subId)) return c;
    }
    return null;
  }
}