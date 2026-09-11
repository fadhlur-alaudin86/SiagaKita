import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localization.dart';
import '../../navigation/presentation/navigation_map_screen.dart';
import '../data/models/mission_model.dart';
import '../services/mission_service.dart';

class MissionDetailScreen extends StatefulWidget {
  final MissionModel mission;

  const MissionDetailScreen({super.key, required this.mission});

  @override
  State<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends State<MissionDetailScreen> {
  late MissionModel _mission;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_mission.audioPath == null || _mission.audioPath!.isEmpty) return;

    if (_isPlayingAudio) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(_mission.audioPath!));
    }
  }

  Future<void> _updateStatus(String nextStatus) async {
    if (nextStatus == 'resolved') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Konfirmasi Selesai'.tr(ctx),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Pastikan situasi di lapangan telah terkendali sebelum menyelesaikan misi.'.tr(ctx),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Batal'.tr(ctx)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Ya, Selesai'.tr(ctx)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    final missionSvc = context.read<MissionService>();
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = 'Status misi berhasil diperbarui'.tr(context);
    final errorMsg = 'Gagal memperbarui status misi'.tr(context);

    setState(() => _isUpdating = true);

    final success = await missionSvc.updateMissionStatus(
      incidentId: _mission.id,
      status: nextStatus,
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.successGreen,
        ),
      );
      if (nextStatus == 'resolved') {
        Navigator.of(context).pop();
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Detail Misi'.tr(context),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.emergencyRed),
                        ),
                        child: Text(
                          _mission.incidentType.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusColor(_mission.status).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _mission.agencyStatus?.toUpperCase() ?? _mission.status.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.statusColor(_mission.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mission.addressDetail ?? 'Lokasi Kejadian'.tr(context),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_mission.latitude.toStringAsFixed(5)}, ${_mission.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tactical Map Shortcut Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.operationalBlue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, color: AppColors.operationalBlue, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peta Taktis'.tr(context),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Arahkan Navigasi'.tr(context),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.operationalBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.navigation, size: 16),
                    label: Text('Buka Navigasi'.tr(context)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NavigationMapScreen(mission: _mission),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Caller / Victim details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Pelapor'.tr(context),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Divider(color: AppColors.border),
                  _buildInfoRow('Nama'.tr(context), _mission.reporterName),
                  if (_mission.reporterPhone != null)
                    _buildInfoRow('Telepon'.tr(context), _mission.reporterPhone!),
                  _buildInfoRow('Golongan Darah'.tr(context), _mission.bloodType ?? '-'),
                  _buildInfoRow('Alergi'.tr(context), _mission.allergies ?? '-'),
                  _buildInfoRow('Label Kepercayaan'.tr(context), _mission.reporterTrustLabel.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Voice audio evidence if available
            if (_mission.audioPath != null && _mission.audioPath!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: AppColors.warningAmber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bukti Rekaman Suara'.tr(context),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: AppColors.warningAmber,
                        size: 36,
                      ),
                      onPressed: _toggleAudio,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: _isUpdating
              ? const Center(
                  heightFactor: 1,
                  child: CircularProgressIndicator(color: AppColors.operationalBlue),
                )
              : Row(
                  children: [
                    // Button 1: Terima / Dalam Perjalanan
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.operationalBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _updateStatus('en_route'),
                        child: Text(
                          _mission.agencyStatus == 'handling'
                              ? 'Dalam Perjalanan'.tr(context)
                              : 'Terima Tugas'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Button 2: Tiba di Lokasi
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningAmber,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _updateStatus('on_scene'),
                        child: Text(
                          'Tiba di Lokasi'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Button 3: Selesai
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _updateStatus('resolved'),
                        child: Text(
                          'Selesai'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
