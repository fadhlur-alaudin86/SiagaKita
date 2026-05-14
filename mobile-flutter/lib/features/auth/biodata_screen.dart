import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import 'login_screen.dart';
import '../../core/models/user_model.dart';
import '../../core/services/user_service.dart';

class BiodataScreen extends StatefulWidget {
  final String accessToken;
  final String userId;

  const BiodataScreen({
    super.key,
    required this.accessToken,
    required this.userId,
  });

  @override
  State<BiodataScreen> createState() => _BiodataScreenState();
}

class _BiodataScreenState extends State<BiodataScreen> {
  final _bloodTypeController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _addressController = TextEditingController();
  final _nikController = TextEditingController();
  final _phoneController = TextEditingController();
  final _placeOfBirthController = TextEditingController();

  final _contacts = <Map<String, dynamic>>[];
  bool _isLoading = false;

  Future<void> _handleRefresh() async {
    await UserService.refreshCurrentUser(widget.accessToken);
    if (!mounted) return;

    final user = UserModel.currentUser.value;
    setState(() {
      if (_nikController.text.isEmpty && user.nik != null) {
        _nikController.text = user.nik!;
      }
      if (_phoneController.text.isEmpty && user.phoneNumber != null) {
        _phoneController.text = user.phoneNumber!;
      }
      if (_placeOfBirthController.text.isEmpty && user.placeOfBirth != null) {
        _placeOfBirthController.text = user.placeOfBirth!;
      }
      if (_birthDateController.text.isEmpty && user.birthDate != null) {
        _birthDateController.text = user.birthDate!;
      }

      final med = user.medicalData ?? {};
      if (_bloodTypeController.text.isEmpty && med['blood_type'] != null) {
        _bloodTypeController.text = med['blood_type'];
      }
      if (_weightController.text.isEmpty && med['weight'] != null) {
        _weightController.text = med['weight'];
      }
      if (_heightController.text.isEmpty && med['height'] != null) {
        _heightController.text = med['height'];
      }
      if (_medicalHistoryController.text.isEmpty &&
          med['medical_history'] != null) {
        _medicalHistoryController.text = med['medical_history'];
      }
      if (_allergiesController.text.isEmpty && med['allergies'] != null) {
        _allergiesController.text = med['allergies'];
      }
      if (_addressController.text.isEmpty && med['address'] != null) {
        _addressController.text = med['address'];
      }

      if (_contacts.isEmpty && user.emergencyContacts != null) {
        _contacts.addAll(user.emergencyContacts!);
      }
    });
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
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
        _birthDateController.text =
            "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  Future<void> _submitBiodata() async {
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
    }

    setState(() => _isLoading = true);
    try {
      final medData = {
        'address': _addressController.text,
        'blood_type': _bloodTypeController.text,
        'weight': _weightController.text,
        'height': _heightController.text,
        'allergies': _allergiesController.text,
        'medical_history': _medicalHistoryController.text,
      };

      final updatedUser = UserModel.currentUser.value.copyWith(
        nik: _nikController.text.isEmpty ? null : _nikController.text,
        phoneNumber: _phoneController.text.isEmpty
            ? null
            : _phoneController.text,
        placeOfBirth: _placeOfBirthController.text.isEmpty
            ? null
            : _placeOfBirthController.text,
        birthDate: _birthDateController.text.isEmpty
            ? null
            : _birthDateController.text,
        medicalData: medData,
        emergencyContacts: _contacts.isEmpty ? null : _contacts,
      );

      await UserService.saveBiodata(widget.accessToken, updatedUser);

      if (!mounted) return;
      _skipBiodata();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'Gagal menyimpan biodata'.tr(context)}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipBiodata() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Lengkapi Biodata'.tr(context),
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Langkah Terakhir!'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data kesehatan ini sangat penting untuk penanganan medis darurat yang tepat sasaran.'
                      .tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Data Identitas & Kontak
                Text(
                  'Data Identitas & Kontak'.tr(context),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bisa diisi sekarang atau nanti di menu Profil. Berfungsi untuk keperluan verifikasi.'
                      .tr(context),
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _nikController,
                  'NIK KTP (16 Digit)'.tr(context),
                  Icons.badge_outlined,
                  colors,
                  inputType: TextInputType.number,
                  maxLength: 16,
                ),
                _buildTextField(
                  _phoneController,
                  'No WhatsApp aktif'.tr(context),
                  Icons.phone_android,
                  colors,
                  inputType: TextInputType.phone,
                  maxLength: 20,
                ),
                _buildTextField(
                  _placeOfBirthController,
                  'Tempat Lahir'.tr(context),
                  Icons.location_city,
                  colors,
                  maxLength: 100,
                ),
                const SizedBox(height: 24),

