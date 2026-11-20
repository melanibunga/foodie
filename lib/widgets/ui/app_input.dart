import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';

/// Input teks standar aplikasi Foodie.id sesuai PRD §5.3 dan §16
class AppInput extends StatefulWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color? fillColor;
  final bool readOnly;
  final int maxLines;
  final FocusNode? focusNode;

  const AppInput({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.fillColor,
    this.readOnly = false,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget? effectiveSuffixIcon = widget.suffixIcon;
    if (widget.isPassword) {
      effectiveSuffixIcon = IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: palette.textSecondary,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    final effectiveFillColor = widget.fillColor ?? palette.field;
    final effectiveBorderColor = widget.errorText != null
        ? palette.danger
        : (palette.isDark ? palette.fieldBorder : palette.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppText.formLabel.copyWith(color: palette.textStrong),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: widget.maxLines > 1 ? null : 48.0,
          decoration: BoxDecoration(
            color: effectiveFillColor,
            borderRadius: AppRadius.input,
            border: Border.all(color: effectiveBorderColor),
          ),
          alignment: widget.maxLines > 1
              ? Alignment.topLeft
              : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            readOnly: widget.readOnly,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            scrollPadding: const EdgeInsets.symmetric(
              vertical: 32.0,
              horizontal: 20.0,
            ),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: AppText.body.copyWith(color: palette.textBody),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: AppText.body.copyWith(color: palette.textSecondary),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              suffixIcon: effectiveSuffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: AppText.caption.copyWith(color: palette.dangerText),
          ),
        ],
      ],
    );
  }
}
