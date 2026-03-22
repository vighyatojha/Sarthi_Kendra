// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/helper_model.dart';

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

  final Set<String> _selectedServices = {};
  bool _isSaving = false;

  static const List<String> _allServices = [
    'Plumber', 'Electrician', 'AC Repair', 'Carpenter',
    'Painter', 'House Cleaning', 'Appliance Repair',
    'Pest Control', 'Security Guard', 'Driver',
    'Cook / Chef', 'Gardener', 'Tutor',
  ];

  @override
  void initState() {
    super.initState();
    final helper = context.read<AuthProvider>().helper;
    if (helper != null) {
      _nameCtrl.text  = helper.name;
      _phoneCtrl.text = helper.phone;
      _areaCtrl.text  = helper.area;
      _selectedServices.addAll(helper.services);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final auth    = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name:     _nameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      area:     _areaCtrl.text.trim(),
      services: _selectedServices.toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _snack('Profile updated successfully!');
      Navigator.pop(context);
    } else {
      _snack(auth.errorMessage ?? 'Update failed.', error: true);
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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final helper  = context.watch<AuthProvider>().helper;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(children: [
        _buildHeader(isDark, helper),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(children: [
                // ── Personal Info ─────────────────────────────
                _SectionCard(
                  title: 'Personal Info',
                  isDark: isDark,
                  child: Column(children: [
                    _field(
                        ctrl: _nameCtrl, label: 'Full Name',
                        hint: 'Your name', icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        validator: (v) => v!.trim().isEmpty ? 'Name is required' : null),
                    const SizedBox(height: 14),
                    _field(
                        ctrl: _phoneCtrl, label: 'Mobile Number',
                        hint: '9876543210', icon: Icons.phone_android_rounded,
                        isDark: isDark,
                        inputType: TextInputType.phone,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v!.isEmpty)     return 'Phone is required';
                          if (v.length != 10) return 'Enter 10-digit number';
                          return null;
                        }),
                    const SizedBox(height: 14),
                    _field(
                        ctrl: _areaCtrl, label: 'Service Area',
                        hint: 'e.g. Vesu, Surat', icon: Icons.location_on_outlined,
                        isDark: isDark,
                        validator: (v) => v!.trim().isEmpty ? 'Area is required' : null),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Services ──────────────────────────────────
                _SectionCard(
                  title: 'Services Offered',
                  isDark: isDark,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.brandPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_selectedServices.length} selected',
                        style: const TextStyle(
                            color: AppColors.brandPurple,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _allServices.map((svc) {
                      final sel = _selectedServices.contains(svc);
                      return GestureDetector(
                        onTap: () => setState(() =>
                        sel ? _selectedServices.remove(svc) : _selectedServices.add(svc)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.brandPurple
                                : (isDark ? AppColors.surfaceDark : AppColors.bgLight),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: sel
                                    ? AppColors.brandPurple
                                    : (isDark ? AppColors.borderDark : AppColors.borderLight)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (sel) ...[
                              const Icon(Icons.check_circle_rounded,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(svc, style: TextStyle(
                                color:      sel ? Colors.white
                                    : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                                fontSize:   13,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Save button ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(bool isDark, HelperModel? helper) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Profile', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          if (helper != null)
            Text(helper.displayId, style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ])),
        // Avatar
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.15),
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Center(child: Text(
              helper?.initials ?? 'SK',
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w700))),
        ),
      ]),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label, required String hint,
    required IconData icon, required bool isDark,
    TextInputType? inputType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: AppColors.brandPurple),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
            fontSize:   13, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 7),
      TextFormField(
        controller:      ctrl,
        keyboardType:    inputType,
        inputFormatters: formatters,
        style: TextStyle(
            color:      isDark ? Colors.white : AppColors.textDarkLight,
            fontSize:   15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: TextStyle(
              color:    isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
              fontSize: 15, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: AppColors.brandPurple, size: 20),
        ),
        validator: validator,
      ),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;
  final Widget? trailing;
  const _SectionCard({
    required this.title, required this.child,
    required this.isDark, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   15, fontWeight: FontWeight.w700)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}