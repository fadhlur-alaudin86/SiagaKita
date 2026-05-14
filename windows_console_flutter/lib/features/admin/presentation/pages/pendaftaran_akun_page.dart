import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicator: BoxDecoration(
                color: const Color(0xFFFF7418),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Instansi (Agency)'),
                Tab(text: 'Admin Sistem'),
              ],
            ),
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
  final _searchCtrl = TextEditingController();
  String _type = 'police';
  bool _loading = false;
  String? _msg;
  bool _isError = false;

  // Map Variables
  final _mapController = MapController();
  LatLng? _selectedLocation;

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
          if (_selectedLocation != null)
            'latitude': _selectedLocation!.latitude,
          if (_selectedLocation != null)
            'longitude': _selectedLocation!.longitude,
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
          _selectedLocation = null;
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

  Future<void> _searchLocation() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    
    setState(() => _loading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final res = await http.get(url, headers: {'User-Agent': 'com.siagakita.console'});
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final point = LatLng(lat, lon);
          setState(() {
            _selectedLocation = point;
          });
          _mapController.move(point, 14.0);
          _reverseGeocode(point);
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=10');
      final res = await http.get(url, headers: {'User-Agent': 'com.siagakita.console'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          String city = address['city'] ?? address['town'] ?? address['county'] ?? address['state'] ?? '';
          if (city.isNotEmpty) {
            String code = city.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
            if (code.length > 3) {
              code = code.substring(0, 3);
            }
            setState(() {
              _cityCtrl.text = code;
            });
          }
        }
      }
    } catch (_) {}
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
        PopupMenuButton<String>(
          initialValue: _type,
          color: const Color(0xFF1A1F2E),
          offset: const Offset(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide.none,
          ),
          onSelected: (v) => setState(() => _type = v),
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'police',
              child: Text('Kepolisian', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'fire',
              child: Text('Pemadam Kebakaran', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'medical',
              child: Text('Medis / Rumah Sakit', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'sar',
              child: Text('Tim SAR', style: TextStyle(color: Colors.white)),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  switch (_type) {
                    'police' => 'Kepolisian',
                    'fire' => 'Pemadam Kebakaran',
                    'medical' => 'Medis / Rumah Sakit',
                    'sar' => 'Tim SAR',
                    _ => _type,
                  },
                  style: const TextStyle(color: Colors.white),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Lokasi Instansi',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari nama tempat / kota...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _loading ? null : _searchLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.search, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(
                  -6.200000,
                  106.816666,
                ), // Jakarta as default
                initialZoom: 10.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                  _reverseGeocode(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.siagakita.console',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Terpilih: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
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
