import 'package:flutter/material.dart';
import '../models/form_field_config.dart';
import '../models/inline_form_config.dart';
import 'form_actions_button.dart';

class InlineForm extends StatefulWidget {
  final InlineFormConfig config;

  /// controlled by parent
  final bool isOpen;
  final VoidCallback onTap;

  const InlineForm({
    super.key,
    required this.config,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<InlineForm> createState() => _InlineFormState();
}

class _InlineFormState extends State<InlineForm> {
  final _formKey = GlobalKey<FormState>();

  late Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();

    controllers = {
      for (var f in widget.config.fields)
        f.label: TextEditingController(text: f.initialValue),
    };
  }

  @override
  void didUpdateWidget(InlineForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update controller values if new initial values are passed (e.g., from async auth fetches)
    for (var f in widget.config.fields) {
      if (!controllers.containsKey(f.label)) {
        controllers[f.label] = TextEditingController(text: f.initialValue);
      } else if (f.initialValue != null &&
          oldWidget.config.fields.firstWhere((old) => old.label == f.label, orElse: () => f).initialValue != f.initialValue) {
        // Only update if the user hasn't heavily modified it or it's a fresh async load
        controllers[f.label]!.text = f.initialValue!;
      }
    }
  }

  /// ===============================
  /// FIELD TYPE → KEYBOARD
  /// ===============================
  TextInputType _mapKeyboard(FieldType type) {
    switch (type) {
      case FieldType.phone:
        return TextInputType.phone;

      case FieldType.number:
        return TextInputType.number;

      case FieldType.email:
        return TextInputType.emailAddress;

      case FieldType.multiline:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  /// ===============================
  /// SAVE
  /// ===============================
  /// ===============================
  /// SAVE
  /// ===============================
  bool _isSaving = false;

  void save() async {
    // If there is no Form (because of customChild), we skip validation and proceed.
    bool isValid = true;
    if (_formKey.currentState != null) {
      isValid = _formKey.currentState!.validate();
    }

    if (isValid) {
      if (widget.config.onSave != null) {
        setState(() {
          _isSaving = true;
        });

        final data = {
          for (var entry in controllers.entries) entry.key: entry.value.text,
        };

        try {
          await widget.config.onSave!(data);
          if (mounted) {
            setState(() {
              widget.config.completed = true;
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Updated successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error updating: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        setState(() {
          widget.config.completed = true;
        });
      }
    }
  }

  /// ===============================
  /// HEADER
  /// ===============================
  Widget _buildHeader() {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            /// + Circle
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF00C6D2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isOpen ? Icons.remove : Icons.add,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 16),

            /// TITLE ONLY
            Expanded(
              child: Text(
                widget.config.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===============================
  /// FORM FIELDS
  /// ===============================
  Widget _buildFields() {
    return Column(
      children: [
        /// CUSTOM CHILD OR NORMAL FIELDS
        if (widget.config.customChild != null)
          widget.config.customChild!
        else
          Form(
            key: _formKey,
            child: Column(
              children: [
                ...widget.config.fields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// FIELD LABEL
                        Text(
                          field.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        /// INPUT BOX
                        TextFormField(
                          controller: controllers[field.label],
                          keyboardType: _mapKeyboard(field.type),
                          maxLines: field.type == FieldType.multiline ? 4 : 1,
                          readOnly: field.readOnly,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFE5E5E5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (field.required &&
                                (value == null || value.isEmpty)) {
                              return "Required";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 12),

        /// ✅ COMMON BUTTONS (WORKS FOR ALL FORMS)
        if (widget.config.showActions)
          _isSaving
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C6D2)),
                ),
              )
              : FormActionButtons(onUpdate: save, onCancel: widget.onTap),

        if (widget.config.completed && !_isSaving)
          const Padding(
            padding: EdgeInsets.only(bottom: 12, top: 6),
            child: Icon(Icons.check_circle, color: Colors.green),
          ),
      ],
    );
  }

  /// ===============================
  /// BUILD
  /// ===============================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),

        /// ✅ accordion behaviour
        if (widget.isOpen) _buildFields(),
      ],
    );
  }
}
