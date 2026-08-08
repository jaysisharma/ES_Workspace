import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:order_app/core/services/geofence_service.dart';

class ManageGeofenceDialog extends StatefulWidget {
  const ManageGeofenceDialog({super.key});

  @override
  State<ManageGeofenceDialog> createState() => _ManageGeofenceDialogState();
}

class _ManageGeofenceDialogState extends State<ManageGeofenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController();

  double _radiusMeters = 200.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocating = false;
  Position? _currentDevicePosition;

  @override
  void initState() {
    super.initState();
    _loadCurrentGeofence();
    _fetchDeviceLocationSilently();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentGeofence() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('office_geofence')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lat = (data['latitude'] as num?)?.toDouble() ?? 27.7172;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 85.3240;
        final radius = (data['radiusMeters'] as num?)?.toDouble() ?? 200.0;
        final address = data['address'] as String? ?? 'Central Office';

        _latitudeController.text = lat.toString();
        _longitudeController.text = lng.toString();
        _radiusController.text = radius.toInt().toString();
        _addressController.text = address;
        _radiusMeters = radius;
      } else {
        // Defaults
        _latitudeController.text = '27.7172';
        _longitudeController.text = '85.3240';
        _radiusController.text = '200';
        _addressController.text = 'Central Office';
        _radiusMeters = 200.0;
      }
    } catch (e) {
      debugPrint('Error loading geofence: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDeviceLocationSilently() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 4)),
        );
        if (mounted) {
          setState(() {
            _currentDevicePosition = pos;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled on your device.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission was denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission is permanently denied.');
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );

      _currentDevicePosition = pos;
      _latitudeController.text = pos.latitude.toStringAsFixed(6);
      _longitudeController.text = pos.longitude.toStringAsFixed(6);

      // Reverse geocode
      try {
        List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          _addressController.text = '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
              .replaceAll(RegExp(r'^,\s*'), '');
        } else {
          _addressController.text = await _reverseGeocodeHttp(pos.latitude, pos.longitude);
        }
      } catch (_) {
        _addressController.text = await _reverseGeocodeHttp(pos.latitude, pos.longitude);
      }

      _showSnackBar('GPS coordinates updated from your device!');
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String> _reverseGeocodeHttp(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ESWorkspace/1.0 (contact: info@esworkspace.com)'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {}
    return 'Lat: ${lat.toStringAsFixed(4)}, Long: ${lon.toStringAsFixed(4)}';
  }

  Future<void> _saveGeofence() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final lat = double.parse(_latitudeController.text.trim());
      final lng = double.parse(_longitudeController.text.trim());
      final radius = double.parse(_radiusController.text.trim());
      final address = _addressController.text.trim();

      await FirebaseFirestore.instance.collection('settings').doc('office_geofence').set({
        'latitude': lat,
        'longitude': lng,
        'radiusMeters': radius,
        'address': address.isEmpty ? 'Office Location' : address,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Office Geofence Zone saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error saving geofence: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    double? distanceMeters;
    bool isInsideZone = true;
    final currentLat = double.tryParse(_latitudeController.text);
    final currentLng = double.tryParse(_longitudeController.text);

    if (_currentDevicePosition != null && currentLat != null && currentLng != null) {
      distanceMeters = GeofenceService.calculateDistance(
        startLatitude: _currentDevicePosition!.latitude,
        startLongitude: _currentDevicePosition!.longitude,
        endLatitude: currentLat,
        endLongitude: currentLng,
      );
      isInsideZone = distanceMeters <= _radiusMeters;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.share_location_rounded, color: colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Manage Office Geofence',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Set the central location and boundary radius for staff clock-in verification.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        // Current Device Location Shortcut Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLocating ? null : _useCurrentLocation,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: colorScheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.my_location_rounded, color: colorScheme.primary),
                            label: Text(
                              _isLocating ? 'Detecting Location...' : 'Use My Current Device Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Address / Location Title
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Office / Venue Name',
                            hintText: 'e.g. Central Office, Kathmandu',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a location name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // Lat & Lng Input Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  hintText: '27.7172',
                                  prefixIcon: const Icon(Icons.location_on),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  if (val == null || double.tryParse(val.trim()) == null) {
                                    return 'Invalid latitude';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  hintText: '85.3240',
                                  prefixIcon: const Icon(Icons.location_on_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  if (val == null || double.tryParse(val.trim()) == null) {
                                    return 'Invalid longitude';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Radius Configuration Header & Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Allowed Geofence Radius',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_radiusMeters.round()} meters',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _radiusMeters.clamp(50.0, 2000.0),
                          min: 50.0,
                          max: 2000.0,
                          divisions: 39,
                          label: '${_radiusMeters.round()} m',
                          onChanged: (val) {
                            setState(() {
                              _radiusMeters = val;
                              _radiusController.text = val.round().toString();
                            });
                          },
                        ),

                        // Preset Radius Chips
                        Wrap(
                          spacing: 8,
                          children: [50, 100, 200, 500, 1000].map((preset) {
                            final isSelected = _radiusMeters.round() == preset;
                            return ChoiceChip(
                              label: Text('${preset}m'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _radiusMeters = preset.toDouble();
                                    _radiusController.text = preset.toString();
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Distance Verification Live Preview Card
                        if (distanceMeters != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isInsideZone ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isInsideZone ? Colors.green : Colors.amber.shade800,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isInsideZone ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: isInsideZone ? Colors.green.shade800 : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your position: ${GeofenceService.formatDistance(distanceMeters)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isInsideZone ? Colors.green.shade900 : Colors.amber.shade900,
                                        ),
                                      ),
                                      Text(
                                        isInsideZone ? 'Inside geofence radius' : 'Outside boundary limit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isInsideZone ? Colors.green.shade800 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveGeofence,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded, color: Colors.white),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Geofence',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
