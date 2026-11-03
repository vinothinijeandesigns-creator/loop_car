import 'package:flutter/material.dart';
import 'form_field_config.dart';

class InlineFormConfig {
  final String title;
  final IconData icon;
  final List<FormFieldConfig> fields;

  final Widget? customChild;

  bool completed;
  bool expanded;

  final bool showActions;
  final Future<void> Function(Map<String, String>)? onSave;

  InlineFormConfig({
    required this.title,
    required this.icon,
    required this.fields,
    this.customChild,
    this.completed = false,
    this.expanded = false,
    this.showActions = true,
    this.onSave,
  });
}
