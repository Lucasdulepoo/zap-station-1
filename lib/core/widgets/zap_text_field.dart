import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ZapTextField extends StatelessWidget {
  const ZapTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.autofillHints,
    this.textAlign = TextAlign.start,
    this.style,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      autofillHints: autofillHints,
      textAlign: textAlign,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefix,
        counterText: '',
      ),
    );
  }
}
