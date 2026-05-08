import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String accessToken;
  const EditProfileScreen({super.key, required this.accessToken});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isSaving = false;
  // Informasi Pribadi
  final _birthDateCtrl = TextEditingController();
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

    _birthDateCtrl.text = user.birthDate ?? '';
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
    _birthDateCtrl.dispose();
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

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime(2000, 1, 1);
    if (_birthDateCtrl.text.isNotEmpty) {
      try {
        final parts = _birthDateCtrl.text.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            initialDate = DateTime.parse(_birthDateCtrl.text);
          } else {
            initialDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      } catch (e) {
        debugPrint('Date parse error: $e');
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: Colors.orange,
                    onPrimary: Colors.white,
                    surface: Color(0xFF162A5A),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Colors.orange,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateCtrl.text =
            "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
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
        birthDate: _birthDateCtrl.text.isEmpty ? null : _birthDateCtrl.text,
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
            content: Text('Gagal memperbarui profil: $e'.tr(context)),
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
          'Edit Profil Utama'.tr(context),
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
      body: SingleChildScrollView(
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
                      controller: _birthDateCtrl,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: InputDecoration(
                        labelText: 'Tanggal Lahir (DD-MM-YYYY)'.tr(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressCtrl,
                      maxLines: 2,
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
                      decoration: InputDecoration(
                        labelText: 'Alergi Utama'.tr(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _medicalHistoryCtrl,
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
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap'.tr(context),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _contacts[index]['relation'],
                                onChanged: (val) =>
                                    _contacts[index]['relation'] = val,
                                decoration: InputDecoration(
                                  labelText: 'Hubungan'.tr(context),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: _contacts[index]['phone'],
                                onChanged: (val) =>
                                    _contacts[index]['phone'] = val,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'No Hp'.tr(context),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
