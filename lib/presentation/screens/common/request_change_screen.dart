import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/event_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/change_request_entity.dart';
import '../../providers/change_request_providers.dart';
import '../../providers/auth_provider.dart';

class RequestChangeScreen extends ConsumerStatefulWidget {
  final EventEntity event;
  final OrderItemEntity item;

  const RequestChangeScreen({
    super.key,
    required this.event,
    required this.item,
  });

  @override
  ConsumerState<RequestChangeScreen> createState() =>
      _RequestChangeScreenState();
}

class _RequestChangeScreenState extends ConsumerState<RequestChangeScreen> {
  final _descriptionController = TextEditingController();
  String _changeType = 'Change Specification';
  String _urgencyLevel = 'Medium';
  bool _isSubmitting = false;

  final List<String> _changeTypes = [
    'Change Specification',
    'Change Quantity',
    'Replace Item',
    'Add Additional Item',
    'Remove Item',
  ];

  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authState = ref.read(authNotifierProvider);
    final userId = authState.user?.uid ?? 'unknown';

    final request = ChangeRequestEntity(
      id: const Uuid().v4(),
      orderId: widget.event.orderId,
      itemId: widget.item.id,
      requestedBy: userId,
      changeType: _changeType,
      description: _descriptionController.text.trim(),
      status: ChangeStatus.pending,
      createdAt: DateTime.now(),
    );

    try {
      await ref
          .read(changeRequestNotifierProvider.notifier)
          .createRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request submitted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0f1a23)
        : const Color(0xFFf5f7f8);
    final surfaceColor = isDarkMode
        ? const Color(0xFF1e293b).withValues(alpha: 0.5)
        : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF334155)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final inputBgColor = isDarkMode
        ? const Color(0xFF0f172a)
        : const Color(0xFFf1f5f9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF0f1a23).withValues(alpha: 0.8)
                : const Color(0xFFf5f7f8).withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 48.0,
                    ), // Balance the back button
                    child: Text(
                      'Request Change',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Event Reference
            _buildSectionHeader('Event Reference', labelColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.event, color: primaryColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: labelColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Oct 12, 2024',
                              style: TextStyle(fontSize: 14, color: labelColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: labelColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.event.location,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: labelColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Current Item Details
            _buildSectionHeader('Current Item Details', labelColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Name',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item.itemName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.item.quantity} ${widget.item.unit}',
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Specification',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: labelColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item.specification,
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.storefront, size: 20, color: labelColor),
                      const SizedBox(width: 8),
                      Text(
                        'Vendor: ',
                        style: TextStyle(fontSize: 14, color: labelColor),
                      ),
                      Text(
                        widget.item.vendor,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Requested Change Form
            _buildSectionHeader('Requested Change', labelColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1e293b).withValues(alpha: 0.3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Change Type
                  Text(
                    'Change Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _changeType,
                        dropdownColor: isDarkMode
                            ? const Color(0xFF1e293b)
                            : Colors.white,
                        icon: Icon(Icons.expand_more, color: labelColor),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontFamily: 'Manrope',
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            if (newValue != null) _changeType = newValue;
                          });
                        },
                        items: _changeTypes.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Explain what needs to be changed and why...',
                      hintStyle: TextStyle(fontSize: 14, color: labelColor),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Urgency
                  Text(
                    'Urgency Level',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _urgencyLevel,
                        dropdownColor: isDarkMode
                            ? const Color(0xFF1e293b)
                            : Colors.white,
                        icon: Icon(Icons.expand_more, color: labelColor),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontFamily: 'Manrope',
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            if (newValue != null) _urgencyLevel = newValue;
                          });
                        },
                        items: _urgencyLevels.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF0f1a23).withValues(alpha: 0.95)
              : const Color(0xFFf5f7f8).withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.2),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: labelColor,
        ),
      ),
    );
  }
}
