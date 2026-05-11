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

  // SOS nearby (untuk relawan ON DUTY)
  List<NearbyIncident> _nearbySOS = [];
  Timer? _nearbyTimer;

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
    LocationController.instance.start();
    _initLocation();
    LocationController.instance.position.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    final pos = LocationController.instance.position.value;
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
    _pulseController.dispose();
    LocationController.instance.position.removeListener(_onLocationChanged);
    LocationController.instance.stop();
    _nearbyTimer?.cancel();
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
    _maybeStartNearbyPolling();
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

  void _maybeStartNearbyPolling() {
    final user = UserModel.currentUser.value;
    if (user.role != UserRole.relawan && user.volunteerStatus != 'approved') {
      return;
    }
    if (!user.isAvailableForMission) {
      return;
    }
    if (widget.accessToken == null) {
      return;
    }
    _fetchNearbySOS();
    _nearbyTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchNearbySOS(),
    );
  }

  Future<void> _fetchNearbySOS() async {
    if (_userLocation == null || widget.accessToken == null) return;
    final results = await IncidentService.getNearby(
      accessToken: widget.accessToken!,
      lat: _userLocation!.latitude,
      lng: _userLocation!.longitude,
      radius: 5.0,
    );
    if (mounted) setState(() => _nearbySOS = results);
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

    if (!isOnline) return '📵 Offline - Peta mungkin tidak tersedia';
    if (isRelawan && isOnDuty && _nearbySOS.isNotEmpty) {
      return '🟢 ON DUTY - Memantau ${_nearbySOS.length} SOS dalam 5KM';
    }
    if (isRelawan && isOnDuty) {
      return '🟢 ON DUTY - Tidak ada SOS aktif dalam 5KM';
    }
    if (isRelawan && !isOnDuty) {
      return '⭕ OFF DUTY - Aktifkan di tab Operasi';
    }
    if (_accuracy > 50) return '⚠️ Akurasi rendah: ±${_accuracy.round()}m';
    if (_addressLabel != null) return '📍 $_addressLabel';
    if (_userLocation != null) {
      return '📍 ${_userLocation!.latitude.toStringAsFixed(5)}, ${_userLocation!.longitude.toStringAsFixed(5)}';
    }
    return '📡 Mendeteksi lokasi...';
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
      floatingActionButton: _userLocation != null
          ? FloatingActionButton(
              backgroundColor: colors.primary,
              onPressed: _recenterMap,
              child: const Icon(Icons.my_location, color: Colors.white),
            )
          : null,
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
                child: FlutterMap(
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
                    MarkerLayer(
                      markers: [
                        // SOS Nearby markers (hanya relawan ON DUTY)
                        ..._nearbySOS.map(
                          (inc) => Marker(
                            point: LatLng(inc.latitude, inc.longitude),
                            width: 48,
                            height: 48,
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
                        // User Position
                        Marker(
                          point: _userLocation!,
                          width: 60,
                          height: 60,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final isSOSActive =
                                  user.isAvailableForMission ==
                                  false; // simplification
                              final markerColor = isSOSActive
                                  ? const Color(0xFFEF4444)
                                  : colors.primary;
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: markerColor.withValues(alpha: 0.3),
                                  ),
                                  child: Center(
                                    child: Container(
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
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
          '${inc.typeEmoji} ${inc.typeLabel} - ${inc.distanceLabel} - Buka tab Operasi untuk terima misi',
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
