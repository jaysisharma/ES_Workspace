import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/client_provider.dart';

class ClientAutocompleteField extends ConsumerWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final Function(String)? onSelected;

  const ClientAutocompleteField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientNotifierProvider).clients;
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return clients
            .map((v) => v.name)
            .where(
              (name) => name.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
      },
      onSelected: (String selection) {
        controller.text = selection;
        if (onSelected != null) {
          onSelected!(selection);
        }
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: labelColor),
            prefixIcon: icon != null
                ? Icon(icon, color: labelColor, size: 20)
                : null,
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colorScheme.primary, width: 1),
            ),
          ),
          onSubmitted: (value) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            color: colorScheme.surface,
            child: SizedBox(
              width:
                  MediaQuery.of(context).size.width - 64, // Margin adjustment
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(
                  color: borderColor.withValues(alpha: 0.5),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(option),
                    dense: true,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
