import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/ws_service.dart';

class PetaOperasionalPage extends StatefulWidget {
  final String token;
  final WsService ws;
  final LatLng? targetLocation;
  const PetaOperasionalPage({
    super.key,
    required this.token,
    required this.ws,
    this.targetLocation,
  });

  @override
  State<PetaOperasionalPage> createState() => _PetaOperasionalPageState();
}

class _PetaOperasionalPageState extends State<PetaOperasionalPage> {
  final _mapController = MapController();
  List<IncidentModel> _incidents = [];
  StreamSubscription<WsMessage>? _wsSub;
  LatLng _defaultCenter = const LatLng(
    -5.55,
    95.32,
  ); // Banda Aceh default fallback
  LatLng? _agencyLocation; // Lokasi agency sendiri
  final Map<String, LatLng> _volunteers = {}; // Lokasi relawan online

  @override
  void initState() {
    super.initState();
    _loadAgencyProfile();
    _loadIncidents();
    _wsSub = widget.ws.eventStream.listen((msg) {
      if (!mounted) return;
      if (msg.event == WsEvent.incomingEmergency ||
          msg.event == WsEvent.sosCancelled ||
          msg.event == WsEvent.connected) {
        _loadIncidents();
      } else if (msg.event == WsEvent.volunteerLocationUpdate) {
        final userId = msg.payload['user_id'] as String?;
        final lat = msg.payload['latitude'] as num?;
        final lng = msg.payload['longitude'] as num?;
        if (userId != null && lat != null && lng != null) {
          setState(() {
            _volunteers[userId] = LatLng(lat.toDouble(), lng.toDouble());
          });
        }
      }
    });

    if (widget.targetLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.targetLocation!, 16.0);
      });
    }
  }

  @override
  void didUpdateWidget(PetaOperasionalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetLocation != oldWidget.targetLocation &&
        widget.targetLocation != null) {
      _mapController.move(widget.targetLocation!, 16.0);
    }
  }

  Future<void> _loadAgencyProfile() async {
    final profile = await AgencyApiService.getProfile(widget.token);
    if (mounted && profile != null) {
      final lat = profile['latitude'] as num?;
      final lng = profile['longitude'] as num?;
      if (lat != null && lng != null) {
        setState(() {
          _agencyLocation = LatLng(lat.toDouble(), lng.toDouble());
          if (widget.targetLocation == null) {
            _defaultCenter = _agencyLocation!;
          }
        });
        if (widget.targetLocation == null) {
          _mapController.move(_defaultCenter, 13.0);
        }
      }
    }
  }

  Future<void> _loadIncidents() async {
    final data = await IncidentApiService.getActiveIncidents(widget.token);
    if (mounted) setState(() => _incidents = data);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Peta Real-time',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_incidents.length} SOS Aktif',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Map
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 11,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.siagakita.console',
                ),
                MarkerLayer(
                  markers: [
                    if (_agencyLocation != null)
                      Marker(
                        point: _agencyLocation!,
                        width: 50,
                        height: 50,
                        child: const Column(
                          children: [
                            Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.blue,
                              size: 32,
                            ),
                            Text(
                              'Pusat',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._incidents.map((inc) {
                      if (inc.latitude == 0 && inc.longitude == 0) {
                        return const Marker(
                          point: LatLng(0, 0),
                          child: SizedBox.shrink(),
                        );
                      }
                      return Marker(
                        point: LatLng(inc.latitude, inc.longitude),
                        width: 48,
                        height: 56,
                        child: GestureDetector(
                          onTap: () => _showIncidentPopup(inc),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              CustomPaint(
                                size: const Size(12, 8),
                                painter: _TrianglePainter(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Marker Relawan
                    ..._volunteers.entries.map((entry) {
                      return Marker(
                        point: entry.value,
                        width: 60,
                        height: 60,
                        child: const _AnimatedVolunteerMarker(),
                      );
                    }),
                    // Target Location Marker (jika ada)
                    if (widget.targetLocation != null)
                      Marker(
                        point: widget.targetLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blueAccent,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              _LegendItem(
                color: Colors.red,
                label: 'SOS Aktif (${_incidents.length})',
              ),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.green, label: 'Relawan Aktif'),
            ],
          ),
        ),
      ],
    );
  }

  void _showIncidentPopup(IncidentModel inc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: Text(inc.typeLabel, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pelapor: ${inc.reporterName}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Trust: ${inc.trustLabel}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Waktu: ${inc.formattedTime}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.red;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AnimatedVolunteerMarker extends StatefulWidget {
  const _AnimatedVolunteerMarker();

  @override
  State<_AnimatedVolunteerMarker> createState() => _AnimatedVolunteerMarkerState();
}

class _AnimatedVolunteerMarkerState extends State<_AnimatedVolunteerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1.0 + (_ctrl.value * 0.2);
        final opacity = 1.0 - (_ctrl.value * 0.5);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse circle
            Container(
              width: 40 * scale,
              height: 40 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: opacity * 0.4),
              ),
            ),
            // Main Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            // Floating Arrow
            Positioned(
              top: 0 - (_ctrl.value * 5),
              child: Opacity(
                opacity: _ctrl.value,
                child: const Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: Colors.greenAccent,
                  size: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
