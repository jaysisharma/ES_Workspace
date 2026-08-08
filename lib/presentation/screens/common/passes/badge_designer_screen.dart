import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_app/data/models/badge_template_model.dart';
import 'package:order_app/core/services/badge_service.dart';

class BadgeDesignerScreen extends StatefulWidget {
  const BadgeDesignerScreen({super.key});

  @override
  State<BadgeDesignerScreen> createState() => _BadgeDesignerScreenState();
}

class _BadgeDesignerScreenState extends State<BadgeDesignerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _widthController = TextEditingController(text: '100');
  final _heightController = TextEditingController(text: '150');
  
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  String? _imagePath;
  double qrX = 0.4;
  double qrY = 0.7;
  double qrSize = 0.25;

  @override
  void initState() {
    super.initState();
    _widthController.addListener(_onDimensionsChanged);
    _heightController.addListener(_onDimensionsChanged);
    _loadExistingTemplate();
  }

  @override
  void dispose() {
    _widthController.removeListener(_onDimensionsChanged);
    _heightController.removeListener(_onDimensionsChanged);
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onDimensionsChanged() {
    setState(() {});
  }

  Future<void> _loadExistingTemplate() async {
    final template = await BadgeService.loadTemplate();
    if (template != null) {
      setState(() {
        _imagePath = template.imagePath;
        _widthController.text = template.widthMm.toStringAsFixed(0);
        _heightController.text = template.heightMm.toStringAsFixed(0);
        qrX = template.qrX;
        qrY = template.qrY;
        qrSize = template.qrSize;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  void _saveTemplate(BuildContext context, Color primaryColor, Color secondaryColor) async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a template image first.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final double? width = double.tryParse(_widthController.text);
    final double? height = double.tryParse(_heightController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid width and height dimensions.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final template = BadgeTemplate(
      imagePath: _imagePath!,
      widthMm: width,
      heightMm: height,
      qrX: qrX,
      qrY: qrY,
      qrSize: qrSize,
    );

    final success = await BadgeService.saveTemplate(template);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Badge template saved successfully!' : 'Failed to save template.'),
          backgroundColor: success ? const Color(0xFF10b981) : secondaryColor,
        ),
      );
      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  void _clearTemplate(BuildContext context, Color secondaryColor) async {
    final success = await BadgeService.deleteTemplate();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Template cleared. Reverted to default A4.' : 'Failed to clear template.'),
          backgroundColor: success ? const Color(0xFF10b981) : secondaryColor,
        ),
      );
      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  BoxDecoration _cardDecoration(Color cardColor, Color borderColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildPreviewCanvas(Color primaryColor, Color accentColor, Color textColor, Color labelColor, Color borderColor) {
    if (_imagePath == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: textColor.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: labelColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload a Template Image',
                style: TextStyle(
                  color: labelColor.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double width = double.tryParse(_widthController.text) ?? 100.0;
    final double height = double.tryParse(_heightController.text) ?? 150.0;
    final double aspectRatio = width / height;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final qrWidthPx = qrSize * constraints.maxWidth;
                  final qrHeightPx = qrWidthPx;

                  return Stack(
                    children: [
                      // 1. Template background image
                      Positioned.fill(
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.fill,
                        ),
                      ),
                      
                      // 2. Interactive QR Overlay
                      Positioned(
                        left: qrX * constraints.maxWidth,
                        top: qrY * constraints.maxHeight,
                        width: qrWidthPx,
                        height: qrHeightPx,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              double newX = qrX + (details.delta.dx / constraints.maxWidth);
                              qrX = newX.clamp(0.0, 1.0 - qrSize);

                              double newY = qrY + (details.delta.dy / constraints.maxHeight);
                              double maxQrYPercentage = 1.0 - (qrHeightPx / constraints.maxHeight);
                              qrY = newY.clamp(0.0, maxQrYPercentage);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: accentColor, width: 2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.qr_code_2,
                              color: Colors.black,
                              size: double.infinity,
                            ),
                          ),
                        ),
                      ),
                      
                      // Drag helper text overlay
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Drag QR code',
                            style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.error; 
    final accentColor = colorScheme.secondary;
    final bgColor = colorScheme.surface;
    final cardColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Badge Designer'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Design Event Badge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your neck card template image and position the QR code layout.',
                      style: TextStyle(color: labelColor, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Canvas Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(cardColor, borderColor),
                      child: Column(
                        children: [
                          _buildPreviewCanvas(primaryColor, accentColor, textColor, labelColor, borderColor),
                          if (_imagePath != null) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.sync, size: 16),
                              label: const Text('Replace Template Image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload Button
                    if (_imagePath == null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Template Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Card Dimensions Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration(cardColor, borderColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARD PHYSICAL DIMENSIONS (MM)',
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _widthController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Width (mm)',
                                    suffixText: 'mm',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || double.tryParse(value) == null) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  controller: _heightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Height (mm)',
                                    suffixText: 'mm',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || double.tryParse(value) == null) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QR resizing settings
                    if (_imagePath != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(cardColor, borderColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR CODE SIZE: ${(qrSize * 100).toInt()}%',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: qrSize,
                              min: 0.1,
                              max: 0.45,
                              activeColor: primaryColor,
                              onChanged: (val) {
                                setState(() {
                                  qrSize = val;
                                  qrX = qrX.clamp(0.0, 1.0 - qrSize);
                                  
                                  final double width = double.tryParse(_widthController.text) ?? 100.0;
                                  final double height = double.tryParse(_heightController.text) ?? 150.0;
                                  final double aspectRatio = width / height;
                                  
                                  double qrHeightPercentage = qrSize * aspectRatio;
                                  qrY = qrY.clamp(0.0, 1.0 - qrHeightPercentage);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _clearTemplate(context, secondaryColor),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text('Reset Template', style: TextStyle(color: Colors.red)),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _saveTemplate(context, primaryColor, secondaryColor),
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text('Save Layout', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
