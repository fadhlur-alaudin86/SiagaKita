import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localization.dart';
import '../../missions/data/models/mission_model.dart';

class NavigationMapScreen extends StatefulWidget {
  final MissionModel mission;

  const NavigationMapScreen({super.key, required this.mission});

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _responderPosition;
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    try {
      final initialPos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _responderPosition = LatLng(initialPos.latitude, initialPos.longitude);
        });
      }

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _responderPosition = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _launchGoogleMaps() async {
    final lat = widget.mission.latitude;
    final lng = widget.mission.longitude;
    final googleMapsAppUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWebUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (await canLaunchUrl(googleMapsAppUrl)) {
      await launchUrl(googleMapsAppUrl);
    } else {
      await launchUrl(googleMapsWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWaze() async {
    final lat = widget.mission.latitude;
    final lng = widget.mission.longitude;
    final wazeAppUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    final wazeWebUrl = Uri.parse('https://www.waze.com/ul?ll=$lat,$lng&navigate=yes');

    if (await canLaunchUrl(wazeAppUrl)) {
      await launchUrl(wazeAppUrl);
    } else {
      await launchUrl(wazeWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentLatLng = LatLng(widget.mission.latitude, widget.mission.longitude);

    double distanceKm = 0.0;
    if (_responderPosition != null) {
      distanceKm = Geolocator.distanceBetween(
            _responderPosition!.latitude,
            _responderPosition!.longitude,
            incidentLatLng.latitude,
            incidentLatLng.longitude,
          ) /
          1000.0;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Navigasi Lapangan'.tr(context),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.operationalBlue),
            onPressed: () {
              if (_responderPosition != null) {
                _mapController.move(_responderPosition!, 15);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _responderPosition ?? incidentLatLng,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.siagakita.responder',
              ),
              // Polyline
              if (_responderPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_responderPosition!, incidentLatLng],
                      strokeWidth: 4.0,
                      color: AppColors.operationalBlue,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  // Incident Pin
                  Marker(
                    point: incidentLatLng,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.emergencyRed,
                      size: 44,
                    ),
                  ),
                  // Responder Pin
                  if (_responderPosition != null)
                    Marker(
                      point: _responderPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.operationalBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating Distance Info Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation, color: AppColors.warningAmber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Menuju Lokasi Insiden'.tr(context),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.mission.addressDetail ?? 'Lokasi Kejadian'.tr(context),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      distanceKm < 1.0
                          ? '${(distanceKm * 1000).toInt()} m'
                          : '${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Bottom Navigation Launchers
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.operationalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.map, size: 18),
                      label: Text('Buka di Google Maps'.tr(context)),
                      onPressed: _launchGoogleMaps,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceHighlight,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      icon: const Icon(Icons.near_me, size: 18, color: AppColors.warningAmber),
                      label: Text('Buka di Waze'.tr(context)),
                      onPressed: _launchWaze,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
