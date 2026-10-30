import 'package:flutter/material.dart';

class CommunicationPreferenceWidget extends StatefulWidget {
  final Map<String, bool> values;
  final Function(String, bool)? onChanged;

  const CommunicationPreferenceWidget({
    super.key,
    required this.values,
    this.onChanged,
  });

  @override
  State<CommunicationPreferenceWidget> createState() =>
      _CommunicationPreferenceWidgetState();
}

class _CommunicationPreferenceWidgetState
    extends State<CommunicationPreferenceWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildCheckbox(
          "Push notification",
          widget.values["Push notification"] ?? true,
          (val) {
            setState(() {
              if (widget.onChanged != null) {
                widget.onChanged!("Push notification", val!);
              }
            });
          },
        ),
        buildCheckbox("Emails", widget.values["Emails"] ?? true, (val) {
          setState(() {
            if (widget.onChanged != null) {
              widget.onChanged!("Emails", val!);
            }
          });
        }),
        buildCheckbox(
          "Text messages",
          widget.values["Text messages"] ?? true,
          (val) {
            setState(() {
              if (widget.onChanged != null) {
                widget.onChanged!("Text messages", val!);
              }
            });
          },
        ),
        buildCheckbox("Phone calls", widget.values["Phone calls"] ?? true, (
          val,
        ) {
          setState(() {
            if (widget.onChanged != null) {
              widget.onChanged!("Phone calls", val!);
            }
          });
        }),
      ],
    );
  }

  Widget buildCheckbox(String title, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: const Color(0xFF00C6D2),
            onChanged: onChanged,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
