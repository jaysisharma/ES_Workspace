import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/data/models/attendance_model.dart';
import 'package:order_app/core/services/geofence_service.dart';
import 'package:order_app/presentation/providers/attendance_providers.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  File? _capturedSelfie;
  String? _selfieBase64;
  Position? _currentPosition;
  String? _streetAddress;

  String? _selectedEventId;
  String? _selectedEventTitle;
  String? _selectedOrderId;

  final ScrollController _scrollController = ScrollController();
  int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _pageSize += 15;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _streetAddress = 'Location services disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _streetAddress = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _streetAddress = 'Location permission permanently denied';
        });
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
      }

      if (pos == null) {
        setState(() {
          _streetAddress = 'GPS timeout. Try checking device settings.';
        });
        return;
      }

      _currentPosition = pos;

      try {
        final geocoding = Geocoding();
        List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          _streetAddress =
              '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                  .replaceAll(RegExp(r'^,\s*'), '');
        } else {
          _streetAddress = await _reverseGeocodeHttp(
            pos.latitude,
            pos.longitude,
          );
        }
      } catch (e) {
        try {
          _streetAddress = await _reverseGeocodeHttp(
            pos.latitude,
            pos.longitude,
          );
        } catch (_) {
          _streetAddress =
              'Lat: ${pos.latitude.toStringAsFixed(4)}, Long: ${pos.longitude.toStringAsFixed(4)}';
        }
      }
    } catch (e) {
      setState(() {
        _streetAddress = 'Unable to get location: $e';
      });
    }
  }

  Future<String> _reverseGeocodeHttp(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ESWorkspace/1.0 (contact: info@esworkspace.com)',
        },
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

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (image != null) {
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      setState(() {
        _capturedSelfie = file;
        _selfieBase64 = base64Encode(bytes);
      });
    }
  }

  void _showClockInDialog(String staffId, String staffName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    double officeLat = 27.7172;
    double officeLng = 85.3240;
    double officeRadius = 200.0;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('office_geofence')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        officeLat = (data['latitude'] as num?)?.toDouble() ?? 27.7172;
        officeLng = (data['longitude'] as num?)?.toDouble() ?? 85.3240;
        officeRadius = (data['radiusMeters'] as num?)?.toDouble() ?? 200.0;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog
    }

    setState(() {
      _selectedEventId = 'daily_attendance';
      _selectedEventTitle = 'Daily Attendance';
      _selectedOrderId = 'office';
      _capturedSelfie = null;
      _selfieBase64 = null;
    });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double? distanceMeters;
            bool isWithinFence = true;

            if (_currentPosition != null) {
              distanceMeters = GeofenceService.calculateDistance(
                startLatitude: _currentPosition!.latitude,
                startLongitude: _currentPosition!.longitude,
                endLatitude: officeLat,
                endLongitude: officeLng,
              );
              isWithinFence = distanceMeters <= officeRadius;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Clock In Attendance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Geofence Visual Status Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isWithinFence
                            ? Colors.green.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isWithinFence
                              ? Colors.green
                              : Colors.amber.shade800,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWithinFence
                                ? Icons.verified_user
                                : Icons.warning_amber_rounded,
                            color: isWithinFence
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWithinFence
                                      ? 'Inside Geofence Zone'
                                      : 'Outside Geofence Zone',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isWithinFence
                                        ? Colors.green.shade900
                                        : Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (distanceMeters != null
                                      ? '${GeofenceService.formatDistance(distanceMeters)} from central Office'
                                            '${!isWithinFence ? ' (Flagged: Outside Bounds)' : ''}'
                                      : 'Standard Office Geofence Verification'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isWithinFence
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Card
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                        ),
                        title: const Text('Verified Location'),
                        subtitle: Text(
                          _streetAddress ?? 'Fetching location...',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            await _fetchCurrentLocation();
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selfie Preview & Button
                    Text(
                      'Selfie Verification (Optional)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_capturedSelfie != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _capturedSelfie!,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Check-In Selfie'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () async {
                          await _takeSelfie();
                          setModalState(() {});
                        },
                      ),
                    const SizedBox(height: 20),

                    // Submit Clock In
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedEventId == null
                          ? null
                          : () async {
                              final now = DateTime.now();
                              final newRecord = AttendanceEntity(
                                id: '${staffId}_${now.millisecondsSinceEpoch}',
                                staffId: staffId,
                                staffName: staffName,
                                eventId: _selectedEventId!,
                                eventTitle: _selectedEventTitle ?? 'Office',
                                orderId: _selectedOrderId ?? '',
                                date: now,
                                checkInTime: now,
                                checkInLatitude: _currentPosition?.latitude,
                                checkInLongitude: _currentPosition?.longitude,
                                checkInAddress: _streetAddress,
                                isWithinGeofence: isWithinFence,
                                distanceToVenueMeters: distanceMeters,
                                createdAt: now,
                              );

                              final success = await ref
                                  .read(attendanceNotifierProvider.notifier)
                                  .checkIn(
                                    newRecord,
                                    selfieBase64: _selfieBase64,
                                  );

                              if (mounted && success) {
                                Navigator.pop(context);
                                setState(() {
                                  _capturedSelfie = null;
                                  _selfieBase64 = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isWithinFence
                                          ? 'Clocked in successfully!'
                                          : 'Clocked in (Flagged: Outside Geofence Zone)',
                                    ),
                                    backgroundColor: isWithinFence
                                        ? Colors.green
                                        : Colors.amber.shade900,
                                  ),
                                );
                              }
                            },
                      child: const Text(
                        'Confirm Clock In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showClockOutDialog(AttendanceEntity activeRecord) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _fetchCurrentLocation();

    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog
    }

    setState(() {
      _capturedSelfie = null;
      _selfieBase64 = null;
    });

    if (!mounted) return;

    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),

              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Clock Out Shift',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Daily Attendance',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    // Location Card
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                        ),
                        title: const Text('Check-Out Location'),
                        subtitle: Text(
                          _streetAddress ?? 'Fetching location...',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            await _fetchCurrentLocation();
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Shift Notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Shift Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Check-out Selfie
                    Text(
                      'Check-Out Selfie Verification (Optional)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_capturedSelfie != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _capturedSelfie!,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Check-Out Selfie'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () async {
                          await _takeSelfie();
                          setModalState(() {});
                        },
                      ),
                    const SizedBox(height: 20),

                    // Submit Clock Out
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final success = await ref
                            .read(attendanceNotifierProvider.notifier)
                            .checkOut(
                              attendanceId: activeRecord.id,
                              checkOutTime: now,
                              latitude: _currentPosition?.latitude,
                              longitude: _currentPosition?.longitude,
                              address: _streetAddress,
                              selfieBase64: _selfieBase64,
                              notes: notesController.text,
                            );

                        if (mounted && success) {
                          Navigator.pop(context);
                          setState(() {
                            _capturedSelfie = null;
                            _selfieBase64 = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Clocked out successfully!'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Confirm Clock Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authNotifierProvider).user;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = colorScheme.primary;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final attendanceStream = ref.watch(
      staffAttendanceStreamProvider(currentUser.uid),
    );
    final notifierState = ref.watch(attendanceNotifierProvider);

    final staffDisplayName = currentUser.email.contains('@')
        ? currentUser.email.split('@').first
        : currentUser.email;

    return Scaffold(
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('My Attendance & Shift'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.time_to_leave_rounded),
            tooltip: 'Request Leave / Off-Duty',
            onPressed: () => showStaffLeaveRequestSheet(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          attendanceStream.when(
            data: (records) {
              final sortedRecords = List<AttendanceEntity>.from(records)
                ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

              final activeRecord = sortedRecords.firstWhere(
                (r) => !r.isCheckedOut,
                orElse: () => AttendanceModel(
                  id: '',
                  staffId: '',
                  staffName: '',
                  eventId: '',
                  eventTitle: '',
                  orderId: '',
                  date: DateTime.now(),
                  checkInTime: DateTime.now(),
                  createdAt: DateTime.now(),
                ),
              );

              final bool hasActiveShift = activeRecord.id.isNotEmpty;

              final activeShiftCard = Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasActiveShift
                        ? [const Color(0xFF0052d4), const Color(0xFF4364f7), const Color(0xFF6fb1fc)]
                        : (isDarkMode
                            ? [const Color(0xFF1e293b), const Color(0xFF0f172a)]
                            : [const Color(0xFFf8fafc), const Color(0xFFf1f5f9)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasActiveShift
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFe2e8f0)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (hasActiveShift ? const Color(0xFF4364f7) : Colors.black).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
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
                                color: (hasActiveShift ? Colors.white : primaryColor).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                hasActiveShift ? Icons.timer_outlined : Icons.wb_sunny_outlined,
                                color: hasActiveShift ? Colors.white : primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              hasActiveShift ? 'ACTIVE SHIFT' : 'SHIFT STATUS',
                              style: TextStyle(
                                color: hasActiveShift ? Colors.white.withValues(alpha: 0.9) : (isDarkMode ? Colors.white70 : const Color(0xFF64748b)),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasActiveShift ? const Color(0xFF10b981) : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFe2e8f0)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: hasActiveShift ? Colors.white : const Color(0xFF94a3b8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasActiveShift ? 'On Duty' : 'Off Duty',
                                style: TextStyle(
                                  color: hasActiveShift ? Colors.white : (isDarkMode ? Colors.white70 : const Color(0xFF475569)),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (hasActiveShift) ...[
                      Text(
                        activeRecord.eventTitle.isNotEmpty ? activeRecord.eventTitle : 'Daily Office Duty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Text(
                            'Checked in at ${DateFormat('hh:mm a').format(activeRecord.checkInTime)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (activeRecord.checkInAddress != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                activeRecord.checkInAddress!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text(
                            'Clock Out Shift',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFef4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _showClockOutDialog(activeRecord),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Ready to start work?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : const Color(0xFF0f172a),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Clock in with verified GPS location to record today\'s attendance.',
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text(
                            'Clock In Now',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _showClockInDialog(
                            currentUser.uid,
                            staffDisplayName,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final historyHeader = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_toggle_off, size: 20, color: Color(0xFF0075db)),
                        const SizedBox(width: 8),
                        Text(
                          'Attendance History',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sortedRecords.length} Records',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final historyList = Expanded(
                child: sortedRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 56, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No attendance logs recorded yet',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : () {
                        final hasMore = sortedRecords.length > _pageSize;
                        final currentLength = hasMore
                            ? _pageSize
                            : sortedRecords.length;

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 40),
                          itemCount: hasMore ? currentLength + 1 : currentLength,
                          itemBuilder: (context, index) {
                            if (index == currentLength) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final item = sortedRecords[index];
                            final isPresent = item.status == AttendanceStatus.present;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: (item.isCheckedOut ? const Color(0xFF10b981) : primaryColor).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                item.isCheckedOut ? Icons.check_circle : Icons.timer,
                                                color: item.isCheckedOut ? const Color(0xFF10b981) : primaryColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.eventTitle.isNotEmpty ? item.eventTitle : 'Daily Duty',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    DateFormat('EEEE, MMM dd, yyyy').format(item.checkInTime),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPresent ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.status.displayName,
                                          style: TextStyle(
                                            color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.login, size: 14, color: Color(0xFF10b981)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'In: ${DateFormat('hh:mm a').format(item.checkInTime)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.logout, size: 14, color: item.checkOutTime != null ? const Color(0xFFef4444) : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.checkOutTime != null
                                                  ? 'Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)}'
                                                  : 'Out: Active',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: item.checkOutTime != null ? colorScheme.onSurface : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.checkInAddress != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.checkInAddress!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.isWithinGeofence
                                          ? const Color(0xFF10b981).withValues(alpha: 0.1)
                                          : Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.isWithinGeofence ? Icons.verified_user : Icons.warning_amber_rounded,
                                          size: 13,
                                          color: item.isWithinGeofence ? const Color(0xFF10b981) : Colors.amber.shade900,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.isWithinGeofence
                                              ? 'Verified On-Site Location'
                                              : 'Outside Office Geofence (${GeofenceService.formatDistance(item.distanceToVenueMeters)})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: item.isWithinGeofence ? const Color(0xFF047857) : Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }(),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: SingleChildScrollView(child: activeShiftCard)),
                        Expanded(flex: 2, child: Column(children: [historyHeader, historyList])),
                      ],
                    );
                  } else {
                    return Column(
                      children: [activeShiftCard, historyHeader, historyList],
                    );
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error loading attendance: $e')),
          ),

          if (notifierState.isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Uploading selfie & saving...',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
