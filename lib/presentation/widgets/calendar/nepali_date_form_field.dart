import 'package:flutter/material.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';

/// An interactive form field that allows BOTH direct manual typing of Bikram Sambat (BS)
/// dates (e.g., "2081-05-15") AND visual picking via [NepaliDatePickerDialog].
class NepaliDateFormField extends StatefulWidget {
  final String label;
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onDateChanged;
  final String? hintText;
  final bool isRequired;
  final bool enabled;
  final IconData prefixIcon;
  final String? helperText;

  const NepaliDateFormField({
    super.key,
    required this.label,
    this.initialDate,
    required this.onDateChanged,
    this.hintText = 'YYYY-MM-DD (BS)',
    this.isRequired = false,
    this.enabled = true,
    this.prefixIcon = Icons.calendar_today_outlined,
    this.helperText,
  });

  @override
  State<NepaliDateFormField> createState() => _NepaliDateFormFieldState();
}

class _NepaliDateFormFieldState extends State<NepaliDateFormField> {
  late final TextEditingController _controller;
  String? _errorText;
  String? _bsDisplayLabel;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.initialDate != null) {
      final bs = NepaliCalendarEngine.adToBs(widget.initialDate!);
      _controller.text =
          '${bs.year}-${bs.month.toString().padLeft(2, '0')}-${bs.day.toString().padLeft(2, '0')}';
      _updateDisplayLabel(bs);
    }
  }

  @override
  void didUpdateWidget(covariant NepaliDateFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate) {
      if (widget.initialDate != null) {
        final bs = NepaliCalendarEngine.adToBs(widget.initialDate!);
        final formatted =
            '${bs.year}-${bs.month.toString().padLeft(2, '0')}-${bs.day.toString().padLeft(2, '0')}';
        if (_controller.text != formatted) {
          _controller.text = formatted;
          _updateDisplayLabel(bs);
        }
      } else if (_controller.text.isNotEmpty) {
        _controller.clear();
        setState(() {
          _bsDisplayLabel = null;
          _errorText = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDisplayLabel(dynamic bsDate) {
    setState(() {
      _bsDisplayLabel =
          '${NepaliCalendarEngine.format(bsDate, pattern: 'MMMM dd, yyyy')} BS';
      _errorText = null;
    });
  }

  void _onTextChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _bsDisplayLabel = null;
        _errorText = widget.isRequired ? 'Date is required' : null;
      });
      widget.onDateChanged(null);
      return;
    }

    final parsed = NepaliCalendarEngine.tryParseBs(trimmed);
    if (parsed != null) {
      final ad = NepaliCalendarEngine.bsToAd(parsed);
      setState(() {
        _updateDisplayLabel(parsed);
      });
      widget.onDateChanged(ad);
    } else {
      setState(() {
        _bsDisplayLabel = null;
        _errorText = 'Enter valid BS date (YYYY-MM-DD)';
      });
    }
  }

  Future<void> _openDatePicker(BuildContext context) async {
    DateTime startAd = widget.initialDate ?? DateTime.now();
    final parsed = NepaliCalendarEngine.tryParseBs(_controller.text);
    if (parsed != null) {
      startAd = NepaliCalendarEngine.bsToAd(parsed);
    }

    final picked = await NepaliDatePickerDialog.show(
      context: context,
      title: widget.label,
      initialStart: startAd,
      allowRange: false,
    );

    if (picked != null && picked['start'] != null) {
      final newAd = picked['start']!;
      final newBs = NepaliCalendarEngine.adToBs(newAd);
      final formatted =
          '${newBs.year}-${newBs.month.toString().padLeft(2, '0')}-${newBs.day.toString().padLeft(2, '0')}';
      _controller.text = formatted;
      _updateDisplayLabel(newBs);
      widget.onDateChanged(newAd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2.0, bottom: 6.0),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          onChanged: _onTextChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              fontSize: 13,
              color: labelColor.withValues(alpha: 0.6),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              size: 20,
              color: primaryColor,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 16,
                      color: labelColor,
                    ),
                    tooltip: 'Clear',
                    onPressed: () {
                      _controller.clear();
                      _onTextChanged('');
                    },
                  ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                  tooltip: 'Pick from Nepali Calendar',
                  onPressed: widget.enabled ? () => _openDatePicker(context) : null,
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            errorText: _errorText,
          ),
        ),
        if (_bsDisplayLabel != null && _errorText == null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 12,
                  color: Color(0xFF10b981),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _bsDisplayLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10b981),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else if (widget.helperText != null && _errorText == null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
            child: Text(
              widget.helperText!,
              style: TextStyle(
                fontSize: 11,
                color: labelColor.withValues(alpha: 0.7),
              ),
            ),
          ),
      ],
    );
  }
}
