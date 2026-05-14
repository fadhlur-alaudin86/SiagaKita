import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_controller.dart';
import '../../core/services/connectivity_service.dart';

class MapScreen extends StatefulWidget {
  final String? accessToken;
  const MapScreen({super.key, this.accessToken});

  static final ValueNotifier<LatLng?> targetLocation = ValueNotifier(null);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoading = true;
  String _errorMessage = '';

  // Reverse geocoding cache
  String? _addressLabel;
  final _accuracy = 0.0;
  bool _geocodingDone = false;

  // Polling data
  List<NearbyIncident> _nearbySOS = [];
  Timer? _pollingTimer;
  ActiveResponseModel? _activeMission; // For volunteers handling an SOS
  ActiveIncident? _activeSOS; // For sender viewing their SOS

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    LocationController.instance.setMode(TrackingMode.passive);
    _initLocation();
    LocationController.instance.addListener(_onLocationChanged);
    MapScreen.targetLocation.addListener(_onTargetLocationChanged);
  }

  void _onTargetLocationChanged() {
    final target = MapScreen.targetLocation.value;
    if (target != null && mounted) {
      _mapController.move(target, 16.0);
      MapScreen.targetLocation.value = null; // Reset after moving
    }
  }

  void _onLocationChanged() {
    final pos = LocationController.instance.currentPosition;
    if (pos == null || !mounted) return;
    final newLoc = LatLng(pos.lat, pos.lng);

    final oldLoc = _userLocation;
    setState(() => _userLocation = newLoc);

    // Geser peta secara smooth ke posisi baru jika beda signifikan (>20m)
    if (oldLoc != null) {
      final distance = const Distance().as(LengthUnit.Meter, oldLoc, newLoc);
      if (distance > 20) {
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    }

    // Geocoding jika belum pernah
    if (!_geocodingDone) {
      _reverseGeocode(pos.lat, pos.lng);
    }
  }

  @override
  void dispose() {
    LocationController.instance.removeListener(_onLocationChanged);
    MapScreen.targetLocation.removeListener(_onTargetLocationChanged);
    LocationController.instance.setMode(TrackingMode.off);
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    final pos = await LocationController.instance.fetchNow();
    if (!mounted) return;
    if (pos != null) {
      setState(() {
        _userLocation = LatLng(pos.lat, pos.lng);
        _isLoading = false;
      });
      _reverseGeocode(pos.lat, pos.lng);
    } else {
      setState(() => _isLoading = false);
    }
    _startPolling();
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (_geocodingDone) return;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'SiagaKita/1.0'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final display = body['display_name'] as String?;
        if (display != null && mounted) {
          setState(() {
            _addressLabel = display.split(',').take(3).join(', ');
            _geocodingDone = true;
          });
        }
      }
    } catch (_) {
      // Geocoding gagal → tetap tampilkan koordinat
    }
  }

  void _startPolling() {
    if (widget.accessToken == null) return;
    _pollData();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollData(),
    );
  }

  Future<void> _pollData() async {
    if (!mounted || widget.accessToken == null) return;
    final user = UserModel.currentUser.value;

    // 1. Fetch Active SOS for the current user (sender)
    try {
      final activeSos = await IncidentService.getActive(
        accessToken: widget.accessToken!,
      );
      if (mounted) setState(() => _activeSOS = activeSos);
    } catch (_) {
      if (mounted) setState(() => _activeSOS = null);
    }

    // 2. Fetch Active Mission and Nearby SOS for Volunteers
    final isRelawan =
        user.role == UserRole.relawan || user.volunteerStatus == 'approved';
    if (isRelawan) {
      try {
        final mission = await IncidentService.getMyActiveResponse(
          accessToken: widget.accessToken!,
        );
        if (mounted) setState(() => _activeMission = mission);
      } catch (_) {
        if (mounted) setState(() => _activeMission = null);
      }

      if (user.isAvailableForMission && _userLocation != null) {
        try {
          final results = await IncidentService.getNearby(
            accessToken: widget.accessToken!,
            lat: _userLocation!.latitude,
            lng: _userLocation!.longitude,
            radius: 5.0,
          );
          if (mounted) setState(() => _nearbySOS = results);
        } catch (_) {}
      } else {
        if (mounted) setState(() => _nearbySOS = []);
      }
    }
  }

  void _recenterMap() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  LatLngBounds? _getMapBounds() {
    if (_userLocation == null) return null;
    const double radiusDegrees = 0.045; // ~5km
    return LatLngBounds(
      LatLng(
        _userLocation!.latitude - radiusDegrees,
        _userLocation!.longitude - radiusDegrees,
      ),
      LatLng(
        _userLocation!.latitude + radiusDegrees,
        _userLocation!.longitude + radiusDegrees,
      ),
    );
  }

  String _buildStatusText(UserModel user, bool isOnline) {
    final isRelawan =
        user.role == UserRole.relawan || user.volunteerStatus == 'approved';
    final isOnDuty = user.isAvailableForMission;

    if (!isOnline) return '📵 Offline - Peta mungkin tidak tersedia'.tr(context);
    if (isRelawan && isOnDuty && _nearbySOS.isNotEmpty) {
      return '${'DALAM TUGAS - Memantau'.tr(context)} ${_nearbySOS.length} ${'SOS dalam 5KM'.tr(context)}';
    }
    if (isRelawan && isOnDuty) {
      return 'DALAM TUGAS - Tidak ada SOS aktif dalam 5KM'.tr(context);
    }
    if (isRelawan && !isOnDuty) {
      return 'DI LUAR TUGAS - Aktifkan di tab Operasi'.tr(context);
    }
    if (_accuracy > 50) return '${'⚠️ Akurasi rendah: ±'.tr(context)}${_accuracy.round()}m';
    if (_addressLabel != null) return _addressLabel!;
    if (_userLocation != null) {
      return '${_userLocation!.latitude.toStringAsFixed(5)}, ${_userLocation!.longitude.toStringAsFixed(5)}';
    }
    return 'Mendeteksi lokasi...';
  }

  Color _buildStatusColor(UserModel user) {
    final isRelawan =
        user.role == UserRole.relawan || user.volunteerStatus == 'approved';
    final isOnDuty = user.isAvailableForMission;
    if (isRelawan && isOnDuty && _nearbySOS.isNotEmpty) {
      return const Color(0xFFEF4444);
    }
    if (isRelawan && isOnDuty) return const Color(0xFF22C55E);
    if (isRelawan && !isOnDuty) return Colors.grey;
    if (_accuracy > 50) return Colors.orange;
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: ConnectivityService.isOnline,
          builder: (context, isOnline, child) {
            return Stack(
              children: [
                _buildMainContent(colors, isDark, isOnline),
                if (!isOnline)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Koneksi Terputus - Peta Mungkin Tidak Tampil'.tr(
                              context,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(ColorScheme colors, bool isDark, bool isOnline) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty && _userLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = '';
                });
                _initLocation();
              },
              child: Text('Coba Lagi'.tr(context)),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<UserModel>(
      valueListenable: UserModel.currentUser,
      builder: (context, user, _) {
        final statusText = _buildStatusText(user, isOnline);
        final statusColor = _buildStatusColor(user);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JEJARING KESELAMATAN LOKAL'.tr(context),
                    style: const TextStyle(
                      color: Color(0xFFFF7418),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RADAR SIAGA & EVAKUASI'.tr(context),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green[600]
                              : Colors.grey[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOnline
                              ? 'ONLINE'.tr(context)
                              : 'OFFLINE'.tr(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Radius 5KM'.tr(context),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.1),
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userLocation!,
                        initialZoom: 15.0,
                        minZoom: 12.0,
                        maxZoom: 18.0,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: _getMapBounds()!,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.superbypass.siagakita',
                        ),
                        if (_activeSOS != null &&
                            (_activeSOS!.status == 'broadcasting' ||
                                _activeSOS!.status == 'handled'))
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final progress =
                                  (_pulseAnimation.value - 1.0) *
                                  2; // 0.0 to 1.0
                              return CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: LatLng(
                                      _activeSOS!.latitude,
                                      _activeSOS!.longitude,
                                    ),
                                    color: Colors.red.withValues(
                                      alpha: 0.2 * (1.0 - progress),
                                    ),
                                    borderStrokeWidth: 2,
                                    borderColor: Colors.red.withValues(
                                      alpha: 0.5 * (1.0 - progress),
                                    ),
                                    useRadiusInMeter: true,
                                    radius: 5000 * progress, // up to 5km
                                  ),
                                ],
                              );
                            },
                          ),
                        if (_activeSOS != null &&
                            _activeSOS!.volunteerLocations.isNotEmpty)
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity:
                                    0.3 + ((_pulseAnimation.value - 1.0) * 1.4),
                                child: PolylineLayer(
                                  polylines: _activeSOS!.volunteerLocations
                                      .map(
                                        (vl) => Polyline(
                                          points: [
                                            LatLng(vl.latitude, vl.longitude),
                                            LatLng(
                                              _activeSOS!.latitude,
                                              _activeSOS!.longitude,
                                            ),
                                          ],
                                          color: const Color(0xFF22C55E),
                                          strokeWidth: 4,
                                          pattern: StrokePattern.dashed(
                                            segments: const [10.0, 10.0],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        MarkerLayer(
                          markers: [
                            // SOS Nearby markers (hanya relawan ON DUTY)
                            ..._nearbySOS.map(
                              (inc) => Marker(
                                point: LatLng(inc.latitude, inc.longitude),
                                width: 48,
                                height: 48,
                                rotate: true,
                                child: GestureDetector(
                                  onTap: () => _showSOSSnackbar(inc),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        inc.typeEmoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Misi Aktif Relawan
                            if (_activeMission != null)
                              Marker(
                                point: LatLng(
                                  _activeMission!.reporterLatitude,
                                  _activeMission!.reporterLongitude,
                                ),
                                width: 56,
                                height: 56,
                                rotate: true,
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) => Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.crisis_alert,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Relawan Menuju Lokasi SOS
                            if (_activeSOS != null &&
                                _activeSOS!.volunteerLocations.isNotEmpty)
                              ..._activeSOS!.volunteerLocations.map(
                                (vl) => Marker(
                                  point: LatLng(vl.latitude, vl.longitude),
                                  width: 50,
                                  height: 50,
                                  rotate: true,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) =>
                                        Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF22C55E,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.two_wheeler,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            // User Position
                            Marker(
                              point: _userLocation!,
                              width: 60,
                              height: 60,
                              rotate: true,
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  final isTransmitting =
                                      _activeSOS != null ||
                                      _activeMission != null;
                                  final markerColor = (_activeSOS != null)
                                      ? const Color(0xFFEF4444)
                                      : colors.primary;

                                  Widget marker = Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: markerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  );

                                  if (isTransmitting) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: markerColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        child: Center(child: marker),
                                      ),
                                    );
                                  }

                                  return Center(child: marker);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_userLocation != null)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          backgroundColor: colors.primary,
                          onPressed: _recenterMap,
                          mini: true,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Status Transmisi
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS TRANSMISI'.tr(context),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(statusText, statusColor, isDark, colors),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSOSSnackbar(NearbyIncident inc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${inc.typeEmoji} ${inc.typeLabel.tr(context)} - ${inc.distanceLabel.tr(context)} - ${'Buka tab Operasi untuk terima misi'.tr(context)}',
        ),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildStatusCard(
    String text,
    Color dotColor,
    bool isDark,
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
