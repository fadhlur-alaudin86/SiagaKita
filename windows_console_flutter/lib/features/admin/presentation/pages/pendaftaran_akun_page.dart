import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';

class PendaftaranAkunPage extends StatefulWidget {
  final String token;
  final String role;
  const PendaftaranAkunPage({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  State<PendaftaranAkunPage> createState() => _PendaftaranAkunPageState();
}

class _PendaftaranAkunPageState extends State<PendaftaranAkunPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _tabCount =
      2; // Always show 2 tabs, but we might disable one or hide it

  @override
  void initState() {
    super.initState();
    // Jika bukan superadmin, hanya tampilkan 1 tab (Instansi)
    final isSuperadmin = widget.role == 'superadmin';
    _tabController = TabController(length: isSuperadmin ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperadmin = widget.role == 'superadmin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSuperadmin)
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFFFF7418),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFFF7418),
            tabs: const [
              Tab(text: 'Instansi (Agency)'),
              Tab(text: 'Admin Sistem'),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Biar tidak bisa di-swipe kalau tab disable
            children: [
              _FormInstansi(token: widget.token),
              if (isSuperadmin) _FormAdmin(token: widget.token),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Form Pembuatan Instansi ──────────────────────────────────────────────────

class _FormInstansi extends StatefulWidget {
  final String token;
  const _FormInstansi({required this.token});

  @override
  State<_FormInstansi> createState() => _FormInstansiState();
}

class _FormInstansiState extends State<_FormInstansi> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _type = 'police';
  bool _loading = false;
  String? _msg;
  bool _isError = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.adminAgencies),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'name': _nameCtrl.text.trim(),
          'type': _type,
          'city_code': _cityCtrl.text.trim(),
        }),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _isError = false;
          _msg = 'Akun instansi berhasil didaftarkan!';
          _emailCtrl.clear();
          _passCtrl.clear();
          _nameCtrl.clear();
          _cityCtrl.clear();
        });
      } else {
        setState(() {
          _isError = true;
          _msg = body['message'] ?? 'Gagal membuat instansi';
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _msg = 'Terjadi kesalahan jaringan.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardForm(
      title: 'Pendaftaran Akun Instansi (Agency)',
      subtitle:
          'Akun ini akan digunakan oleh operator instansi untuk mengelola respon dan mendaftarkan petugas lapangannya.',
      msg: _msg,
      isError: _isError,
      children: [
        _buildField('Email Login', _emailCtrl),
        _buildField('Password', _passCtrl, obscureText: true),
        _buildField('Nama Instansi (Cth: Polrestabes Bandung)', _nameCtrl),
        _buildField('Kode Kota (Cth: BDO)', _cityCtrl),
        const SizedBox(height: 12),
        const Text(
          'Tipe Instansi',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _type,
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'police', child: Text('Kepolisian')),
            DropdownMenuItem(value: 'fire', child: Text('Pemadam Kebakaran')),
            DropdownMenuItem(
              value: 'medical',
              child: Text('Medis / Rumah Sakit'),
            ),
            DropdownMenuItem(value: 'sar', child: Text('Tim SAR')),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: _buildSubmitBtn('Daftarkan Instansi', _loading, _submit),
        ),
      ],
    );
  }
}

// ─── Form Pembuatan Admin ─────────────────────────────────────────────────────

class _FormAdmin extends StatefulWidget {
  final String token;
  const _FormAdmin({required this.token});

  @override
  State<_FormAdmin> createState() => _FormAdminState();
}

class _FormAdminState extends State<_FormAdmin> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _msg;
  bool _isError = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.adminAdmins),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
          'full_name': _nameCtrl.text.trim(),
        }),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _isError = false;
          _msg = 'Akun admin berhasil didaftarkan!';
          _emailCtrl.clear();
          _passCtrl.clear();
          _nameCtrl.clear();
        });
      } else {
        setState(() {
          _isError = true;
          _msg = body['message'] ?? 'Gagal membuat admin';
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _msg = 'Terjadi kesalahan jaringan.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardForm(
      title: 'Pendaftaran Administrator Sistem',
      subtitle:
          'Hanya superadmin yang dapat membuat akun admin. Admin bertugas mengelola aplikasi harian.',
      msg: _msg,
      isError: _isError,
      children: [
        _buildField('Email Login', _emailCtrl),
        _buildField('Password', _passCtrl, obscureText: true),
        _buildField('Nama Lengkap', _nameCtrl),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: _buildSubmitBtn('Daftarkan Admin', _loading, _submit),
        ),
      ],
    );
  }
}

// ─── Komponen Shared ──────────────────────────────────────────────────────────

Widget _buildCardForm({
  required String title,
  required String subtitle,
  String? msg,
  required bool isError,
  required List<Widget> children,
}) {
  return Card(
    color: const Color(0xFF111827),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF1F2937)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: (isError ? Colors.red : Colors.green).withValues(
                  alpha: 0.1,
                ),
                border: Border.all(
                  color: (isError ? Colors.red : Colors.green).withValues(
                    alpha: 0.3,
                  ),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg,
                style: TextStyle(color: isError ? Colors.red : Colors.green),
              ),
            ),
          ...children,
        ],
      ),
    ),
  );
}

Widget _buildField(
  String label,
  TextEditingController ctrl, {
  bool obscureText = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSubmitBtn(String label, bool loading, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFF7418),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}
