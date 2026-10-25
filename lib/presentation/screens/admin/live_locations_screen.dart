import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:order_app/core/services/live_location_service.dart';
import 'package:order_app/core/services/location_tracking_service.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

final liveLocationsStreamProvider = StreamProvider<List<LiveLocationData>>((ref) {
  return LiveLocationService.getLiveLocationsStream();
});

/// Real-time map of where employees are, for management roles.
class LiveLocationsScreen extends ConsumerStatefulWidget {
  const LiveLocationsScreen({super.key});

  @override
  ConsumerState<LiveLocationsScreen> createState() => _LiveLocationsScreenState();
}

class _LiveLocationsScreenState extends ConsumerState<LiveLocationsScreen> {
  static const _defaultCenter = LatLng(27.7172, 85.3240); // Kathmandu
  static const _onlineColor = Color(0xFF16a34a);
  static const _offlineColor = Color(0xFF94a3b8);

  final MapController _mapController = MapController();
  Timer? _ticker;
  bool _mapReady = false;
  bool _didInitialFit = false;
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate "online" and "x min ago" labels as time passes.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fitAll(List<LiveLocationData> locations) {
    if (!_mapReady || locations.isEmpty) return;
    if (locations.length == 1) {
      _mapController.move(LatLng(locations.first.latitude, locations.first.longitude), 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: locations.map((l) => LatLng(l.latitude, l.longitude)).toList(),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  String _lastSeen(DateTime? time) {
    if (time == null) return 'Unknown';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return DateFormat('MMM d, hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(liveLocationsStreamProvider);
    final users = ref.watch(usersStreamProvider).maybeWhen(
          data: (users) => {for (final u in users) u.id: u},
          orElse: () => <String, UserEntity>{},
        );

    final all = locationsAsync.maybeWhen(
      data: (list) => [...list],
      orElse: () => <LiveLocationData>[],
    )..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));
      });
    final visible = _onlineOnly ? all.where((l) => l.isOnline).toList() : all;
    final onlineCount = all.where((l) => l.isOnline).length;

    if (!_didInitialFit && _mapReady && visible.isNotEmpty) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll(visible));
    }

    String nameFor(LiveLocationData l) {
      final user = users[l.userId];
      if (user != null && user.name.isNotEmpty) return user.name;
      return l.userEmail.contains('@') ? l.userEmail.split('@').first : 'Staff Member';
    }

    return Scaffold(
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: const Text(
          'Live Staff Locations',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
            tooltip: 'Fit all on map',
            onPressed: () => _fitAll(visible),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 11,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12,
                onMapReady: () => setState(() => _mapReady = true),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.order_app',
                ),
                MarkerLayer(
                  markers: [
                    for (final l in visible)
                      Marker(
                        point: LatLng(l.latitude, l.longitude),
                        width: 120,
                        height: 64,
                        child: GestureDetector(
                          onTap: () => _showDetails(l, nameFor(l)),
                          child: _MapPin(
                            label: nameFor(l),
                            color: l.isOnline ? _onlineColor : _offlineColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: _onlineColor),
                const SizedBox(width: 6),
                Text(
                  '$onlineCount online • ${all.length} total',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Online only'),
                  selected: _onlineOnly,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => setState(() => _onlineOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 9,
            child: locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load locations: $e')),
              data: (_) {
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _onlineOnly
                            ? 'No staff are sharing their location right now.'
                            : 'No live locations yet. Staff appear here once they open the app with location enabled.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final l = visible[i];
                    final name = nameFor(l);
                    final color = l.isOnline ? _onlineColor : _offlineColor;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${l.userRole} • ${l.isOnline ? 'Live' : 'Last seen'} ${_lastSeen(l.updatedAt)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.map_outlined),
                        tooltip: 'Open in Google Maps',
                        onPressed: () => LocationTrackingService.openMap(l.latitude, l.longitude),
                      ),
                      onTap: () {
                        if (_mapReady) {
                          _mapController.move(LatLng(l.latitude, l.longitude), 16);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(LiveLocationData l, String name) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${l.userRole} • ${l.device}'),
              const SizedBox(height: 12),
              Text('Status: ${l.isOnline ? 'Live' : 'Offline'} (updated ${_lastSeen(l.updatedAt)})'),
              Text('Coordinates: ${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}'),
              if (l.accuracy != null) Text('Accuracy: ±${l.accuracy!.round()} m'),
              if (l.speed != null && l.speed! > 0.5)
                Text('Speed: ${(l.speed! * 3.6).toStringAsFixed(1)} km/h'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Open in Google Maps'),
                  onPressed: () => LocationTrackingService.openMap(l.latitude, l.longitude),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String label;
  final Color color;

  const _MapPin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        Icon(Icons.location_on, color: color, size: 32),
      ],
    );
  }
}
