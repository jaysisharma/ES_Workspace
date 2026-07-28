import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/entities/event_pass_entity.dart';
import '../../providers/event_pass_provider.dart';

class CreateEventPassScreen extends ConsumerStatefulWidget {
  const CreateEventPassScreen({super.key});

  @override
  ConsumerState<CreateEventPassScreen> createState() => _CreateEventPassScreenState();
}

class _CreateEventPassScreenState extends ConsumerState<CreateEventPassScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _customServiceController = TextEditingController();

  String? _photoBase64;
  final List<String> _selectedServices = [];
  bool _isLoadingLocal = false;

  final List<String> _presetServices = [
    'Dinner',
    'Lunch',
    'Drinks',
    'Photoshoot',
  ];

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _eventNameController.dispose();
    _companyNameController.dispose();
    _customServiceController.dispose();
    super.dispose();
  }

  void _togglePreset(String service) {
    setState(() {
      if (_selectedServices.contains(service)) {
        _selectedServices.remove(service);
      } else {
        _selectedServices.add(service);
      }
    });
  }

  Future<void> _addCustomService() async {
    final text = _customServiceController.text.trim();
    if (text.isEmpty) return;

    if (_selectedServices.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service already added')),
      );
      return;
    }

    setState(() {
      _isLoadingLocal = true;
    });

    try {
      await ref.read(eventPassNotifierProvider.notifier).addAvailableService(text);
      setState(() {
        _selectedServices.add(text);
        _customServiceController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save service: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocal = false;
        });
      }
    }
  }

  void _removeService(String service) {
    setState(() {
      _selectedServices.remove(service);
    });
  }

  Future<void> _generatePass() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add at least one service'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingLocal = true;
    });

    try {
      final String passId = const Uuid().v4();
      final syncState = ref.read(syncProvider);
      final String signature = EventPassEntity.generateSignature(passId, syncState.salt);

      final List<PassServiceItem> serviceItems = _selectedServices
          .map((name) => PassServiceItem(name: name, isRedeemed: false))
          .toList();

      final EventPassEntity pass = EventPassEntity(
        id: passId,
        clientName: _clientNameController.text.trim(),
        clientPhone: _clientPhoneController.text.trim(),
        eventName: _eventNameController.text.trim(),
        services: serviceItems,
        createdAt: DateTime.now(),
        passSignature: signature,
        companyName: _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
        photoBase64: _photoBase64,
      );

      final success = await ref.read(eventPassNotifierProvider.notifier).addPass(pass);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event Pass generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          final errorMessage = ref.read(eventPassNotifierProvider).errorMessage ?? 'Unknown error occurred';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate pass: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate pass: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Event Pass',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Pass Information', colorScheme),
                  _buildTextField(
                    _clientNameController,
                    'Name',
                    Icons.person_outline,
                    colorScheme,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _clientPhoneController,
                    'Contact Number',
                    Icons.phone_outlined,
                    colorScheme,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Must be 10 digits';
                      if (int.tryParse(v) == null) return 'Must contain only digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _eventNameController,
                    'Event Name',
                    Icons.event_outlined,
                    colorScheme,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _companyNameController,
                    'Company Name (Optional)',
                    Icons.business_outlined,
                    colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSelector(colorScheme),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Services & Permissions', colorScheme),
                  Text(
                    'Select preset services to authorize on this pass:',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: (ref.watch(eventPassNotifierProvider).availableServices.isNotEmpty
                            ? ref.watch(eventPassNotifierProvider).availableServices
                            : _presetServices)
                        .map((service) {
                      final isSelected = _selectedServices.contains(service);
                      final isPreset = _presetServices.contains(service);
                      return InputChip(
                        label: Text(
                          service,
                          style: GoogleFonts.manrope(
                            color: isSelected ? Colors.white : colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: colorScheme.primary,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => _togglePreset(service),
                        onDeleted: isPreset ? null : () => _confirmDeleteService(service),
                        deleteIcon: isPreset
                            ? null
                            : Icon(
                                Icons.cancel,
                                size: 16,
                                color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                              ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Or add custom service manually:',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customServiceController,
                          style: GoogleFonts.manrope(),
                          decoration: InputDecoration(
                            hintText: 'e.g. VIP Lounge, Valet Parking',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            prefixIcon: Icon(Icons.star_outline, color: colorScheme.onSurfaceVariant, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addCustomService,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_selectedServices.isNotEmpty) ...[
                    Text(
                      'Authorized Services:',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedServices.map((service) {
                        return Chip(
                          label: Text(
                            service,
                            style: GoogleFonts.manrope(fontSize: 13, color: colorScheme.onSurface),
                          ),
                          deleteIcon: Icon(Icons.cancel, size: 16, color: colorScheme.onSurfaceVariant),
                          onDeleted: () => _removeService(service),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoadingLocal ? null : _generatePass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoadingLocal
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Generate Event Pass',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoadingLocal)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    ColorScheme colorScheme, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      ),
    );
  }

  Widget _buildPhotoSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pass Photo (Optional)',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: _photoBase64 == null
                  ? Icon(Icons.person_outline, size: 40, color: colorScheme.onSurfaceVariant)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_photoBase64!),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pick Image'),
            ),
            if (_photoBase64 != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _photoBase64 = null;
                  });
                },
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _photoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteService(String serviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete the service "$serviceName" from the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoadingLocal = true;
      });
      final success = await ref
          .read(eventPassNotifierProvider.notifier)
          .deleteAvailableService(serviceName);
      if (mounted) {
        setState(() {
          _isLoadingLocal = false;
        });
        if (success) {
          setState(() {
            _selectedServices.remove(serviceName);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final errorMessage = ref.read(eventPassNotifierProvider).errorMessage ?? 'Failed to delete service';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
