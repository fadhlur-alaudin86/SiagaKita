import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/services/ws_service.dart';

class DispatchRelawanPage extends StatefulWidget {
  final String token;
  final WsService ws;

  const DispatchRelawanPage({super.key, required this.token, required this.ws});

  @override
  State<DispatchRelawanPage> createState() => _DispatchRelawanPageState();
}

class _DispatchRelawanPageState extends State<DispatchRelawanPage> {
  final MapController _mapController = MapController();
  List<IncidentModel> _incidents = [];
  IncidentModel? _selectedIncident;
  bool _loadingIncidents = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // Map of online volunteer telemetry: userId -> LatLng
  final ValueNotifier<Map<String, LatLng>> _volunteerLocationsNotifier =
      ValueNotifier({});
  Map<String, LatLng> get _volunteerLocations =>
      _volunteerLocationsNotifier.value;
  // Track timestamp of last received telemetry ping
  final Map<String, DateTime> _volunteerLastSeen = {};
  // Selected volunteer candidate IDs for manual dispatch selection
  final Set<String> _selectedCandidateIds = {};

  StreamSubscription<WsMessage>? _wsSub;
  Timer? _cleanupTimer;

  static const _categoryFilters = [
    'all',
    'fire',
    'medical',
    'crime',
    'disaster',
    'accident',
  ];

  static const _categoryColors = <String, Color>{
    'fire': Color(0xFFEF5350),
    'medical': Color(0xFFAB47BC),
    'crime': Color(0xFFFF7043),
    'disaster': Color(0xFF42A5F5),
    'accident': Color(0xFF26C6DA),
    'general': Color(0xFF66BB6A),
    'unknown': Color(0xFFFFCA28),
  };

  static const _categoryLabels = <String, String>{
    'all': 'Semua',
    'fire': 'Kebakaran',
    'medical': 'Medis',
    'crime': 'Kriminalitas',
    'disaster': 'Bencana',
    'accident': 'Kecelakaan',
  };

