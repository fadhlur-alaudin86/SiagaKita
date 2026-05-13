import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/localization/app_localization.dart';
import '../../core/services/location_service.dart';
import '../../core/services/report_service.dart';
import 'package:camera/camera.dart';
import '../../core/widgets/custom_camera_view.dart';
import 'report_history_screen.dart' as import_report_history;

class ReportScreen extends StatefulWidget {
  final String accessToken;
  const ReportScreen({super.key, required this.accessToken});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // ─── Location ────────────────────────────────────────────────────────────────
  LatLng? _currentLatLng;
  String _addressLabel = 'Memuat lokasi...';
  bool _isLoadingLocation = true;

  // ─── Category ────────────────────────────────────────────────────────────────
  final ScrollController _categoryScrollCtrl = ScrollController();
  int _selectedCategoryIndex = -1;
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Kebakaran',
      'icon': Icons.local_fire_department,
      'color': Colors.orange,
      'value': 'fire',
    },
    {
      'title': 'Kecelakaan',
      'icon': Icons.car_crash,
      'color': Colors.red,
      'value': 'accident',
    },
    {
      'title': 'Bencana Alam',
      'icon': Icons.water_damage,
      'color': Colors.blue,
      'value': 'disaster',
    },
    {
      'title': 'Kriminalitas',
      'icon': Icons.warning_rounded,
      'color': Colors.purple,
      'value': 'crime',
    },
    {
      'title': 'Medis',
      'icon': Icons.medical_services,
      'color': Colors.green,
      'value': 'medical',
    },
  ];

  // ─── Photos ──────────────────────────────────────────────────────────────────
  final List<File> _photos = [];

  // ─── Audio ───────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  File? _audioFile;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _audioPath;

  // ─── Form ────────────────────────────────────────────────────────────────────
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _descCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Location ────────────────────────────────────────────────────────────────

  Future<void> _loadLocation() async {
    final pos = await LocationService.getCurrentPositionOrNull();
    if (!mounted) return;
    if (pos != null) {
      setState(() => _currentLatLng = LatLng(pos.latitude, pos.longitude));
      await _reverseGeocode(pos.latitude, pos.longitude);
    } else {
      setState(() {
        _addressLabel = 'Lokasi tidak tersedia';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'com.siagakita.mobile'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final display = data['display_name'] as String? ?? '$lat, $lng';
        final parts = display.split(', ');
        final short = parts.take(3).join(', ');
        setState(() {
          _addressLabel = short;
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _addressLabel = '$lat, $lng';
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressLabel = 'Gagal memuat alamat';
          _isLoadingLocation = false;
        });
      }
    }
  }

  // ─── Photos ──────────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    if (_photos.length >= 3) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin kamera ditolak. Buka pengaturan untuk mengizinkan.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomCameraView(
          title: 'Ambil Foto Keadaan Darurat',
          lensDirection: CameraLensDirection.back,
          showOverlay: false,
          onPictureTaken: (XFile file) async {
            final dir = await getTemporaryDirectory();
            final outPath = p.join(
              dir.path,
              'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            final compressed = await FlutterImageCompress.compressAndGetFile(
              file.path,
              outPath,
              quality: 70,
              minWidth: 1280,
              minHeight: 960,
            );
            if (compressed != null && mounted) {
              setState(() => _photos.add(File(compressed.path)));
            }
          },
        ),
      ),
    );
  }

  // Removed _showPhotoSource, direct camera instead

  // ─── Audio ───────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_isRecording) return; // Cegah timer ganda
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin mikrofon ditolak.')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _audioPath = p.join(
      dir.path,
      'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 22050,
        bitRate: 64000,
      ),
      path: _audioPath!,
    );
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 60) {
          _stopRecording();
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      if (path != null) _audioFile = File(path);
    });
  }

  Future<void> _togglePlayAudio() async {
    if (_audioFile == null) return;
    if (_isPlayingAudio) {
      await _player.stop();
      setState(() => _isPlayingAudio = false);
    } else {
      await _player.play(DeviceFileSource(_audioFile!.path));
      setState(() => _isPlayingAudio = true);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlayingAudio = false);
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  void _showConfirmSheet() {
    if (_selectedCategoryIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori darurat terlebih dahulu.'),
        ),
      );
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto bukti wajib dilampirkan.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final colors = Theme.of(context).colorScheme;
    final cat = _categories[_selectedCategoryIndex];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Konfirmasi Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _confirmRow(
              Icons.category_outlined,
              'Kategori',
              cat['title'].toString(),
              colors,
            ),
            _confirmRow(
              Icons.location_on_outlined,
              'Lokasi',
              _addressLabel,
              colors,
            ),
            if (_photos.isNotEmpty)
              _confirmRow(
                Icons.image_outlined,
                'Foto',
                '${_photos.length} foto terlampir',
                colors,
              ),
            if (_audioFile != null)
              _confirmRow(
                Icons.mic_outlined,
                'Audio',
                'Rekaman ${_formatDuration(_recordSeconds)}',
                colors,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _submitReport();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Kirim Sekarang',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colors, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor ?? colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      await ReportService.submitReport(
        accessToken: widget.accessToken,
        incidentType: _categories[_selectedCategoryIndex]['value'].toString(),
        latitude: _currentLatLng?.latitude ?? 0,
        longitude: _currentLatLng?.longitude ?? 0,
        description: _descCtrl.text,
        photos: _photos,
        audio: _audioFile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan berhasil dikirim!'.tr(context)),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on ReportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  // ─── Build ───────────────────────────────────────────────────────────────────

  Widget _buildFormTab(ColorScheme colors, Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Map
          _buildMapCard(colors, primaryColor, isDark),
          const SizedBox(height: 24),

          // 2. Kategori
          Text(
            'Kategori Darurat'.tr(context),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryRow(colors, primaryColor, isDark),
          const SizedBox(height: 24),

          // 3. Foto
          Text(
            'Lampiran Foto & Audio'.tr(context),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPhotoSection(colors, isDark),
          const SizedBox(height: 16),

          // 4. Audio
          _buildAudioSection(colors, isDark),
          const SizedBox(height: 24),

          // 5. Deskripsi
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Ketik deskripsi tambahan jika ada...'.tr(context),
                hintStyle: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 6. Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _showConfirmSheet,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                'Kirim Laporan'.tr(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(
            'Laporan Warga'.tr(context),
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.onSurface),
          bottom: TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: primaryColor,
            tabs: [
              Tab(text: 'Pelaporan'.tr(context)),
              Tab(text: 'Riwayat Laporan'.tr(context)),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildFormTab(colors, primaryColor, isDark),
              import_report_history.ReportHistoryScreen(
                accessToken: widget.accessToken,
                isNested: true,
              ), // Will fix import later
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(ColorScheme colors, Color primaryColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 140,
              child: _currentLatLng == null
                  ? Container(
                      color: const Color(0xFF0D1B3E),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: _currentLatLng!,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.siagakita.mobile',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLatLng!,
                              child: Icon(
                                Icons.location_on,
                                color: primaryColor,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isLoadingLocation ? Icons.hourglass_empty : Icons.gps_fixed,
                  color: _isLoadingLocation ? Colors.grey : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingLocation
                            ? 'Mendeteksi lokasi...'
                            : 'Lokasi Otomatis Ditemukan',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _addressLabel,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoadingLocation = true;
                      _addressLabel = 'Memuat ulang...';
                    });
                    _loadLocation();
                  },
                  child: Icon(
                    Icons.refresh,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    ColorScheme colors,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      height: 120, // slightly taller to accommodate the track padding
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          trackColor: WidgetStateProperty.all(
            isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Scrollbar(
          controller: _categoryScrollCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 6,
          radius: const Radius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ), // Padding to avoid overlapping content
            child: ListView.builder(
              controller: _categoryScrollCtrl,
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSel = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSel ? primaryColor : colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel
                            ? primaryColor
                            : colors.onSurface.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSel && !isDark
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          color: isSel ? Colors.white : cat['color'] as Color,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat['title'].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSel ? Colors.white : colors.onSurface,
                            fontSize: 10,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ColorScheme colors, bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ..._photos.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  entry.value,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => setState(() => _photos.removeAt(entry.key)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_photos.length < 3)
          GestureDetector(
            onTap: _openCamera,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 28,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_photos.length}/3',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioSection(ColorScheme colors, bool isDark) {
    if (_audioFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rekaman ${_formatDuration(_recordSeconds)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isPlayingAudio ? Icons.stop : Icons.play_arrow,
                color: Colors.green,
              ),
              onPressed: _togglePlayAudio,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => setState(() {
                _audioFile = null;
                _audioPath = null;
                _recordSeconds = 0;
              }),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onLongPressCancel: () => _stopRecording(),
      onLongPressUp: () => _stopRecording(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(
              color: _isRecording
                  ? Colors.red
                  : colors.onSurface.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Horizontal fill animation from left to right
              if (_isRecording)
                AnimatedFractionallySizedBox(
                  duration: const Duration(seconds: 1),
                  curve: Curves.linear,
                  alignment: Alignment.centerLeft,
                  widthFactor: (_recordSeconds / 60.0).clamp(0.0, 1.0),
                  child: Container(color: Colors.red.withValues(alpha: 0.15)),
                ),
              // Content
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic,
                    size: 28,
                    color: _isRecording
                        ? Colors.red
                        : colors.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _isRecording
                          ? 'Merekam... ${_formatDuration(_recordSeconds)} / 01:00'
                          : 'Tahan untuk rekam suara (Opsional, maks 1 menit)',
                      style: TextStyle(
                        color: _isRecording
                            ? Colors.red
                            : colors.onSurface.withValues(alpha: 0.6),
                        fontWeight: _isRecording
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
