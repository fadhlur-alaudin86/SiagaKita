import 'package:flutter/material.dart';

import '../../../../core/services/api_services.dart';

class ManajemenPersonilPage extends StatefulWidget {
  final String token;
  const ManajemenPersonilPage({super.key, required this.token});

  @override
  State<ManajemenPersonilPage> createState() => _ManajemenPersonilPageState();
}

class _ManajemenPersonilPageState extends State<ManajemenPersonilPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _badgeNumberCtrl = TextEditingController();
  
  bool _loading = false;
  bool _obscurePassword = true;

  // Mock data for personil & relawan
  final List<Map<String, dynamic>> _mockPersonil = [
    {
      'id': '1',
      'name': 'Budi Santoso',
      'type': 'Agency Responder',
      'badge': 'AR-001',
      'status': 'active',
    },
    {
      'id': '2',
      'name': 'Agus Pratama',
      'type': 'Relawan',
      'badge': '-',
      'status': 'active',
    },
    {
      'id': '3',
      'name': 'Siti Aminah',
      'type': 'Agency Responder',
      'badge': 'AR-002',
      'status': 'banned',
    },
  ];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _badgeNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      await AgencyApiService.createPersonnel(
        widget.token,
        _fullNameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _badgeNumberCtrl.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun personil lapangan berhasil didaftarkan.'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _fullNameCtrl.clear();
        _emailCtrl.clear();
        _passwordCtrl.clear();
        _badgeNumberCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSimulatedBanDialog(Map<String, dynamic> personil) {
    if (personil['type'] == 'Agency Responder') {
      // Agency has full power
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2537),
          title: Text('Ban ${personil['name']}?'),
          content: const Text(
            'Sebagai Agency, Anda memiliki kuasa penuh untuk memblokir personil Anda.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => personil['status'] = 'banned');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Personil berhasil diblokir (Simulasi).'), backgroundColor: Colors.red),
                );
              },
              child: const Text('Ban Personil', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // Relawan: Agency can only request ban
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2537),
          title: Text('Ajukan Ban untuk ${personil['name']}?'),
          content: const Text(
            'Relawan bersifat publik. Anda hanya dapat mengajukan permintaan pemblokiran kepada Admin Pusat disertai bukti.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permintaan Ban dikirim ke Admin (Simulasi).'), backgroundColor: Colors.orange),
                );
              },
              child: const Text('Ajukan Ban', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kiri: Daftar Personil
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daftar Personil & Relawan (Simulasi)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kelola personil instansi Anda dan pantau relawan di wilayah Anda.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _mockPersonil.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final p = _mockPersonil[i];
                    final isBanned = p['status'] == 'banned';
                    return Card(
                      color: const Color(0xFF1A2035),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(
                          p['name'],
                          style: TextStyle(
                            color: isBanned ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: isBanned ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text('${p['type']} • Badge: ${p['badge']}', style: const TextStyle(color: Colors.white54)),
                        trailing: isBanned
                            ? const Text('BANNED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                icon: const Icon(Icons.block, size: 16),
                                label: Text(p['type'] == 'Agency Responder' ? 'Ban' : 'Ajukan Ban'),
                                onPressed: () => _showSimulatedBanDialog(p),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Kanan: Pendaftaran
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pendaftaran Personil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Buat akun baru untuk personil lapangan.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF1A2035),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _fullNameCtrl,
                            label: 'Nama Lengkap',
                            icon: Icons.person_outline,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailCtrl,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Wajib diisi';
                              }
                              if (!val.contains('@')) return 'Tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _badgeNumberCtrl,
                            label: 'Nomor Lencana (Badge)',
                            icon: Icons.badge_outlined,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordCtrl,
                            label: 'Kata Sandi Awal',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Wajib diisi';
                              }
                              if (val.length < 6) return 'Minimal 6 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Daftarkan',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