                // Fisik & Kesehatan
                Text(
                  'Fisik & Kesehatan'.tr(context),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Data ini mempermudah tim penolong mengetahui karakteristik fisik Anda.'
                      .tr(context),
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  _birthDateController,
                  'Tanggal Lahir (DD-MM-YYYY)'.tr(context),
                  Icons.calendar_today,
                  colors,
                ),
                _buildDropdownField(
                  _bloodTypeController,
                  'Gol. Darah'.tr(context),
                  Icons.bloodtype,
                  colors,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _weightController,
                        'Berat (kg)'.tr(context),
                        Icons.monitor_weight_outlined,
                        colors,
                        inputType: TextInputType.number,
                        maxLength: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        _heightController,
                        'Tinggi (cm)'.tr(context),
                        Icons.height,
                        colors,
                        inputType: TextInputType.number,
                        maxLength: 3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Riwayat Medis & Alergi
                Text(
                  'Riwayat Penyakit & Alergi'.tr(context),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kosongkan jika tidak ada. Data ini krusial untuk menghindari pantangan obat darurat.'
                      .tr(context),
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _medicalHistoryController,
                  'Contoh: Asma, Hipertensi'.tr(context),
                  Icons.medical_information_outlined,
                  colors,
                  maxLength: 255,
                ),
                _buildTextField(
                  _allergiesController,
                  'Contoh: Udang, Debu, Penisilin'.tr(context),
                  Icons.warning_amber_rounded,
                  colors,
                  maxLength: 255,
                ),
                const SizedBox(height: 8),

                // Alamat Lengkap
                Text(
                  'Alamat Tempat Tinggal'.tr(context),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sebagai acuan domisili terdekat jika evakuasi diperlukan.'
                      .tr(context),
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _addressController,
                    maxLines: 3,
                    maxLength: 255,
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Alamat lengkap sesuai domisili...'.tr(context),
                      hintStyle: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                // Kontak Darurat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kontak Darurat (Wali/Keluarga)'.tr(context),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addContact,
                      icon: Icon(Icons.add, color: primaryColor, size: 18),
                      label: Text(
                        'Tambah'.tr(context),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Orang yang akan dihubungi jika Anda dalam bahaya.'.tr(
                    context,
                  ),
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                if (_contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Belum ada kontak darurat ditambahkan.'.tr(context),
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...List.generate(_contacts.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'Kontak Darurat'.tr(context)} #${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
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
                          TextField(
                            controller:
                                TextEditingController(
                                    text: _contacts[index]['name'],
                                  )
                                  ..selection = TextSelection.collapsed(
                                    offset: _contacts[index]['name'].length,
                                  ),
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
                                child: TextField(
                                  controller:
                                      TextEditingController(
                                          text: _contacts[index]['relation'],
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset: _contacts[index]['relation']
                                              .length,
                                        ),
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
                                child: TextField(
                                  controller:
                                      TextEditingController(
                                          text: _contacts[index]['phone'],
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset:
                                              _contacts[index]['phone'].length,
                                        ),
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
                    );
                  }),

                const SizedBox(height: 32),
                Text(
                  'Bisa dilewati, data dapat dilengkapi nanti di dalam menu Profil.'
                      .tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _skipBiodata,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: primaryColor),
                        ),
                        child: Text(
                          'Lewati'.tr(context),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBiodata,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                          shadowColor: primaryColor.withValues(alpha: 0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Simpan & Selesai'.tr(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String hint,
    IconData icon,
    ColorScheme colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(context),
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            icon,
            color: colors.onSurface.withValues(alpha: 0.5),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    TextEditingController controller,
    String hint,
    IconData icon,
    ColorScheme colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: controller.text.isNotEmpty ? controller.text : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            icon,
            color: colors.onSurface.withValues(alpha: 0.5),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dropdownColor: colors.surface,
        style: TextStyle(color: colors.onSurface, fontSize: 14),
        items: [
          'A+',
          'A-',
          'B+',
          'B-',
          'AB+',
          'AB-',
          'O+',
          'O-',
          'Belum Tahu',
        ].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
        onChanged: (val) {
          if (val != null) controller.text = val;
        },
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    ColorScheme colors, {
    TextInputType inputType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLength: maxLength,
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.4),
            fontSize: 12,
          ),
          prefixIcon: Icon(
            icon,
            color: colors.onSurface.withValues(alpha: 0.5),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
