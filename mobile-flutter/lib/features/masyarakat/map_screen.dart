import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/location_service.dart';
import '../../core/services/connectivity_service.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Mock markers for responders
  final List<LatLng> _mockResponders = [];

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

    _initLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _isLoading = false;
          _generateMockResponders();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat lokasi: $e';
        });
      }
    }
  }
  
  void _generateMockResponders() {
    if (_userLocation == null) return;
    // Generate 2 mock responders nearby (within ~500m to 2km)
    // 0.01 degrees is roughly 1km
    _mockResponders.clear();
    _mockResponders.add(LatLng(_userLocation!.latitude + 0.005, _userLocation!.longitude + 0.005));
    _mockResponders.add(LatLng(_userLocation!.latitude - 0.008, _userLocation!.longitude - 0.002));
  }

  void _recenterMap() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  LatLngBounds? _getMapBounds() {
    if (_userLocation == null) return null;
    // ~5km radius constraint (1 degree is ~111km, so 5km is ~0.045 degrees)
    const double radiusDegrees = 0.045;
    return LatLngBounds(
      LatLng(_userLocation!.latitude - radiusDegrees, _userLocation!.longitude - radiusDegrees),
      LatLng(_userLocation!.latitude + radiusDegrees, _userLocation!.longitude + radiusDegrees),
    );
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
                          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Koneksi Terputus - Peta Mungkin Tidak Tampil'.tr(context),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      floatingActionButton: _userLocation != null ? FloatingActionButton(
        backgroundColor: colors.primary,
        onPressed: _recenterMap,
        child: const Icon(Icons.my_location, color: Colors.white),
      ) : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green[600] : Colors.grey[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOnline ? 'ONLINE'.tr(context) : 'OFFLINE'.tr(context),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
        
        // Map Grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
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
                cameraConstraint: CameraConstraint.contain(bounds: _getMapBounds()!),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.superbypass.siagakita',
                ),
                MarkerLayer(
                  markers: [
                    // Responders
                    ..._mockResponders.map((pos) => Marker(
                      point: pos,
                      width: 80,
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.favorite, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('Relawan'.tr(context), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )),
                    // User Position
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 14),
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

        // Bottom Info
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
              _buildStatusCard(
                'Koordinat GPS Terkunci'.tr(context),
                Colors.green,
                context,
                isDark,
              ),
              const SizedBox(height: 8),
              _buildStatusCard(
                'Menyiarkan SOS ke relawan sekitar'.tr(context),
                colors.primary,
                context,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String text, Color dotColor, BuildContext context, bool isDark) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5),
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
          Text(
            text,
            style: TextStyle(color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
