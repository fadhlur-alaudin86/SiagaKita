import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/user_service.dart';
import '../../core/constants/relation_constants.dart';

class EditProfileScreen extends StatefulWidget {
  final String accessToken;
  const EditProfileScreen({super.key, required this.accessToken});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isSaving = false;
  // Informasi Pribadi
  final _fullNameCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _placeOfBirthCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Data Medis
  final _bloodTypeCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();

  // Contacts state
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    final user = UserModel.currentUser.value;

    _fullNameCtrl.text = user.name;
    _nikCtrl.text = user.nik ?? '';
    _phoneCtrl.text = user.phoneNumber ?? '';
    _placeOfBirthCtrl.text = user.placeOfBirth ?? '';
    _bioCtrl.text = user.bio ?? '';

    final medData = user.medicalData ?? {};
    _addressCtrl.text = medData['address'] ?? '';
    _bloodTypeCtrl.text = medData['blood_type'] ?? '';
    _weightCtrl.text = medData['weight']?.toString() ?? '';
    _heightCtrl.text = medData['height']?.toString() ?? '';
    _allergiesCtrl.text = medData['allergies'] ?? '';
    _medicalHistoryCtrl.text = medData['medical_history'] ?? '';

    // Create a mutable copy of contacts for the state
    if (user.emergencyContacts != null) {
      _contacts = List<Map<String, dynamic>>.from(
        user.emergencyContacts!.map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nikCtrl.dispose();
    _phoneCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _bioCtrl.dispose();
    _addressCtrl.dispose();
    _bloodTypeCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    super.dispose();
  }

  void _addContact() {
    setState(() {
      _contacts.add({'name': '', 'relation': '', 'phone': ''});
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  Future<void> _handleRefresh() async {
    await UserService.refreshCurrentUser(widget.accessToken);
    if (!mounted) return;

    final user = UserModel.currentUser.value;
    setState(() {
      _fullNameCtrl.text = user.name;
      _nikCtrl.text = user.nik ?? '';
      _phoneCtrl.text = user.phoneNumber ?? '';
      _placeOfBirthCtrl.text = user.placeOfBirth ?? '';
      _bioCtrl.text = user.bio ?? '';

      final medData = user.medicalData ?? {};
      _addressCtrl.text = medData['address'] ?? '';
      _bloodTypeCtrl.text = medData['blood_type'] ?? '';
      _weightCtrl.text = medData['weight']?.toString() ?? '';
      _heightCtrl.text = medData['height']?.toString() ?? '';
      _allergiesCtrl.text = medData['allergies'] ?? '';
      _medicalHistoryCtrl.text = medData['medical_history'] ?? '';

      if (user.emergencyContacts != null) {
        _contacts = List<Map<String, dynamic>>.from(
          user.emergencyContacts!.map((e) => Map<String, dynamic>.from(e)),
        );
      }
    });
  }

  Future<void> _saveData() async {
    await _doSaveProfile();
  }

  /// Lakukan penyimpanan profil ke server.
  Future<void> _doSaveProfile() async {
    // Validate contacts
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      if ((c['name']?.isEmpty ?? true) ||
          (c['relation']?.isEmpty ?? true) ||
          (c['phone']?.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'Form kontak baris ke'.tr(context)}-${i + 1} ${'belum lengkap!'.tr(context)}',
            ),
          ),
        );
        return;
      }
      if ((c['phone']?.length ?? 0) < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'Nomor pada kontak ke'.tr(context)}-${i + 1} ${'minimal 10 digit!'.tr(context)}',
            ),
          ),
        );
        return;
      }
    }

    final user = UserModel.currentUser.value;

    setState(() => _isSaving = true);

    // Simpan referensi SEBELUM await agar tidak pakai BuildContext stale
    // (mencegah '_dependents.isEmpty' assertion error setelah pop)
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updatedMedData = Map<String, dynamic>.from(user.medicalData ?? {});
      updatedMedData['address'] = _addressCtrl.text;
      updatedMedData['blood_type'] = _bloodTypeCtrl.text;
      updatedMedData['weight'] = _weightCtrl.text;
      updatedMedData['height'] = _heightCtrl.text;
      updatedMedData['allergies'] = _allergiesCtrl.text;
      updatedMedData['medical_history'] = _medicalHistoryCtrl.text;

      final updatedUser = user.copyWith(
        name: _fullNameCtrl.text,
        nik: _nikCtrl.text.isEmpty ? null : _nikCtrl.text,
        phoneNumber: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
        placeOfBirth: _placeOfBirthCtrl.text.isEmpty
            ? null
            : _placeOfBirthCtrl.text,
        bio: _bioCtrl.text,
        medicalData: updatedMedData,
        emergencyContacts: _contacts.isEmpty ? null : _contacts,
      );

      final returnedUser = await UserService.updateProfile(
        widget.accessToken,
        updatedUser,
      );

      if (!mounted) return;

      // Pop DULU sebelum update ValueNotifier.
      // Jika ValueNotifier diupdate sebelum pop, ia memicu rebuild seluruh
      // widget tree di frame yang sama -> '_dependents.isEmpty' assertion error.
      navigator.pop();

      // Update model SETELAH pop agar widget tree sudah clean
      UserModel.currentUser.value = returnedUser;

      messenger.showSnackBar(
        SnackBar(content: Text('Profil berhasil diperbarui.'.tr(context))),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${'Gagal memperbarui profil'.tr(context)}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic Colors based on theme
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;
    final borderColor = isDark
        ? Colors.grey.withValues(alpha: 0.3)
        : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'EDIT PROFIL'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. INFORMASI PRIBADI & DOMISILI
              Text(
                'INFORMASI PRIBADI'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: cardColor,
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        maxLength: 255,
                        decoration: InputDecoration(
                          labelText: 'Domisili Lengkap'.tr(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        maxLength: 255,
                        decoration: InputDecoration(
                          labelText: 'Bio Singkat'.tr(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 2. DATA MEDIS & KEAMANAN
              Text(
                'DATA MEDIS & KEAMANAN'.tr(context),
                style: TextStyle(
                  color: isDark ? Colors.red.shade300 : Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.red.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.red.shade100,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            [
                              'A+',
                              'A-',
                              'B+',
                              'B-',
                              'AB+',
                              'AB-',
                              'O+',
                              'O-',
                              'Belum Tahu',
                            ].contains(_bloodTypeCtrl.text)
                            ? _bloodTypeCtrl.text
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Golongan Darah'.tr(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            [
                                  'A+',
                                  'A-',
                                  'B+',
                                  'B-',
                                  'AB+',
                                  'AB-',
                                  'O+',
                                  'O-',
                                  'Belum Tahu'.tr(context),
                                ]
                                .map(
                                  (val) => DropdownMenuItem(
                                    value: val,
                                    child: Text(val),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) _bloodTypeCtrl.text = val;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weightCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              decoration: InputDecoration(
                                labelText: 'Berat (kg)'.tr(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _heightCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              decoration: InputDecoration(
                                labelText: 'Tinggi (cm)'.tr(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _allergiesCtrl,
                        maxLength: 255,
                        decoration: InputDecoration(
                          labelText: 'Alergi Utama (Opsional)'.tr(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _medicalHistoryCtrl,
                        maxLength: 255,
                        decoration: InputDecoration(
                          labelText: 'Riwayat Penyakit (Opsional)'.tr(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 3. KONTAK DARURAT
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KONTAK DARURAT'.tr(context),
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.add, color: Colors.orange, size: 18),
                    label: Text(
                      'Tambah'.tr(context),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Belum ada kontak darurat.'.tr(context),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                )
              else
                ...List.generate(_contacts.length, (index) {
                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: isDark ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'Kontak Darurat'.tr(context)} #${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeContact(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: _contacts[index]['name'],
                            onChanged: (val) => _contacts[index]['name'] = val,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: 'Nama Lengkap'.tr(context),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: _contacts[index]['phone'],
                            onChanged: (val) =>
                                _contacts[index]['phone'] = val,
                            keyboardType: TextInputType.phone,
                            maxLength: 20,
                            decoration: InputDecoration(
                              labelText: 'No Hp'.tr(context),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Hubungan'.tr(context),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: EmergencyRelation.all.map((rel) {
                              final currentRel = _contacts[index]['relation'];
                              final isSelected = currentRel == rel ||
                                  (rel == EmergencyRelation.other &&
                                      currentRel != null &&
                                      currentRel.isNotEmpty &&
                                      !EmergencyRelation.all.contains(currentRel));
                              return ChoiceChip(
                                label: Text(
                                  EmergencyRelation.getLabel(rel, context),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.orange
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _contacts[index]['relation'] = rel;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _isSaving ? null : _saveData,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Simpan Perubahan'.tr(context),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