  @override
  void initState() {
    super.initState();
    _loadIncidents();

    // Listen to real-time WebSocket events
    _wsSub = widget.ws.eventStream.listen((msg) {
      if (!mounted) return;
      switch (msg.event) {
        case WsEvent.incomingEmergency:
        case WsEvent.sosCancelled:
        case WsEvent.sosStatusUpdate:
        case WsEvent.rescueAccepted:
        case WsEvent.incidentUpdated:
        case WsEvent.connected:
          _loadIncidents(silent: true);
          break;

        case WsEvent.volunteerLocationUpdate:
          final userId = msg.payload['user_id'] as String?;
          final lat = msg.payload['latitude'] as num?;
          final lng = msg.payload['longitude'] as num?;
          if (userId != null && lat != null && lng != null) {
            final updated =
                Map<String, LatLng>.from(_volunteerLocationsNotifier.value);
            updated[userId] = LatLng(
              lat.toDouble(),
              lng.toDouble(),
            );
            _volunteerLastSeen[userId] = DateTime.now();
            _volunteerLocationsNotifier.value = updated;
          }
          break;

        case WsEvent.incidentDispatchTimeout:
          final incId = msg.payload['incident_id'] as String?;
          if (incId != null && incId == _selectedIncident?.id) {
            _showTimeoutDialog();
          }
          break;

        default:
          break;
      }
    });

    // Periodic cleanup: remove stale volunteer markers older than 90s (anti-memory leak)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final staleKeys = <String>[];
      _volunteerLastSeen.forEach((id, lastSeen) {
        if (now.difference(lastSeen).inSeconds > 90) {
          staleKeys.add(id);
        }
      });
      if (staleKeys.isNotEmpty) {
        final updated =
            Map<String, LatLng>.from(_volunteerLocationsNotifier.value);
        bool candidateRemoved = false;
        for (final key in staleKeys) {
          updated.remove(key);
          _volunteerLastSeen.remove(key);
          if (_selectedCandidateIds.remove(key)) {
            candidateRemoved = true;
          }
        }
        _volunteerLocationsNotifier.value = updated;
        if (candidateRemoved && mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _cleanupTimer?.cancel();
    _volunteerLocationsNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents({bool silent = false}) async {
    if (!silent) setState(() => _loadingIncidents = true);
    final data = await IncidentApiService.getActiveIncidents(widget.token);
    if (!mounted) return;

    setState(() {
      _incidents = data;
      _loadingIncidents = false;

      // Preserve or update selected incident
      if (_selectedIncident != null) {
        final updated = data.where((i) => i.id == _selectedIncident!.id);
        if (updated.isNotEmpty) {
          _selectedIncident = updated.first;
        }
      } else if (data.isNotEmpty) {
        _selectedIncident = data.first;
        _moveMapToIncident(_selectedIncident!);
        _fetchNearbyVolunteers(_selectedIncident!);
      }
    });
  }

  Future<void> _fetchNearbyVolunteers(IncidentModel incident) async {
    try {
      final volunteers = await IncidentApiService.getNearbyVolunteers(
        widget.token,
        incident.latitude,
        incident.longitude,
      );
      if (!mounted) return;
      final updated =
          Map<String, LatLng>.from(_volunteerLocationsNotifier.value);
      for (final v in volunteers) {
        final userId = v['user_id'] as String?;
        final lat = v['latitude'] as num?;
        final lng = v['longitude'] as num?;
        if (userId != null && lat != null && lng != null) {
          updated[userId] = LatLng(
            lat.toDouble(),
            lng.toDouble(),
          );
          _volunteerLastSeen[userId] = DateTime.now();
        }
      }
      _volunteerLocationsNotifier.value = updated;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _moveMapToIncident(IncidentModel incident) {
    _mapController.move(LatLng(incident.latitude, incident.longitude), 15.0);
  }

  // Calculate distance in kilometers using standard Haversine formula
  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, p1, p2);
  }

  // Get ranked top candidate volunteers relative to current selected SOS
  List<MapEntry<String, LatLng>> _getRankedCandidates() {
    if (_selectedIncident == null) return [];
    final sosPos = LatLng(
      _selectedIncident!.latitude,
      _selectedIncident!.longitude,
    );

    final entries = _volunteerLocations.entries.toList();
    entries.sort((a, b) {
      final d1 = _calculateDistanceKm(sosPos, a.value);
      final d2 = _calculateDistanceKm(sosPos, b.value);
      return d1.compareTo(d2);
    });
    return entries;
  }

  List<IncidentModel> get _filteredIncidents {
    return _incidents.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.reporterName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (item.addressDetail?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          item.id.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'all' ||
          item.incidentType.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left Panel: Active SOS Incident Queue (380px) ──────────────────
        RepaintBoundary(
          child: SizedBox(width: 380, child: _buildQueuePanel()),
        ),
        const SizedBox(width: 16),

        // ── Right Panel: OpenStreetMap Radar & Candidate Drawer ────────────
        Expanded(
          child: RepaintBoundary(
            child: _selectedIncident == null
                ? _buildEmptyRadarPlaceholder()
                : _buildRadarAndCandidatesPanel(),
          ),
        ),
      ],
    );
  }

  // ─── LEFT PANEL: Active SOS Queue ──────────────────────────────────────────
  Widget _buildQueuePanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2537),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Antrean SOS Aktif'.tr(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${_incidents.length}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Input
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau alamat...'.tr(context),
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
                const SizedBox(height: 10),
                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryFilters.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      final label = (_categoryLabels[cat] ?? cat).tr(context);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                          backgroundColor: const Color(0xFF111827),
                          selectedColor: const Color(
                            0xFFFF7418,
                          ).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFFFF7418),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFF7418)
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFFFF7418)
                                  : Colors.white12,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Incident List
          Expanded(
            child: _loadingIncidents
                ? const Center(child: CircularProgressIndicator())
                : _filteredIncidents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada insiden SOS aktif'.tr(context),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredIncidents.length,
                    itemBuilder: (ctx, i) {
                      final incident = _filteredIncidents[i];
                      final isSelected = _selectedIncident?.id == incident.id;
                      return KeyedSubtree(
                        key: ValueKey(incident.id),
                        child: _buildIncidentQueueCard(incident, isSelected),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentQueueCard(IncidentModel incident, bool isSelected) {
    final color =
        _categoryColors[incident.incidentType.toLowerCase()] ??
        const Color(0xFFEF5350);
    final categoryLabel =
        (_categoryLabels[incident.incidentType.toLowerCase()] ??
                incident.incidentType)
            .tr(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIncident = incident;
          _selectedCandidateIds.clear();
        });
        _moveMapToIncident(incident);
        _fetchNearbyVolunteers(incident);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF7418).withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFFFF7418) : Colors.transparent,
              width: 3.5,
            ),
            bottom: const BorderSide(color: Colors.white10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatTimeAgo(incident.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              incident.reporterName.isNotEmpty
                  ? incident.reporterName
                  : 'Warga (SOS)'.tr(context),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (incident.addressDetail != null &&
                incident.addressDetail!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                incident.addressDetail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CRITICAL',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (incident.volunteerResponseStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      incident.volunteerResponseStatus!.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF42A5F5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── RIGHT PANEL: OpenStreetMap Radar & Candidate Panel ────────────────────
  Widget _buildEmptyRadarPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2537),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar_outlined, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'Pilih insiden SOS di sebelah kiri untuk melihat radar relawan dan melakukan penugasan.'
                  .tr(context),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarAndCandidatesPanel() {
    final incident = _selectedIncident!;
    final sosLocation = LatLng(incident.latitude, incident.longitude);
    final rankedCandidates = _getRankedCandidates();

    final polylines = <Polyline>[];
    if (incident.responderId != null &&
        _volunteerLocations.containsKey(incident.responderId)) {
      polylines.add(
        Polyline(
          points: [sosLocation, _volunteerLocations[incident.responderId]!],
          color: const Color(0xFF43A047),
          strokeWidth: 4.0,
        ),
      );
    } else {
      for (final id in _selectedCandidateIds) {
        if (_volunteerLocations.containsKey(id)) {
          polylines.add(
            Polyline(
              points: [sosLocation, _volunteerLocations[id]!],
              color: const Color(0xFFFF7418).withValues(alpha: 0.8),
              strokeWidth: 2.5,
            ),
          );
        }
      }
    }

    return Column(
      children: [
        // ── Top Header bar: Active Incident Overview ────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2537),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sensors,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SOS: ${incident.reporterName.isNotEmpty ? incident.reporterName : "Warga"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)})',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (incident.addressDetail != null)
                      Text(
                        incident.addressDetail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7418),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Fokus Lokasi'),
                onPressed: () => _moveMapToIncident(incident),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Interactive Map (OpenStreetMap) ─────────────────────────────────
        Expanded(
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  ValueListenableBuilder<Map<String, LatLng>>(
                    valueListenable: _volunteerLocationsNotifier,
                    builder: (context, volunteerLocations, _) {
                      final dynamicPolylines = <Polyline>[];
                      if (incident.responderId != null &&
                          volunteerLocations.containsKey(incident.responderId)) {
                        dynamicPolylines.add(
                          Polyline(
                            points: [
                              sosLocation,
                              volunteerLocations[incident.responderId]!,
                            ],
                            color: const Color(0xFF43A047),
                            strokeWidth: 4.0,
                          ),
                        );
                      } else {
                        for (final id in _selectedCandidateIds) {
                          if (volunteerLocations.containsKey(id)) {
                            dynamicPolylines.add(
                              Polyline(
                                points: [sosLocation, volunteerLocations[id]!],
                                color: const Color(
                                  0xFFFF7418,
                                ).withValues(alpha: 0.8),
                                strokeWidth: 2.5,
                              ),
                            );
                          }
                        }
                      }

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: sosLocation,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.siagakita.console',
                          ),
                          if (dynamicPolylines.isNotEmpty)
                            PolylineLayer(polylines: dynamicPolylines),
                          // Markers Layer
                          MarkerLayer(
                            markers: [
                              // Target SOS Marker (🔴)
                              Marker(
                                point: sosLocation,
                                width: 46,
                                height: 46,
                                child: const _PulsingSosMarker(),
                              ),
                              // Live Volunteer Markers (🟢)
                              ...volunteerLocations.entries.map((entry) {
                                final isTopCandidate = rankedCandidates
                                    .take(3)
                                    .any((c) => c.key == entry.key);
                                return Marker(
                                  point: entry.value,
                                  width: 40,
                                  height: 40,
                                  child: _buildVolunteerMarker(
                                    entry.key,
                                    isTopCandidate,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  // Floating Map Controls
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'zoomIn',
                          backgroundColor: const Color(0xFF1E2537),
                          foregroundColor: Colors.white,
                          onPressed: () {
                            final z = _mapController.camera.zoom + 1;
                            _mapController.move(_mapController.camera.center, z);
                          },
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoomOut',
                          backgroundColor: const Color(0xFF1E2537),
                          foregroundColor: Colors.white,
                          onPressed: () {
                            final z = _mapController.camera.zoom - 1;
                            _mapController.move(_mapController.camera.center, z);
                          },
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'centerSos',
                          backgroundColor: const Color(0xFFFF7418),
                          foregroundColor: Colors.white,
                          onPressed: () => _moveMapToIncident(incident),
                          child: const Icon(Icons.crisis_alert),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Candidate Panel Drawer: Top-3 Nearest Volunteers or Active Mission Tracking ──
        RepaintBoundary(
          child: incident.volunteerResponseStatus != null
              ? _buildActiveMissionDrawer(incident, sosLocation)
              : _buildCandidateDrawer(rankedCandidates, sosLocation),
        ),
      ],
    );
  }

  Widget _buildVolunteerMarker(String userId, bool isTopCandidate) {
    return Tooltip(
      message: 'Relawan #$userId',
      child: Container(
        decoration: BoxDecoration(
          color: isTopCandidate
              ? const Color(0xFF43A047)
              : const Color(0xFF2E7D32),
          shape: BoxShape.circle,
          border: Border.all(
            color: isTopCandidate ? Colors.amber : Colors.white,
            width: isTopCandidate ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.person, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildCandidateDrawer(
    List<MapEntry<String, LatLng>> candidates,
    LatLng sosLocation,
  ) {
    final top3 = candidates.take(3).toList();

    return Container(
      height: 195,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2537),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Color(0xFFFF7418), size: 18),
              const SizedBox(width: 8),
              Text(
                'Kandidat Relawan Terdekat'.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 1-Click Fast Broadcast Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7418),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.broadcast_on_personal, size: 16),
                label: Text(
                  _selectedCandidateIds.isNotEmpty
                      ? '${"Kirim Penugasan".tr(context)} (${_selectedCandidateIds.length})'
                      : 'Broadcast ke 3 Terdekat'.tr(context),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: top3.isEmpty
                    ? null
                    : () => _handleDispatch(
                        _selectedCandidateIds.isNotEmpty
                            ? _selectedCandidateIds.toList()
                            : top3.map((c) => c.key).toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: top3.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada relawan online dalam radius'.tr(context),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: top3.length,
                    itemBuilder: (ctx, i) {
                      final candidate = top3[i];
                      final distKm = _calculateDistanceKm(
                        sosLocation,
                        candidate.value,
                      );
                      final isSelected = _selectedCandidateIds.contains(
                        candidate.key,
                      );

                      return Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF7418)
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFFFF7418),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedCandidateIds.add(
                                          candidate.key,
                                        );
                                      } else {
                                        _selectedCandidateIds.remove(
                                          candidate.key,
                                        );
                                      }
                                    });
                                  },
                                ),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2E7D32),
                                  child: Text(
                                    '#${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Relawan #${candidate.key.substring(0, candidate.key.length > 8 ? 8 : candidate.key.length)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${distKm.toStringAsFixed(1)} ${"km dari lokasi".tr(context)}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ON DUTY'.tr(context),
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      _handleDispatch([candidate.key]),
                                  child: Text(
                                    'Tugaskan'.tr(context),
                                    style: const TextStyle(
                                      color: Color(0xFFFF7418),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDispatch(List<String> targetIds) async {
    if (_selectedIncident == null || targetIds.isEmpty) return;
    final success = await IncidentApiService.dispatchBroadcast(
      widget.token,
      _selectedIncident!.id,
      targetIds,
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _selectedCandidateIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${"Penugasan berhasil dikirim".tr(context)} (${targetIds.length} relawan)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal mengirim penugasan".tr(context)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showTimeoutDialog() {
    if (!mounted || _selectedIncident == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Waktu penugasan habis (Timeout)'.tr(context),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Belum ada relawan yang menerima panggilan dalam 60 detik.'.tr(
            context,
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await IncidentApiService.agencyHandle(
                widget.token,
                _selectedIncident!.id,
              );
              _loadIncidents(silent: true);
            },
            child: Text('Tangani oleh Petugas Instansi'.tr(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7418),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final top3 = _getRankedCandidates()
                  .take(3)
                  .map((c) => c.key)
                  .toList();
              if (top3.isNotEmpty) {
                _handleDispatch(top3);
              }
            },
            child: Text('Broadcast Ulang'.tr(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMissionDrawer(IncidentModel incident, LatLng sosLocation) {
    final status = incident.volunteerResponseStatus ?? 'accepted';
    int currentStep = 0;
    if (status == 'en_route') {
      currentStep = 1;
    } else if (status == 'on_scene') {
      currentStep = 2;
    } else if (status == 'completed' || status == 'waiting_review') {
      currentStep = 3;
    }

    final steps = [
      'Diterima'.tr(context),
      'Menuju Lokasi'.tr(context),
      'Tiba di Lokasi'.tr(context),
      'Selesai'.tr(context),
    ];

    double? distKm;
    if (incident.responderId != null &&
        _volunteerLocations.containsKey(incident.responderId)) {
      distKm = _calculateDistanceKm(
        sosLocation,
        _volunteerLocations[incident.responderId]!,
      );
    }

    final responderDisplay =
        incident.responderName ??
        (incident.responderId != null
            ? 'Relawan #${incident.responderId!.substring(0, incident.responderId!.length > 8 ? 8 : incident.responderId!.length)}'
            : 'Relawan Siaga'.tr(context));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2537),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF43A047).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.navigation_outlined,
                  color: Color(0xFF43A047),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Misi Sedang Berjalan'.tr(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${"Relawan Penanggung Jawab".tr(context)}: $responderDisplay',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              if (distKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distKm.toStringAsFixed(1)} ${"km dari lokasi".tr(context)}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7418),
                  side: const BorderSide(color: Color(0xFFFF7418)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(
                  'Broadcast Ulang'.tr(context),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  final top3 = _getRankedCandidates()
                      .take(3)
                      .map((c) => c.key)
                      .toList();
                  if (top3.isNotEmpty) {
                    _handleDispatch(top3);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4-Step Stepper
          Row(
            children: List.generate(steps.length, (idx) {
              final isPassed = idx < currentStep;
              final isCurrent = idx == currentStep;
              final color = isPassed || isCurrent
                  ? const Color(0xFF43A047)
                  : Colors.white24;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (idx > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isPassed || isCurrent
                                  ? const Color(0xFF43A047)
                                  : Colors.white12,
                            ),
                          ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPassed
                                ? const Color(0xFF43A047)
                                : isCurrent
                                ? const Color(0xFF111827)
                                : const Color(0xFF1E2537),
                            border: Border.all(
                              color: color,
                              width: isCurrent ? 2.5 : 1.5,
                            ),
                          ),
                          child: Center(
                            child: isPassed
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : isCurrent
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF43A047),
                                    ),
                                  )
                                : Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                          ),
                        ),
                        if (idx < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: idx < currentStep
                                  ? const Color(0xFF43A047)
                                  : Colors.white12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[idx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.greenAccent
                            : isPassed
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

// ─── Pulsing SOS Red Marker ──────────────────────────────────────────────────

class _PulsingSosMarker extends StatefulWidget {
  const _PulsingSosMarker();

  @override
  State<_PulsingSosMarker> createState() => _PulsingSosMarkerState();
}

class _PulsingSosMarkerState extends State<_PulsingSosMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, child) {
        final scale = 1.0 + (_controller.value * 0.25);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(
                    alpha: 0.6 * _controller.value,
                  ),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.sensors, color: Colors.white, size: 22),
            ),
          ),
        );
      },
    );
  }
}
